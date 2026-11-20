import 'package:ethmar/l10n/app_strings.dart';
import 'package:ethmar/screens/validators.dart';
import 'package:ethmar/theme/app_colors.dart';
import 'package:ethmar/widgets/password_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  final s = S(AppStrings.en);

  group('Validators.newPassword', () {
    test('empty asks for a password', () {
      expect(Validators.newPassword('', s), s.errPasswordRequired);
    });

    test('accepted only when every rule is followed', () {
      expect(Validators.newPassword('Seed@12', s), s.errPasswordRules);
      expect(Validators.newPassword('seed@123', s), s.errPasswordRules);
      expect(Validators.newPassword('Seed@abc', s), s.errPasswordRules);
      expect(Validators.newPassword('Seed1234', s), s.errPasswordRules);
      expect(Validators.newPassword('Seed@123', s), isNull);
    });

    test('each rule is checked on its own', () {
      bool met(PasswordRule r, String p) => Validators.passwordRuleMet(r, p);
      expect(met(PasswordRule.length, 'abcdefgh'), isTrue);
      expect(met(PasswordRule.length, 'abcdefg'), isFalse);
      expect(met(PasswordRule.upper, 'aB'), isTrue);
      expect(met(PasswordRule.upper, 'ab'), isFalse);
      expect(met(PasswordRule.digit, 'a1'), isTrue);
      expect(met(PasswordRule.digit, 'ab'), isFalse);
      expect(met(PasswordRule.special, 'a!'), isTrue);
      expect(met(PasswordRule.special, 'a b'), isFalse);
      // Only English symbols count: Arabic letters and other non-English
      // characters are not special characters.
      expect(met(PasswordRule.special, 'Abcdefg1ب'), isFalse);
      expect(met(PasswordRule.special, 'aé'), isFalse);
      for (final c in r'''!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~'''.split('')) {
        expect(met(PasswordRule.special, 'a$c'), isTrue, reason: c);
      }
    });
  });

  group('PasswordRules', () {
    late TextEditingController controller;

    setUp(() => controller = TextEditingController());
    tearDown(() => controller.dispose());

    Future<void> pump(WidgetTester tester) => tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: PasswordRules(controller: controller)),
          ),
        );

    /// The rule's text colour.
    Color? colourOf(WidgetTester tester, PasswordRule rule) {
      final text = find.descendant(
        of: find.byKey(Key('passwordRule_${rule.name}')),
        matching: find.text(rule.label(s)),
      );
      return DefaultTextStyle.of(tester.element(text)).style.color;
    }

    Finder ticks() => find.byIcon(Icons.check_circle_rounded);

    testWidgets('every rule is listed, dim, before typing', (tester) async {
      await pump(tester);
      for (final rule in PasswordRule.values) {
        expect(find.text(rule.label(s)), findsOneWidget);
        expect(colourOf(tester, rule), isNot(AppColors.success));
      }
      expect(ticks(), findsNothing);
    });

    testWidgets('a rule turns green as soon as it is followed', (
      tester,
    ) async {
      await pump(tester);

      controller.text = 'A';
      await tester.pumpAndSettle();
      expect(colourOf(tester, PasswordRule.upper), AppColors.success);
      expect(colourOf(tester, PasswordRule.digit), isNot(AppColors.success));
      expect(ticks(), findsOneWidget);

      controller.text = 'Seed@123';
      await tester.pumpAndSettle();
      for (final rule in PasswordRule.values) {
        expect(colourOf(tester, rule), AppColors.success);
      }
      expect(ticks(), findsNWidgets(PasswordRule.values.length));

      // Deleting goes back to dim.
      controller.text = 'Seed';
      await tester.pumpAndSettle();
      expect(colourOf(tester, PasswordRule.length), isNot(AppColors.success));
      expect(colourOf(tester, PasswordRule.upper), AppColors.success);
    });
  });
}
