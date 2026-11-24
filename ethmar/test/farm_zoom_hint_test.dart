import 'package:ethmar/l10n/app_strings.dart';
import 'package:ethmar/screens/virtual_farm_screen.dart';
import 'package:ethmar/services/farm_store.dart';
import 'package:ethmar/services/sky_clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _hint = 'Pinch to Zoom';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _showFarm(WidgetTester tester, {Locale? locale}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const VirtualFarmScreen(),
    ),
  );
  await _settle(tester);
}

/// The farm's zoom right now.
double _scale(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byType(InteractiveViewer))
    .transformationController!
    .value
    .getMaxScaleOnAxis();

/// Sets the zoom as the app would, around the top-left corner.
void _setScale(WidgetTester tester, double scale) => tester
    .widget<InteractiveViewer>(find.byType(InteractiveViewer))
    .transformationController!
    .value = Matrix4.diagonal3Values(scale, scale, 1);

Future<bool?> _saved() async => (await SharedPreferences.getInstance())
    .getBool(VirtualFarmScreen.zoomHintDoneKey);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VirtualFarmScreen.resetZoomHintForTests();
    // A fixed daytime sky, without the phone's location.
    SkyClock.clockForTests = () => SkyClock(
      now: () => DateTime(2026, 1, 1, 12),
      locate: () async => null,
      followApp: false,
    );
    FarmStore.lands.value = 1;
    FarmStore.plants.value = const [];
    FarmStore.plantsLoaded.value = false;
  });

  tearDown(() {
    SkyClock.clockForTests = null;
    SkyClock.resetForTests();
    VirtualFarmScreen.resetZoomHintForTests();
  });

  group('Pinch to Zoom hint', () {
    testWidgets('shows on the first visit', (tester) async {
      await _showFarm(tester);
      expect(find.text(_hint), findsOneWidget);
      expect(await _saved(), isNull);
    });

    testWidgets('panning, tapping and recentering leave it', (tester) async {
      await _showFarm(tester);

      await tester.drag(find.byType(InteractiveViewer), const Offset(-80, 60));
      await _settle(tester);
      await tester.tap(find.byType(InteractiveViewer));
      await _settle(tester);
      await tester.tap(find.byTooltip('Reset view'));
      await _settle(tester);

      expect(find.text(_hint), findsOneWidget);
      expect(await _saved(), isNull);
    });

    testWidgets('the + button hides it for good', (tester) async {
      await _showFarm(tester);
      await tester.tap(find.byTooltip('Zoom in'));
      await _settle(tester);

      expect(_scale(tester), greaterThan(1));
      expect(find.text(_hint), findsNothing);
      expect(await _saved(), isTrue);
    });

    testWidgets('the − button hides it too', (tester) async {
      await _showFarm(tester);
      // Zoomed in by the app, not the user: that alone doesn't count.
      _setScale(tester, 2);
      await _settle(tester);
      expect(find.text(_hint), findsOneWidget);

      await tester.tap(find.byTooltip('Zoom out'));
      await _settle(tester);

      expect(_scale(tester), lessThan(2));
      expect(find.text(_hint), findsNothing);
      expect(await _saved(), isTrue);
    });

    testWidgets('a two-finger pinch hides it', (tester) async {
      await _showFarm(tester);
      final middle = tester.getCenter(find.byType(InteractiveViewer));
      final a = await tester.startGesture(middle - const Offset(40, 0));
      final b = await tester.startGesture(middle + const Offset(40, 0));
      for (var i = 0; i < 10; i++) {
        await a.moveBy(const Offset(-10, 0));
        await b.moveBy(const Offset(10, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await a.up();
      await b.up();
      await _settle(tester);

      expect(_scale(tester), greaterThan(1));
      expect(find.text(_hint), findsNothing);
      expect(await _saved(), isTrue);
    });

    testWidgets('a − that the farm holds back changes nothing, so it stays', (
      tester,
    ) async {
      // The farm starts as far out as the viewer lets it go, so − here
      // doesn't change the zoom.
      await _showFarm(tester);
      await tester.tap(find.byTooltip('Zoom out'));
      await _settle(tester);
      expect(_scale(tester), closeTo(1, 0.001));
      expect(find.text(_hint), findsOneWidget);
      expect(await _saved(), isNull);
    });

    testWidgets('once zoomed, it stays hidden on later visits', (
      tester,
    ) async {
      await _showFarm(tester);
      await tester.tap(find.byTooltip('Zoom in'));
      await _settle(tester);

      // Leave the farm, then come back after a restart (nothing in memory).
      await tester.pumpWidget(const SizedBox());
      VirtualFarmScreen.resetZoomHintForTests();
      await _showFarm(tester);
      expect(find.text(_hint), findsNothing);
    });

    testWidgets('a user who zoomed before never sees it', (tester) async {
      SharedPreferences.setMockInitialValues({
        VirtualFarmScreen.zoomHintDoneKey: true,
      });
      await _showFarm(tester);
      expect(find.text(_hint), findsNothing);
    });

    testWidgets('a user who never zoomed still sees it when back', (
      tester,
    ) async {
      await _showFarm(tester);
      await tester.pumpWidget(const SizedBox());
      VirtualFarmScreen.resetZoomHintForTests();
      await _showFarm(tester);
      expect(find.text(_hint), findsOneWidget);
    });
  });

  group('labels', () {
    testWidgets('the farm in English', (tester) async {
      await _showFarm(tester, locale: const Locale('en'));
      expect(find.text('My Farm'), findsOneWidget);
      expect(find.text('Pinch to Zoom'), findsOneWidget);
    });

    testWidgets('the farm in Arabic, right to left', (tester) async {
      await _showFarm(tester, locale: const Locale('ar'));
      expect(find.text('مزرعتي'), findsOneWidget);
      expect(find.text('كبّر وصغّر بإصبعين'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('مزرعتي'))),
        TextDirection.rtl,
      );
    });

    test('the tab and the diagnosis card, in both languages', () {
      final en = S(AppStrings.en), ar = S(AppStrings.ar);
      expect(en.navVirtualFarm, 'My Farm');
      expect(ar.navVirtualFarm, 'مزرعتي');
      expect(en.farmTitle, 'My Farm');
      expect(ar.farmTitle, 'مزرعتي');
      expect(en.homeCardDiagnosis, 'Plant Diagnosis');
      expect(ar.homeCardDiagnosis, 'تشخيص نبتة');
      expect(en.farmPinchHint, 'Pinch to Zoom');
      expect(ar.farmPinchHint, 'كبّر وصغّر بإصبعين');
    });
  });
}
