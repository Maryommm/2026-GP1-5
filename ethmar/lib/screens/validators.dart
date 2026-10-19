import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';

// Check if the user's input follows the required rules.
class Validators {
  Validators._();

  // Check the email format.
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  // The longest username. Typing simply stops here, with no error.
  static const usernameMaxLength = 30;

  // For the username field: stop at the maximum length and ignore "/",
  // which can't be used (the username is also a database document name).
  static final usernameFormatters = <TextInputFormatter>[
    FilteringTextInputFormatter.deny('/'),
    LengthLimitingTextInputFormatter(usernameMaxLength),
  ];

  // Any username is fine; it just can't be empty.
  static String? username(String? v, S s) {
    final t = v?.trim() ?? '';

    if (t.isEmpty) return s.errUsernameRequired;

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
  // The error lists only the rules that are still missing.
  static String? password(String? v, S s) {
    final t = v ?? '';

    if (t.isEmpty) return s.errPasswordRequired;

    final missing = [
      if (t.length < 8) s.errPasswordLength,
      if (!_upperRe.hasMatch(t)) s.errPasswordUpper,
      if (!_digitRe.hasMatch(t)) s.errPasswordDigit,
      if (!_specialRe.hasMatch(t)) s.errPasswordSpecial,
    ];

    return missing.isEmpty ? null : s.passwordNeeds(missing);
  }

  // Check that the password field is not empty.
  static String? passwordRequired(String? v, S s) =>
      (v == null || v.isEmpty) ? s.errPasswordRequired : null;
}