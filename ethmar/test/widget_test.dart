import 'package:flutter_test/flutter_test.dart';
import 'package:ethmar/l10n/app_strings.dart';

void main() {
  test('every English string has an Arabic twin', () {
    expect(AppStrings.en.keys.toSet(), AppStrings.ar.keys.toSet());
  });

  test('password reset confirmation does not reveal account existence', () {
    expect(
      AppStrings.en['resetLinkSent'],
      'If an account exists for this email, you will receive a password reset link.',
    );
    expect(
      AppStrings.ar['resetLinkSent'],
      'إذا كان هناك حساب مرتبط بهذا البريد الإلكتروني، فسيصلك رابط لإعادة تعيين كلمة المرور.',
    );
  });
}
