import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';

// The rules a new password must follow, in the order they're listed.
enum PasswordRule {
  length,
  upper,
  digit,
  special;

  // "at least 8 characters", "a capital letter"...
  String label(S s) => switch (this) {
        PasswordRule.length => s.errPasswordLength,
        PasswordRule.upper => s.errPasswordUpper,
        PasswordRule.digit => s.errPasswordDigit,
        PasswordRule.special => s.errPasswordSpecial,
      };
}

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
  // Only English keyboard symbols count, so Arabic letters or other non-English
  // characters can't stand in for a special character.
  static final _specialRe = RegExp(r'''[!"#$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~]''');

  // Whether [password] follows [rule]. The sign-up checklist and the checks
  // below both use this, so they always agree.
  static bool passwordRuleMet(PasswordRule rule, String password) =>
      switch (rule) {
        PasswordRule.length => password.length >= 8,
        PasswordRule.upper => _upperRe.hasMatch(password),
        PasswordRule.digit => _digitRe.hasMatch(password),
        PasswordRule.special => _specialRe.hasMatch(password),
      };

  // Passwords may only use English letters, numbers, symbols and spaces
  // (the characters on an English keyboard).
  static final _englishOnlyRe = RegExp(r'^[\x20-\x7E]*$');

  static bool isEnglishOnly(String password) =>
      _englishOnlyRe.hasMatch(password);

  // Require 8 characters, a capital letter, a number, and a special character.
  // The error lists only the rules that are still missing.
  static String? password(String? v, S s) {
    final t = v ?? '';

    if (t.isEmpty) return s.errPasswordRequired;
    if (!isEnglishOnly(t)) return s.errPasswordEnglishOnly;

    final missing = [
      for (final rule in PasswordRule.values)
        if (!passwordRuleMet(rule, t)) rule.label(s),
    ];

    return missing.isEmpty ? null : s.passwordNeeds(missing);
  }

  // Sign-up, where the checklist under the field already shows which rules
  // are missing: the error only says that some are.
  static String? newPassword(String? v, S s) {
    final t = v ?? '';
    if (t.isEmpty) return s.errPasswordRequired;
    if (!isEnglishOnly(t)) return s.errPasswordEnglishOnly;
    final allMet = PasswordRule.values.every((r) => passwordRuleMet(r, t));
    return allMet ? null : s.errPasswordRules;
  }

  // Check that the password field is not empty.
  static String? passwordRequired(String? v, S s) =>
      (v == null || v.isEmpty) ? s.errPasswordRequired : null;
}