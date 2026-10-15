import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';
import 'user_service.dart';

// Define the possible screens after startup.
enum StartupDestination { welcome, login, home, completeRegistration }

// Define the possible startup errors.
enum StartupFailure { authentication, network, profile }

// Store the destination and information needed after startup.
class StartupDecision {
  const StartupDecision._(
    this.destination, {
    this.email = '',
    this.username = '',
    this.resumePersistedSession = false,
    this.failure,
  });

  const StartupDecision.welcome() : this._(StartupDestination.welcome);

  const StartupDecision.login({
    String email = '',
    bool resumePersistedSession = false,
    StartupFailure? failure,
  }) : this._(
         StartupDestination.login,
         email: email,
         resumePersistedSession: resumePersistedSession,
         failure: failure,
       );

  const StartupDecision.home(String username)
    : this._(StartupDestination.home, username: username);

  const StartupDecision.completeRegistration(String email)
    : this._(StartupDestination.completeRegistration, email: email);

  final StartupDestination destination;
  final String email;
  final String username;
  final bool resumePersistedSession;
  final StartupFailure? failure;
}

// Define the functions used during startup.
typedef StartupSessionLoader = Future<AuthSession?> Function();
typedef EmailVerificationRefresher = Future<bool> Function();
typedef CurrentSessionReader = AuthSession? Function();
typedef UsernameLoader = Future<String> Function();
typedef StartupSignOut = Future<void> Function();

// Restore the Firebase session and choose the first screen.
class StartupService {
  factory StartupService({AuthService? authService, UserService? userService}) {
    final auth = authService ?? AuthService();
    final users = userService ?? UserService();

    return StartupService.withDependencies(
      waitForSession: auth.waitForRestoredSession,
      refreshEmailVerification: auth.isEmailVerified,
      currentSession: () => auth.currentSession,
      loadUsername: users.getCurrentUsername,
      signOut: auth.signOut,
    );
  }

  StartupService.withDependencies({
    required StartupSessionLoader waitForSession,
    required EmailVerificationRefresher refreshEmailVerification,
    required CurrentSessionReader currentSession,
    required UsernameLoader loadUsername,
    required StartupSignOut signOut,
  }) : _waitForSession = waitForSession,
       _refreshEmailVerification = refreshEmailVerification,
       _currentSession = currentSession,
       _loadUsername = loadUsername,
       _signOut = signOut;

  final StartupSessionLoader _waitForSession;
  final EmailVerificationRefresher _refreshEmailVerification;
  final CurrentSessionReader _currentSession;
  final UsernameLoader _loadUsername;
  final StartupSignOut _signOut;

  // Verify the restored session and profile before allowing Home access.
  Future<StartupDecision> resolve() async {
    AuthSession? restoredSession;

    try {
      // Wait until Firebase checks if the user is already signed in.
      restoredSession = await _waitForSession();

      // Show Welcome if there is no saved session.
      if (restoredSession == null) return const StartupDecision.welcome();

      // Refresh email verification and check the current session.
      final verified = await _refreshEmailVerification();
      final currentSession = _currentSession();

      // Make sure the same user is still signed in.
      if (currentSession == null || currentSession.uid != restoredSession.uid) {
        throw StateError('The authenticated user changed during startup.');
      }

      final email = currentSession.email.isEmpty
          ? restoredSession.email
          : currentSession.email;

      // Return to Login if the email is not verified.
      if (!verified || !currentSession.emailVerified) {
        return StartupDecision.login(
          email: email,
          resumePersistedSession: true,
        );
      }

      try {
        // Load the username from Firestore.
        final username = await _loadUsername();

        // Check that the verified session has not changed.
        _requireUnchangedVerifiedSession(restoredSession.uid);

        // Open Home when the profile exists.
        return StartupDecision.home(username);

      } on UserProfileMissingException {
        // Check the session before completing registration.
        _requireUnchangedVerifiedSession(restoredSession.uid);

        // Open registration if the user profile is missing.
        return StartupDecision.completeRegistration(email);
      }

    } on UserProfileInvalidException {
      // Sign out if the saved profile is invalid.
      await _signOutQuietly();

      return StartupDecision.login(
        email: restoredSession?.email ?? '',
        failure: StartupFailure.profile,
      );

    } on FirebaseAuthException catch (error) {
      // Keep the saved session during network errors.
      if (error.code == 'network-request-failed') {
        return StartupDecision.login(
          email: restoredSession?.email ?? '',
          resumePersistedSession: restoredSession != null,
          failure: StartupFailure.network,
        );
      }

      // Sign out when authentication fails.
      await _signOutQuietly();

      return StartupDecision.login(
        email: restoredSession?.email ?? '',
        failure: StartupFailure.authentication,
      );

    } on FirebaseException catch (error) {
      // Keep the session if Firestore is temporarily unavailable.
      if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
        return StartupDecision.login(
          email: restoredSession?.email ?? '',
          resumePersistedSession: restoredSession != null,
          failure: StartupFailure.network,
        );
      }

      // Sign out if another Firestore error occurs.
      await _signOutQuietly();

      return StartupDecision.login(
        email: restoredSession?.email ?? '',
        failure: StartupFailure.profile,
      );

    } catch (_) {
      // Handle unexpected startup errors.
      await _signOutQuietly();

      return StartupDecision.login(
        email: restoredSession?.email ?? '',
        failure: StartupFailure.authentication,
      );
    }
  }

  // Reject the result if the authenticated user changed during loading.
  void _requireUnchangedVerifiedSession(String expectedUid) {
    final session = _currentSession();

    if (session == null ||
        session.uid != expectedUid ||
        !session.emailVerified) {
      throw StateError('The authenticated user changed during startup.');
    }
  }

  // Sign out without interrupting the startup error handling.
  Future<void> _signOutQuietly() async {
    try {
      await _signOut();
    } catch (_) {
      // Keep the user on Login even if sign-out fails.
    }
  }
}