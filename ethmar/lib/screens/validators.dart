import '../l10n/app_strings.dart';

class Validators {
  Validators._();

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  static final _usernameRe = RegExp(r'^[a-zA-Z0-9_.]{3,20}$');

  static String? username(String? v, S s) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return s.errUsernameRequired;
    if (!_usernameRe.hasMatch(t)) return s.errUsernameInvalid;
    return null;
  }

  static String? email(String? v, S s) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return s.errEmailRequired;
    if (!_emailRe.hasMatch(t)) return s.errEmailInvalid;
    return null;
  }

  static final _upperRe = RegExp(r'[A-Z]');
  static final _digitRe = RegExp(r'[0-9]');
  static final _specialRe = RegExp(r'[^A-Za-z0-9\s]');

  /// Sign-up rules: 8+ characters, one capital, one number, one special.
  static String? password(String? v, S s) {
    final t = v ?? '';
    if (t.isEmpty) return s.errPasswordRequired;
    final ok = t.length >= 8 &&
        _upperRe.hasMatch(t) &&
        _digitRe.hasMatch(t) &&
        _specialRe.hasMatch(t);
    return ok ? null : s.errPasswordWeak;
  }

  static String? passwordRequired(String? v, S s) =>
      (v == null || v.isEmpty) ? s.errPasswordRequired : null;
}
