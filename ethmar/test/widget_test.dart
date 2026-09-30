import 'package:flutter_test/flutter_test.dart';
import 'package:ethmar/l10n/app_strings.dart';

void main() {
  test('every English string has an Arabic twin', () {
    expect(AppStrings.en.keys.toSet(), AppStrings.ar.keys.toSet());
  });
}
