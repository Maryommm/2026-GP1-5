import '../l10n/app_strings.dart';

class Validators {
  Validators._();

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  static final _usernameRe = RegExp(r'^[a-zA-Z0-9_.]{3,20}$');

  static String? username(String? v, S s) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return s.errUsernameRequired;
    if (!_usernameRe.hasMatch(t)) return s.errUsernameInvalid;
    // TODO(firebase): Uniqueness can't be checked here. In SignUpScreen._submit,
    // check Firestore (e.g. a `usernames/{lowercased}` doc) before creating the
    // account, and show s.errUsernameTaken if it already exists.
    return null;
  }

  static String? email(String? v, S s) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return s.errEmailRequired;
    if (!_emailRe.hasMatch(t)) return s.errEmailInvalid;
    return null;
  }

  static String? password(String? v, S s) {
    final t = v ?? '';
    if (t.isEmpty) return s.errPasswordRequired;
    if (t.length < 8) return s.errPasswordShort;
    return null;
  }

  static String? passwordRequired(String? v, S s) =>
      (v == null || v.isEmpty) ? s.errPasswordRequired : null;
}
