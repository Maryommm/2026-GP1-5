// Ask Thamoor: the header shows only Thamoor's name, centred; his greeting
// has a round picture on the start side (right in Arabic, left in English);
// the send button is off until something is typed.
import 'package:ethmar/screens/chat_screen.dart';
import 'package:ethmar/screens/main_shell.dart' show isKeyboardOpen, keyboardMinHeight;
import 'package:ethmar/widgets/character.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> _open(WidgetTester tester, Locale locale) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const ChatScreen(username: 'Wajd'),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('the bar hides for a real keyboard only, not a thin IME toolbar', () {
    expect(isKeyboardOpen(0), isFalse);
    // Gboard's toolbar with a physical keyboard: 63 px at 2.625 = 24.
    expect(isKeyboardOpen(24), isFalse);
    expect(isKeyboardOpen(keyboardMinHeight - 1), isFalse);
    expect(isKeyboardOpen(keyboardMinHeight), isTrue);
    expect(isKeyboardOpen(280), isTrue);
  });

  testWidgets('the composer stays above the keyboard and comes back down',
      (tester) async {
    await _open(tester, const Locale('ar'));
    double fieldBottom() => tester.getBottomLeft(find.byType(TextField)).dy;
    final closed = fieldBottom();

    // Tapping focuses the field and it stays editable.
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isFalse);

    // A 300-high keyboard opens: the composer moves up above it.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    expect(fieldBottom(), lessThanOrEqualTo(800 - 300));
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), 'سؤال');
    await tester.pump();
    expect(find.text('سؤال'), findsOneWidget);

    // It closes: back where it was.
    tester.view.resetViewInsets();
    await tester.pump();
    expect(fieldBottom(), closed);
    expect(tester.takeException(), isNull);
  });

  for (final (locale, title, greeting, rtl) in [
    (const Locale('ar'), 'ثمور', 'مرحبًا Wajd، كيف أقدر أساعدك؟', true),
    (const Locale('en'), 'Thamoor', 'Hi Wajd, how can I help you?', false),
  ]) {
    testWidgets('$locale: header, greeting and avatar', (tester) async {
      await _open(tester, locale);
      expect(tester.takeException(), isNull);

      // The header: only the title, centred, 74 high (no status bar here).
      final header = find.byKey(const Key('chatHeader'));
      expect(tester.getSize(header).height, 74);
      expect(
        find.descendant(of: header, matching: find.byType(Text)),
        findsOneWidget,
      );
      expect(find.descendant(of: header, matching: find.text(title)),
          findsOneWidget);
      expect(find.descendant(of: header, matching: find.byType(Image)),
          findsNothing);
      expect(find.byType(EthmarCharacter), findsNothing);
      expect(
        tester.getCenter(find.text(title)).dx,
        closeTo(tester.getCenter(header).dx, 1),
      );

      // The greeting, with the user's name, and Thamoor's round picture.
      expect(find.text(greeting), findsOneWidget);
      final avatar = find.byKey(const Key('thamoorAvatar'));
      expect(tester.getSize(avatar), const Size(38, 38));
      final avatarX = tester.getCenter(avatar).dx;
      final bubbleX = tester.getCenter(find.text(greeting)).dx;
      expect(avatarX > bubbleX, rtl, reason: 'start side');
      // Level with the bubble's bottom, as in chat apps.
      expect(
        tester.getBottomLeft(avatar).dy,
        lessThanOrEqualTo(tester.getBottomLeft(find.text(greeting)).dy + 16),
      );

      // No placeholder; send is off until something is typed.
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration!.hintText, isNull);
      IconButton send() => tester.widget<IconButton>(find.byType(IconButton));
      expect(send().onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      expect(send().onPressed, isNotNull);
    });
  }
}
