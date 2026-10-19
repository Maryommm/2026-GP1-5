import 'package:ethmar/l10n/app_strings.dart';
import 'package:ethmar/screens/validators.dart';
import 'package:ethmar/widgets/ethmar_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  final s = S(AppStrings.en);
  final form = GlobalKey<FormState>();

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpField(WidgetTester tester) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: form,
              child: EthmarTextField(
                label: 'Password',
                hint: '',
                validator: (v) => Validators.password(v, s),
              ),
            ),
          ),
        ),
      );

  testWidgets('errors wait until two seconds after typing stops',
      (tester) async {
    await pumpField(tester);
    final weak = Validators.password('seed', s)!;

    await tester.enterText(find.byType(TextFormField), 'seed');
    await tester.pump();
    expect(find.text(weak), findsNothing);

    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text(weak), findsNothing);

    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(weak), findsOneWidget);

    // Typing again hides the error straight away.
    await tester.enterText(find.byType(TextFormField), 'seedS');
    await tester.pump();
    expect(find.text(weak), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('an empty field only complains when the form is checked',
      (tester) async {
    await pumpField(tester);

    await tester.enterText(find.byType(TextFormField), 'x');
    await tester.enterText(find.byType(TextFormField), '');
    await tester.pump(const Duration(seconds: 3));
    expect(find.text(s.errPasswordRequired), findsNothing);

    // The button checks the whole form.
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text(s.errPasswordRequired), findsOneWidget);
  });

  testWidgets('pressing the button while typing still checks the field',
      (tester) async {
    await pumpField(tester);

    await tester.enterText(find.byType(TextFormField), 'seed');
    expect(form.currentState!.validate(), isFalse);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text(Validators.password('seed', s)!), findsOneWidget);
  });
}
