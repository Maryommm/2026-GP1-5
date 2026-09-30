import 'package:ethmar/l10n/app_strings.dart';
import 'package:ethmar/screens/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final s = S(AppStrings.en);

  group('required fields', () {
    test('an empty or blank field shows its "required" error', () {
      expect(Validators.username('', s), s.errUsernameRequired);
      expect(Validators.username('   ', s), s.errUsernameRequired);
      expect(Validators.email('', s), s.errEmailRequired);
      expect(Validators.email('   ', s), s.errEmailRequired);
      expect(Validators.password('', s), s.errPasswordRequired);
    });
  });

  group('Validators.email', () {
    test('rejects an email missing "@"', () {
      expect(Validators.email('noora.gmail.com', s), s.errEmailInvalid);
    });

    test('rejects an email missing the domain name', () {
      expect(Validators.email('noora@', s), s.errEmailInvalid);
      expect(Validators.email('noora@gmail', s), s.errEmailInvalid);
      expect(Validators.email('noora@.com', s), s.errEmailInvalid);
    });

    test('rejects an email missing the part before "@"', () {
      expect(Validators.email('@gmail.com', s), s.errEmailInvalid);
    });

    test('accepts a well-formed email', () {
      expect(Validators.email('noora@gmail.com', s), isNull);
      expect(Validators.email('  noora@gmail.com  ', s), isNull);
    });
  });

  group('Validators.password', () {
    test('rejects an empty password', () {
      expect(Validators.password('', s), s.errPasswordRequired);
    });

    test('rejects a password missing any one rule', () {
      expect(Validators.password('Seed@12', s), s.errPasswordWeak); // < 8
      expect(Validators.password('seed@123', s), s.errPasswordWeak); // no capital
      expect(Validators.password('Seed@abc', s), s.errPasswordWeak); // no number
      expect(Validators.password('Seed1234', s), s.errPasswordWeak); // no special
      expect(Validators.password('Seed 1234', s), s.errPasswordWeak); // space isn't special
    });

    test('accepts a password that meets every rule', () {
      expect(Validators.password('Seed@123', s), isNull);
    });
  });
}
