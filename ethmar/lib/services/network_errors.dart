import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

/// Firestore error codes that mean the server couldn't be reached (or
/// didn't answer in time), as opposed to a refusal or a bug.
const _networkCodes = {'unavailable', 'deadline-exceeded', 'network-request-failed'};

/// True when [error] came from a lost or missing connection, so the user
/// is told to check it. A write that failed this way may or may not have
/// reached the server; every write here can safely be tried again.
bool isNetworkError(Object error) =>
    (error is FirebaseException && _networkCodes.contains(error.code)) ||
    error is TimeoutException;
