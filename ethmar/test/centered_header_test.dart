import 'package:ethmar/widgets/centered_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const screenWidth = 390.0;

  // Two round buttons, as on My Plants: wider than the back button.
  Widget twoActions() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        key: const Key('a1'),
        onPressed: () {},
        icon: const Icon(Icons.checklist_rounded),
      ),
      const SizedBox(width: 8),
      IconButton(
        key: const Key('a2'),
        onPressed: () {},
        icon: const Icon(Icons.tune_rounded),
      ),
    ],
  );

  Future<void> pumpHeader(
    WidgetTester tester, {
    required TextDirection direction,
    bool showBack = true,
    Widget? trailing,
    String? subtitle,
  }) async {
    tester.view.physicalSize = const Size(screenWidth, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EthmarCenteredHeader(
                  title: 'My plants',
                  subtitle: subtitle,
                  showBack: showBack,
                  trailing: trailing,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double centreX(WidgetTester tester, Finder f) => tester.getCenter(f).dx;

  for (final direction in TextDirection.values) {
    group('$direction', () {
      testWidgets('the title is centred on the screen with uneven sides', (
        tester,
      ) async {
        await pumpHeader(tester, direction: direction, trailing: twoActions());
        expect(
          centreX(tester, find.text('My plants')),
          moreOrLessEquals(screenWidth / 2, epsilon: 0.5),
        );
      });

      testWidgets('the title stays centred without a back button', (
        tester,
      ) async {
        await pumpHeader(
          tester,
          direction: direction,
          showBack: false,
          trailing: twoActions(),
        );
        expect(
          centreX(tester, find.text('My plants')),
          moreOrLessEquals(screenWidth / 2, epsilon: 0.5),
        );
      });

      testWidgets('the subtitle is centred under the title', (tester) async {
        await pumpHeader(
          tester,
          direction: direction,
          subtitle: 'everything growing on your farm',
          trailing: twoActions(),
        );
        final title = tester.getRect(find.text('My plants'));
        final subtitle = tester.getRect(
          find.text('everything growing on your farm'),
        );
        expect(
          subtitle.center.dx,
          moreOrLessEquals(screenWidth / 2, epsilon: 0.5),
        );
        expect(subtitle.top, greaterThanOrEqualTo(title.bottom));
      });

      testWidgets('back is on the start side, actions on the end side', (
        tester,
      ) async {
        await pumpHeader(tester, direction: direction, trailing: twoActions());
        final back = centreX(tester, find.byTooltip('Back'));
        final action = centreX(tester, find.byKey(const Key('a2')));
        if (direction == TextDirection.ltr) {
          expect(back, lessThan(screenWidth / 2));
          expect(action, greaterThan(screenWidth / 2));
        } else {
          expect(back, greaterThan(screenWidth / 2));
          expect(action, lessThan(screenWidth / 2));
        }
      });

      testWidgets('the side buttons can be tapped', (tester) async {
        var tapped = 0;
        await pumpHeader(
          tester,
          direction: direction,
          trailing: IconButton(
            key: const Key('action'),
            onPressed: () => tapped++,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        );
        await tester.tap(find.byKey(const Key('action')));
        expect(tapped, 1);
      });
    });
  }
}
