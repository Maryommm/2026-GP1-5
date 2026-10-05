import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

final ValueNotifier<String> currentUsername = ValueNotifier('');

class UserProfileMissingException implements Exception {
  const UserProfileMissingException();
}

class UserProfileInvalidException implements Exception {
  const UserProfileInvalidException();
}

class UserProfileConflictException implements Exception {
  const UserProfileConflictException();
}

class UsernameAlreadyTakenException implements Exception {
  const UsernameAlreadyTakenException();
}

class UserService {
  UserService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  static final _usernamePattern = RegExp(r'^[a-zA-Z0-9_.]{3,20}$');

  Future<void> createCurrentUserProfile({required String username}) async {
    final user = _auth.currentUser;
    final email = user?.email?.trim();
    final trimmedUsername = username.trim();
    // Keep username checks case-insensitive.
    final normalizedUsername = trimmedUsername.toLowerCase();

    if (user == null) {
      throw StateError('No authenticated user is available.');
    }
    if (!user.emailVerified) {
      throw StateError('The authenticated email is not verified.');
    }
    if (email == null || email.isEmpty) {
      throw StateError('The authenticated user has no email address.');
    }
    if (!_usernamePattern.hasMatch(trimmedUsername)) {
      throw ArgumentError.value(username, 'username', 'Username is invalid.');
    }

    final profile = _firestore.collection('users').doc(user.uid);
    final reservation = _firestore
        .collection('usernames')
        .doc(normalizedUsername);
    // Reserve the username and create the profile as one atomic write.
    await _firestore.runTransaction<void>((transaction) async {
      final reservationSnapshot = await transaction.get(reservation);
      final profileSnapshot = await transaction.get(profile);

      if (reservationSnapshot.exists) {
        final reservationData = reservationSnapshot.data();
        final reservedUid = reservationData?['uid'];
        if (reservedUid is! String || reservationData?.length != 1) {
          throw const UserProfileConflictException();
        }
        if (reservedUid != user.uid) {
          throw const UsernameAlreadyTakenException();
        }
      }

      if (reservationSnapshot.exists != profileSnapshot.exists) {
        throw const UserProfileConflictException();
      }

      if (profileSnapshot.exists) {
        final data = profileSnapshot.data();
        // Matching documents make profile creation safe to retry.
        if (data?.length == 4 &&
            data?['username'] == trimmedUsername &&
            data?['normalizedUsername'] == normalizedUsername &&
            data?['email'] == email &&
            data?['createdAt'] is Timestamp) {
          return;
        }
        throw const UserProfileConflictException();
      }

      transaction.set(reservation, {'uid': user.uid});
      transaction.set(profile, {
        'username': trimmedUsername,
        'normalizedUsername': normalizedUsername,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    currentUsername.value = trimmedUsername;
  }

  Future<String> getCurrentUsername() async {
    final user = _auth.currentUser;
    final email = user?.email?.trim();
    if (user == null || !user.emailVerified || email == null || email.isEmpty) {
      throw StateError('A verified authenticated user is required.');
    }

    final snapshot = await _firestore.collection('users').doc(user.uid).get();
    if (!snapshot.exists) {
      throw const UserProfileMissingException();
    }

    final data = snapshot.data();
    final username = data?['username'];
    final normalizedUsername = data?['normalizedUsername'];
    final storedEmail = data?['email'];
    final createdAt = data?['createdAt'];
    if (data?.length != 4 ||
        username is! String ||
        username != username.trim() ||
        !_usernamePattern.hasMatch(username) ||
        normalizedUsername is! String ||
        normalizedUsername != username.toLowerCase() ||
        storedEmail is! String ||
        storedEmail != email ||
        createdAt is! Timestamp) {
      throw const UserProfileInvalidException();
    }

    currentUsername.value = username;
    return username;
  }

  /// Changes the signed-in user's username.
  ///
  /// Uniqueness is case-insensitive: the reservation document's ID is the
  /// lowercased name, so Fanar / fanar / FANAR all share `usernames/fanar`.
  /// * Only the capitalization changed: the reservation is already ours,
  ///   so just `username` is updated.
  /// * New name: reserve it, update both username fields and release the
  ///   old reservation, all in one transaction.
  /// * Name reserved by another account: [UsernameAlreadyTakenException].
  Future<void> updateCurrentUsername(String newUsername) async {
    final user = _auth.currentUser;
    final email = user?.email?.trim();
    final trimmedUsername = newUsername.trim();
    final normalizedUsername = trimmedUsername.toLowerCase();

    if (user == null || !user.emailVerified || email == null || email.isEmpty) {
      throw StateError('A verified authenticated user is required.');
    }
    if (!_usernamePattern.hasMatch(trimmedUsername)) {
      throw ArgumentError.value(
        newUsername,
        'username',
        'Username is invalid.',
      );
    }

    final profile = _firestore.collection('users').doc(user.uid);
    final newReservation = _firestore
        .collection('usernames')
        .doc(normalizedUsername);

    await _firestore.runTransaction<void>((transaction) async {
      // All reads come before any writes in a transaction.
      final profileSnapshot = await transaction.get(profile);
      final data = profileSnapshot.data();
      final oldUsername = data?['username'];
      final oldNormalizedUsername = data?['normalizedUsername'];
      if (!profileSnapshot.exists ||
          oldUsername is! String ||
          oldNormalizedUsername is! String) {
        throw const UserProfileMissingException();
      }

      // Nothing changed: no write needed.
      if (oldUsername == trimmedUsername) return;

      // Same name, different capitalization: keep our reservation.
      if (oldNormalizedUsername == normalizedUsername) {
        transaction.update(profile, {'username': trimmedUsername});
        return;
      }

      final oldReservation = _firestore
          .collection('usernames')
          .doc(oldNormalizedUsername);
      final newReservationSnapshot = await transaction.get(newReservation);
      final oldReservationSnapshot = await transaction.get(oldReservation);

      if (newReservationSnapshot.exists) {
        if (newReservationSnapshot.data()?['uid'] != user.uid) {
          throw const UsernameAlreadyTakenException();
        }
        // Reserved for us but not used by our profile: data is out of sync.
        throw const UserProfileConflictException();
      }
      if (oldReservationSnapshot.data()?['uid'] != user.uid) {
        throw const UserProfileConflictException();
      }

      transaction.set(newReservation, {'uid': user.uid});
      transaction.update(profile, {
        'username': trimmedUsername,
        'normalizedUsername': normalizedUsername,
      });
      transaction.delete(oldReservation);
    });

    currentUsername.value = trimmedUsername;
  }
}
