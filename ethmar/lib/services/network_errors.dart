import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore error codes that mean the server couldn't be reached or didn't
/// answer in time.
const _networkCodes = {'unavailable', 'deadline-exceeded', 'network-request-failed'};

/// True when [error] was caused by a missing or lost connection, so we tell
/// the user to check their internet. Every write here is safe to retry.
bool isNetworkError(Object error) =>
    (error is FirebaseException && _networkCodes.contains(error.code)) ||
    error is TimeoutException;

/// How long a save or server read waits before we tell the user to check
/// their connection.
const serverTimeout = Duration(seconds: 15);

/// The error used when the server doesn't answer within [serverTimeout].
/// It is a Firestore 'deadline-exceeded' error, so the screens already
/// show the "check your connection" message for it.
FirebaseException serverTimedOut() => FirebaseException(
  plugin: 'cloud_firestore',
  code: 'deadline-exceeded',
  message: 'The server did not answer in time.',
);

/// Returns [future], or throws [serverTimedOut] if it takes longer than
/// [serverTimeout]. Used for reads that must come from the server, because
/// they can wait a long time on a bad connection.
Future<T> withServerTimeout<T>(Future<T> future) =>
    future.timeout(serverTimeout, onTimeout: () => throw serverTimedOut());

extension SaveOnServer on FirebaseFirestore {
  /// Runs [handler] as a transaction that stops after [serverTimeout].
  ///
  /// All saves in the app use this instead of a plain `set`, `update` or
  /// `delete`. When offline, those plain writes never fail: they wait until
  /// the connection comes back (the save button keeps spinning) and then
  /// send anyway. A transaction needs the server, so offline it fails right
  /// away and the screen can show an error. Nothing gets saved later without
  /// the user knowing.
  Future<T> saveOnServer<T>(TransactionHandler<T> handler) => runTransaction(
    handler,
    timeout: serverTimeout,
  ).timeout(
    // A bit longer than Firestore's own limit, in case it never answers.
    serverTimeout + const Duration(seconds: 5),
    onTimeout: () => throw serverTimedOut(),
  );
}
