import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

    return username;
  }
}
