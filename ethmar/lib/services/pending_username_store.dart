import 'package:shared_preferences/shared_preferences.dart';

// Saves the username chosen at sign up until the profile is created, so the
// app can finish the profile if it closes during email verification.
class PendingUsernameStore {
  PendingUsernameStore._();

  static String _key(String uid) => 'pending_username_$uid';

  static Future<void> save(String uid, String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(uid), username);
    } catch (_) {
      // Sign up still works; only the recovery after a restart is lost.
    }
  }

  static Future<String?> read(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_key(uid));
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(uid));
    } catch (_) {
      // A leftover name is harmless because it's only used when no profile exists.
    }
  }
}
