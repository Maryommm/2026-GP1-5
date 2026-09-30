import '../l10n/app_strings.dart';

class Validators {
  Validators._();

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  static String? name(String? v, S s) =>
      (v == null || v.trim().isEmpty) ? s.errNameRequired : null;

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
