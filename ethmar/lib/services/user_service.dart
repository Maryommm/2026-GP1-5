import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'pending_username_store.dart';

// Store the current username and update the UI when it changes.
final ValueNotifier<String> currentUsername = ValueNotifier('');

// Error when the user's profile does not exist.
class UserProfileMissingException implements Exception {
  const UserProfileMissingException();
}

// Error when the user's profile contains invalid data.
class UserProfileInvalidException implements Exception {
  const UserProfileInvalidException();
}

// Error when the profile and username data do not match.
class UserProfileConflictException implements Exception {
  const UserProfileConflictException();
}

// Error when another user already has the username.
class UsernameAlreadyTakenException implements Exception {
  const UsernameAlreadyTakenException();
}

// Manage user profiles and usernames in Firestore.
class UserService {
  UserService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // Any username is allowed, as long as its lowercase form can be a
  // Firestore document name (it reserves the username): not empty, no "/",
  // not "." or "..", and not "__like_this__". The app stops typing at 30
  // characters; 100 leaves room for emoji, which count as several.
  // firestore.rules checks the same things.
  static bool _isAllowedUsername(String username) {
    final id = username.toLowerCase();
    return username.isNotEmpty &&
        username.length <= 100 &&
        !username.contains('/') &&
        id != '.' &&
        id != '..' &&
        !(id.startsWith('__') && id.endsWith('__'));
  }

  // Check if nobody has reserved this username yet. Works before sign up,
  // so the sign-up screen can check the name while the user types.
  // A name that can't be reserved at all also counts as unavailable.
  Future<bool> isUsernameAvailable(String username) async {
    final trimmedUsername = username.trim();
    if (!_isAllowedUsername(trimmedUsername)) return false;

    final snapshot = await _firestore
        .collection('usernames')
        .doc(trimmedUsername.toLowerCase())
        .get(const GetOptions(source: Source.server));
    return !snapshot.exists;
  }

  // Create a Firestore profile for the signed-in user.
  Future<void> createCurrentUserProfile({required String username}) async {
    final user = _auth.currentUser;
    final email = user?.email?.trim();
    final trimmedUsername = username.trim();

    // Use lowercase to prevent duplicate usernames.
    final normalizedUsername = trimmedUsername.toLowerCase();

    // Make sure the user is signed in.
    if (user == null) {
      throw StateError('No authenticated user is available.');
    }

    // Require email verification before creating a profile.
    if (!user.emailVerified) {
      throw StateError('The authenticated email is not verified.');
    }

    // Make sure the user has an email address.
    if (email == null || email.isEmpty) {
      throw StateError('The authenticated user has no email address.');
    }

    // Check that the username follows the required rules.
    if (!_isAllowedUsername(trimmedUsername)) {
      throw ArgumentError.value(username, 'username', 'Username is invalid.');
    }

    // Get the user's profile document.
    final profile = _firestore.collection('users').doc(user.uid);

    // Get the username reservation document.
    final reservation = _firestore
        .collection('usernames')
        .doc(normalizedUsername);

    // Create the profile and reserve the username together.
    await _firestore.runTransaction<void>((transaction) async {
      // Check if the username and profile already exist.
      final reservationSnapshot = await transaction.get(reservation);
      final profileSnapshot = await transaction.get(profile);

      if (reservationSnapshot.exists) {
        final reservationData = reservationSnapshot.data();
        final reservedUid = reservationData?['uid'];

        // Stop if the username reservation has invalid data.
        if (reservedUid is! String || reservationData?.length != 1) {
          throw const UserProfileConflictException();
        }

        // Stop if another user already owns this username.
        if (reservedUid != user.uid) {
          throw const UsernameAlreadyTakenException();
        }
      }

      // The profile and username reservation must both exist or both be new.
      if (reservationSnapshot.exists != profileSnapshot.exists) {
        throw const UserProfileConflictException();
      }

      if (profileSnapshot.exists) {
        final data = profileSnapshot.data();

        // Allow retrying if the saved profile already matches.
        if (data?.length == 4 &&
            data?['username'] == trimmedUsername &&
            data?['normalizedUsername'] == normalizedUsername &&
            data?['email'] == email &&
            data?['createdAt'] is Timestamp) {
          return;
        }

        // Stop if the existing profile has different data.
        throw const UserProfileConflictException();
      }

      // Reserve the username for this user.
      transaction.set(reservation, {'uid': user.uid});

      // Save the new user profile in Firestore.
      transaction.set(profile, {
        'username': trimmedUsername,
        'normalizedUsername': normalizedUsername,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    // The profile is saved, so the name kept from sign up is no longer needed.
    await PendingUsernameStore.clear(user.uid);

    // Update the username after saving the profile.
    currentUsername.value = trimmedUsername;
  }

  // For a verified account with no profile (the app closed during email
  // verification). Saves the profile with the username kept from sign up and
  // returns it. If that isn't possible, deletes the unfinished account so the
  // email can sign up again, and returns null.
  // Throws FirebaseAuthException 'requires-recent-login' if the account
  // can't be deleted until the user logs in again.
  Future<String?> finishUnfinishedSignUp() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user is available.');
    }

    final username = await PendingUsernameStore.read(user.uid);
    if (username != null) {
      try {
        await createCurrentUserProfile(username: username);
        return username.trim();
      } on UsernameAlreadyTakenException {
        // Someone took the name meanwhile; fall through and remove the account.
      } on ArgumentError {
        // The kept name can't be used; fall through and remove the account.
      }
    }

    // Ask the server, not the cache, before deleting anything.
    final profile = await _firestore
        .collection('users')
        .doc(user.uid)
        .get(const GetOptions(source: Source.server));
    if (profile.exists) {
      throw const UserProfileConflictException();
    }

    await user.delete();
    await PendingUsernameStore.clear(user.uid);
    return null;
  }

  // Get the current user's username from Firestore.
  Future<String> getCurrentUsername() async {
    final user = _auth.currentUser;
    final email = user?.email?.trim();

    // Require a signed-in user with a verified email.
    if (user == null || !user.emailVerified || email == null || email.isEmpty) {
      throw StateError('A verified authenticated user is required.');
    }

    // Read the user's profile from Firestore.
    final snapshot = await _firestore.collection('users').doc(user.uid).get();

    // Stop if the profile does not exist.
    if (!snapshot.exists) {
      throw const UserProfileMissingException();
    }

    // Get the saved profile information.
    final data = snapshot.data();
    final username = data?['username'];
    final normalizedUsername = data?['normalizedUsername'];
    final storedEmail = data?['email'];
    final createdAt = data?['createdAt'];

    // Check that the profile has valid and matching information.
    if (data?.length != 4 ||
        username is! String ||
        username != username.trim() ||
        !_isAllowedUsername(username) ||
        normalizedUsername is! String ||
        normalizedUsername != username.toLowerCase() ||
        storedEmail is! String ||
        storedEmail != email ||
        createdAt is! Timestamp) {
      throw const UserProfileInvalidException();
    }

    // Update the current username and return it.
    currentUsername.value = username;
    return username;
  }

  // Update the username and its reservation in Firestore.
  Future<void> updateCurrentUsername(String newUsername) async {
    final user = _auth.currentUser;
    final email = user?.email?.trim();
    final trimmedUsername = newUsername.trim();
    final normalizedUsername = trimmedUsername.toLowerCase();

    // Require a signed-in user with a verified email.
    if (user == null || !user.emailVerified || email == null || email.isEmpty) {
      throw StateError('A verified authenticated user is required.');
    }

    // Check the new username format.
    if (!_isAllowedUsername(trimmedUsername)) {
      throw ArgumentError.value(
        newUsername,
        'username',
        'Username is invalid.',
      );
    }

    // Get the user's profile document.
    final profile = _firestore.collection('users').doc(user.uid);

    // Get the new username reservation document.
    final newReservation = _firestore
        .collection('usernames')
        .doc(normalizedUsername);

    // Update the username safely using a Firestore transaction.
    await _firestore.runTransaction<void>((transaction) async {
      // Read the profile before making any changes.
      final profileSnapshot = await transaction.get(profile);
      final data = profileSnapshot.data();
      final oldUsername = data?['username'];
      final oldNormalizedUsername = data?['normalizedUsername'];

      // Stop if the current profile is missing or incomplete.
      if (!profileSnapshot.exists ||
          oldUsername is! String ||
          oldNormalizedUsername is! String) {
        throw const UserProfileMissingException();
      }

      // Do nothing if the username has not changed.
      if (oldUsername == trimmedUsername) return;

      // Update only the letters' case if the username is the same.
      if (oldNormalizedUsername == normalizedUsername) {
        transaction.update(profile, {'username': trimmedUsername});
        return;
      }

      // Get the old username reservation.
      final oldReservation = _firestore
          .collection('usernames')
          .doc(oldNormalizedUsername);

      // Check the new and old username reservations.
      final newReservationSnapshot = await transaction.get(newReservation);
      final oldReservationSnapshot = await transaction.get(oldReservation);

      if (newReservationSnapshot.exists) {
        // Stop if another user owns the new username.
        if (newReservationSnapshot.data()?['uid'] != user.uid) {
          throw const UsernameAlreadyTakenException();
        }

        // Stop if the new username is reserved but the data does not match.
        throw const UserProfileConflictException();
      }

      // Make sure the old username belongs to this user.
      if (oldReservationSnapshot.data()?['uid'] != user.uid) {
        throw const UserProfileConflictException();
      }

      // Reserve the new username.
      transaction.set(newReservation, {'uid': user.uid});

      // Update the username in the user's profile.
      transaction.update(profile, {
        'username': trimmedUsername,
        'normalizedUsername': normalizedUsername,
      });

      // Remove the old username reservation.
      transaction.delete(oldReservation);
    });

    // Update the username shown in the app.
    currentUsername.value = trimmedUsername;
  }
}