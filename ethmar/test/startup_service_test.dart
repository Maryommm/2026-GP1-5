import 'package:ethmar/services/auth_service.dart';
import 'package:ethmar/services/startup_service.dart';
import 'package:ethmar/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

const _verifiedSession = AuthSession(
  uid: 'user-123',
  email: 'user@example.com',
  emailVerified: true,
);

const _unverifiedSession = AuthSession(
  uid: 'user-123',
  email: 'user@example.com',
  emailVerified: false,
);

class _StartupHarness {
  AuthSession? restoredSession = _verifiedSession;
  AuthSession? currentSession = _verifiedSession;
  bool refreshedVerification = true;
  String username = 'ethmar_user';
  Object? waitError;
  Object? refreshError;
  Object? profileError;
  Object? signOutError;
  String? finishedUsername;
  Object? finishError;
  void Function()? afterProfileLoad;
  int refreshCount = 0;
  int profileLoadCount = 0;
  int signOutCount = 0;
  int finishCount = 0;

  StartupService get service => StartupService.withDependencies(
    waitForSession: () async {
      final error = waitError;
      if (error != null) throw error;
      return restoredSession;
    },
    refreshEmailVerification: () async {
      refreshCount += 1;
      final error = refreshError;
      if (error != null) throw error;
      return refreshedVerification;
    },
    currentSession: () => currentSession,
    loadUsername: () async {
      profileLoadCount += 1;
      final error = profileError;
      if (error != null) throw error;
      afterProfileLoad?.call();
      return username;
    },
    signOut: () async {
      signOutCount += 1;
      final error = signOutError;
      if (error != null) throw error;
    },
    finishUnfinishedSignUp: () async {
      finishCount += 1;
      final error = finishError;
      if (error != null) throw error;
      return finishedUsername;
    },
  );
}

void main() {
  test('routes a signed-out session to Welcome', () async {
    final harness = _StartupHarness()
      ..restoredSession = null
      ..currentSession = null;

    final decision = await harness.service.resolve();

    expect(decision.destination, StartupDestination.welcome);
    expect(harness.refreshCount, 0);
    expect(harness.profileLoadCount, 0);
    expect(harness.signOutCount, 0);
  });

  test(
    'refreshes a verified session and routes a valid profile to Home',
    () async {
      final harness = _StartupHarness();

      final decision = await harness.service.resolve();

      expect(decision.destination, StartupDestination.home);
      expect(decision.username, 'ethmar_user');
      expect(harness.refreshCount, 1);
      expect(harness.profileLoadCount, 1);
      expect(harness.signOutCount, 0);
    },
  );

  test('routes an unverified session to Login recovery', () async {
    final harness = _StartupHarness()
      ..restoredSession = _unverifiedSession
      ..currentSession = _unverifiedSession
      ..refreshedVerification = false;

    final decision = await harness.service.resolve();

    expect(decision.destination, StartupDestination.login);
    expect(decision.email, 'user@example.com');
    expect(decision.resumePersistedSession, isTrue);
    expect(decision.failure, isNull);
    expect(harness.profileLoadCount, 0);
    expect(harness.signOutCount, 0);
  });

  test(
    'finishes an unfinished sign up with the kept username and opens Home',
    () async {
      final harness = _StartupHarness()
        ..profileError = const UserProfileMissingException()
        ..finishedUsername = 'kept_name';

      final decision = await harness.service.resolve();

      expect(decision.destination, StartupDestination.home);
      expect(decision.username, 'kept_name');
      expect(harness.finishCount, 1);
      expect(harness.signOutCount, 0);
    },
  );

  test(
    'routes to Login to sign up again when the unfinished account is removed',
    () async {
      final harness = _StartupHarness()
        ..profileError = const UserProfileMissingException();

      final decision = await harness.service.resolve();

      expect(decision.destination, StartupDestination.login);
      expect(decision.failure, StartupFailure.unfinishedSignUp);
      expect(decision.email, 'user@example.com');
      expect(decision.resumePersistedSession, isFalse);
    },
  );

  test(
    'signs out and asks for a fresh login when removal needs one',
    () async {
      final harness = _StartupHarness()
        ..profileError = const UserProfileMissingException()
        ..finishError = FirebaseAuthException(code: 'requires-recent-login');

      final decision = await harness.service.resolve();

      expect(decision.destination, StartupDestination.login);
      expect(decision.failure, StartupFailure.logInToFinishSignUp);
      expect(decision.resumePersistedSession, isFalse);
      expect(harness.signOutCount, 1);
    },
  );

  test('signs out an invalid profile and routes to Login safely', () async {
    final harness = _StartupHarness()
      ..profileError = const UserProfileInvalidException();

    final decision = await harness.service.resolve();

    expect(decision.destination, StartupDestination.login);
    expect(decision.failure, StartupFailure.profile);
    expect(decision.resumePersistedSession, isFalse);
    expect(harness.signOutCount, 1);
  });

  test('keeps the session for a profile-loading network error', () async {
    final harness = _StartupHarness()
      ..profileError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );

    final decision = await harness.service.resolve();

    expect(decision.destination, StartupDestination.login);
    expect(decision.failure, StartupFailure.network);
    expect(decision.resumePersistedSession, isTrue);
    expect(harness.signOutCount, 0);
  });

  test('keeps the session for an authentication network error', () async {
    final harness = _StartupHarness()
      ..refreshError = FirebaseAuthException(code: 'network-request-failed');

    final decision = await harness.service.resolve();

    expect(decision.destination, StartupDestination.login);
    expect(decision.failure, StartupFailure.network);
    expect(decision.resumePersistedSession, isTrue);
    expect(harness.signOutCount, 0);
  });

  test(
    'maps an unexpected restoration error to an authentication failure',
    () async {
      final harness = _StartupHarness()
        ..waitError = StateError('restore failed');

      final decision = await harness.service.resolve();

      expect(decision.destination, StartupDestination.login);
      expect(decision.failure, StartupFailure.authentication);
      expect(harness.profileLoadCount, 0);
      expect(harness.signOutCount, 1);
    },
  );

  test(
    'does not grant Home if the session changes while loading the profile',
    () async {
      final harness = _StartupHarness();
      harness.afterProfileLoad = () {
        harness.currentSession = const AuthSession(
          uid: 'different-user',
          email: 'other@example.com',
          emailVerified: true,
        );
      };

      final decision = await harness.service.resolve();

      expect(decision.destination, StartupDestination.login);
      expect(decision.failure, StartupFailure.authentication);
      expect(harness.signOutCount, 1);
    },
  );

  test('stays on Login when sign-out cleanup fails', () async {
    final harness = _StartupHarness()
      ..profileError = const UserProfileInvalidException()
      ..signOutError = StateError('sign-out failed');

    final decision = await harness.service.resolve();

    expect(decision.destination, StartupDestination.login);
    expect(decision.failure, StartupFailure.profile);
    expect(harness.signOutCount, 1);
  });
}
