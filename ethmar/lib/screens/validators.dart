import '../l10n/app_strings.dart';

// Check if the user's input follows the required rules.
class Validators {
  Validators._();

  // Check the email format.
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  // Allow 3 to 20 characters: letters, numbers, _ and .
  static final _usernameRe = RegExp(r'^[a-zA-Z0-9_.]{3,20}$');

  // Check if the username is entered and has a valid format.
  static String? username(String? v, S s) {
    final t = v?.trim() ?? '';

    if (t.isEmpty) return s.errUsernameRequired;
    if (!_usernameRe.hasMatch(t)) return s.errUsernameInvalid;

    return null;
  }

  // Check if the email is entered and has a valid format.
  static String? email(String? v, S s) {
    final t = v?.trim() ?? '';

    if (t.isEmpty) return s.errEmailRequired;
    if (!_emailRe.hasMatch(t)) return s.errEmailInvalid;

    return null;
  }

  // Check for a capital letter, number, and special character.
  static final _upperRe = RegExp(r'[A-Z]');
  static final _digitRe = RegExp(r'[0-9]');
  static final _specialRe = RegExp(r'[^A-Za-z0-9\s]');

  // Require 8 characters, a capital letter, a number, and a special character.
  static String? password(String? v, S s) {
    final t = v ?? '';

    if (t.isEmpty) return s.errPasswordRequired;

    final ok = t.length >= 8 &&
        _upperRe.hasMatch(t) &&
        _digitRe.hasMatch(t) &&
        _specialRe.hasMatch(t);

    return ok ? null : s.errPasswordWeak;
  }

  // Check that the password field is not empty.
  static String? passwordRequired(String? v, S s) =>
      (v == null || v.isEmpty) ? s.errPasswordRequired : null;
}