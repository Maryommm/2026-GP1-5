import 'package:firebase_auth/firebase_auth.dart';

// Store the user's login information.
class AuthSession {
  const AuthSession({
    required this.uid,
    required this.email,
    required this.emailVerified,
  });

  final String uid;
  final String email;
  final bool emailVerified;
}

// Manage user accounts and login sessions using Firebase.
class AuthService {

  // Wait for Firebase to check if the user is already signed in.
  Future<AuthSession?> waitForRestoredSession() async {
    final user = await FirebaseAuth.instance.authStateChanges().first;
    return user == null ? null : _sessionFor(user);
  }

  // Get the current user's login information.
  AuthSession? get currentSession {
    final user = FirebaseAuth.instance.currentUser;
    return user == null ? null : _sessionFor(user);
  }

  // Create a new account using email and password.
  Future<UserCredential> createAccount({
    required String email,
    required String password,
  }) {
    return FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Send an email verification link to the user.
  Future<void> sendEmailVerification() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError(
        'Cannot send email verification because no user is signed in.',
      );
    }

    // Avoid sending another email if the account is already verified.
    if (!user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  // Check if the user has verified their email.
  Future<bool> isEmailVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // Get the latest verification status from Firebase.
    await user.reload();

    final refreshedUser = FirebaseAuth.instance.currentUser;
    if (refreshedUser == null || !refreshedUser.emailVerified) return false;

    // Update the token so Firestore knows the email is verified.
    await refreshedUser.getIdToken(true);

    return true;
  }

  // Sign in using email and password.
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Send a password reset link to the user's email.
  Future<void> sendPasswordResetEmail({required String email}) {
    return FirebaseAuth.instance.sendPasswordResetEmail(
      email: email.trim(),
    );
  }

  // Sign out the current user.
  Future<void> signOut() {
    return FirebaseAuth.instance.signOut();
  }

  // Get the user's ID, email, and verification status.
  AuthSession _sessionFor(User user) => AuthSession(
    uid: user.uid,
    email: user.email?.trim() ?? '',
    emailVerified: user.emailVerified,
  );
}