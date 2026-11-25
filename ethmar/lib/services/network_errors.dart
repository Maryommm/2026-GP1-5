import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore error codes that mean the server couldn't be reached (or
/// didn't answer in time), as opposed to a refusal or a bug.
const _networkCodes = {'unavailable', 'deadline-exceeded', 'network-request-failed'};

/// True when [error] came from a lost or missing connection, so the user
/// is told to check it. A write that failed this way may or may not have
/// reached the server; every write here can safely be tried again.
bool isNetworkError(Object error) =>
    (error is FirebaseException && _networkCodes.contains(error.code)) ||
    error is TimeoutException;

/// How long a save or a server read waits before the user is told to
/// check the connection.
const serverTimeout = Duration(seconds: 15);

/// The error for a server that didn't answer within [serverTimeout]. It is
/// a Firestore 'deadline-exceeded', so the screens that already tell the
/// user to check the connection for Firestore errors do so here too.
FirebaseException serverTimedOut() => FirebaseException(
  plugin: 'cloud_firestore',
  code: 'deadline-exceeded',
  message: 'The server did not answer in time.',
);

/// [future], or a [serverTimedOut] error if it takes longer than
/// [serverTimeout]. For reads that must come from the server
/// (`Source.server`), which can wait a long time on a dropped connection.
Future<T> withServerTimeout<T>(Future<T> future) =>
    future.timeout(serverTimeout, onTimeout: () => throw serverTimedOut());

extension SaveOnServer on FirebaseFirestore {
  /// Runs [handler] as a transaction that gives up after [serverTimeout].
  ///
  /// Every save in the app goes through here rather than a plain `set`,
  /// `update` or `delete`: offline, those never fail. They wait, unseen,
  /// for the connection to come back (the save button spins forever) and
  /// are then sent anyway, maybe after the user gave up or tried again. A
  /// transaction needs the server, so offline it fails ('unavailable') and
  /// the screen can say why; nothing is saved behind the user's back later.
  Future<T> saveOnServer<T>(TransactionHandler<T> handler) => runTransaction(
    handler,
    timeout: serverTimeout,
  ).timeout(
    // A little longer than Firestore's own limit, in case it never answers.
    serverTimeout + const Duration(seconds: 5),
    onTimeout: () => throw serverTimedOut(),
  );
}
