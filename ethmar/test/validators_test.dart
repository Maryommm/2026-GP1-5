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

    test('login only asks that a password was entered', () {
      expect(Validators.passwordRequired('', s), s.errPasswordRequired);
      expect(Validators.passwordRequired(null, s), s.errPasswordRequired);
      expect(Validators.passwordRequired('x', s), isNull);
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

  group('Validators.username', () {
    test('accepts any username that is not empty', () {
      expect(Validators.username('N', s), isNull);
      expect(Validators.username('Fanar_2.0', s), isNull);
      expect(Validators.username('  fanar  ', s), isNull);
      expect(Validators.username('fanar user', s), isNull);
      expect(Validators.username('fanar-user', s), isNull);
      expect(Validators.username('فَنار', s), isNull);
    });
  });

  group('Validators.password', () {
    test('rejects an empty password', () {
      expect(Validators.password('', s), s.errPasswordRequired);
    });

    test('one missing rule is a single sentence', () {
      final needs = s.passwordNeeds;
      expect(
        Validators.password('Seed@12', s),
        needs([s.errPasswordLength]),
      );
      expect(Validators.password('seed@123', s), needs([s.errPasswordUpper]));
      expect(Validators.password('Seed@abc', s), needs([s.errPasswordDigit]));
      expect(
        Validators.password('Seed1234', s),
        needs([s.errPasswordSpecial]),
      );
      // A space isn't a special character.
      expect(
        Validators.password('Seed 1234', s),
        needs([s.errPasswordSpecial]),
      );
      expect(
        Validators.password('Seed@12', s),
        'Your password needs at least 8 characters',
      );
    });

    test('several missing rules are listed as bullet points', () {
      expect(
        Validators.password('seed', s),
        'Your password needs:\n'
        '• at least 8 characters\n'
        '• a capital letter\n'
        '• a number\n'
        '• a special character (like ! or @)',
      );
    });

    test('accepts a password that meets every rule', () {
      expect(Validators.password('Seed@123', s), isNull);
    });
  });
}
