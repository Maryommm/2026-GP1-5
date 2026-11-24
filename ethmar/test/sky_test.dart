import 'package:ethmar/screens/virtual_farm_screen.dart';
import 'package:ethmar/services/farm_store.dart';
import 'package:ethmar/services/sky_clock.dart';
import 'package:ethmar/services/sun_times.dart';
import 'package:ethmar/widgets/farm_sky.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const SkyPlace riyadh = (latitude: 24.7136, longitude: 46.6753);
const SkyPlace london = (latitude: 51.5074, longitude: -0.1278);
const SkyPlace losAngeles = (latitude: 34.0522, longitude: -118.2437);
const SkyPlace tromso = (latitude: 69.6492, longitude: 18.9553);

/// [actual] is within [minutes] of [expected] (both compared in UTC, so the
/// tests don't depend on the computer's time zone).
void expectNear(DateTime? actual, DateTime expected, {int minutes = 3}) {
  expect(actual, isNotNull);
  final off = actual!.toUtc().difference(expected).inSeconds.abs();
  expect(
    off,
    lessThanOrEqualTo(minutes * 60),
    reason: 'got ${actual.toUtc()}, expected about $expected',
  );
}

/// The local calendar day that [utc] falls on.
DateTime localDay(DateTime utc) => utc.toLocal();

void main() {
  group('sunrise and sunset', () {
    test('Riyadh, midsummer', () {
      final t = SunTimes.on(localDay(DateTime.utc(2026, 6, 21, 9)), riyadh);
      expectNear(t.sunrise, DateTime.utc(2026, 6, 21, 2, 4));
      expectNear(t.sunset, DateTime.utc(2026, 6, 21, 15, 47));
    });

    test('London, midwinter', () {
      final t = SunTimes.on(localDay(DateTime.utc(2026, 12, 21, 12)), london);
      expectNear(t.sunrise, DateTime.utc(2026, 12, 21, 8, 4));
      expectNear(t.sunset, DateTime.utc(2026, 12, 21, 15, 53));
    });

    test('west of Greenwich, sunset falls on the next UTC day', () {
      final t = SunTimes.on(
        localDay(DateTime.utc(2026, 3, 20, 20)),
        losAngeles,
      );
      expectNear(t.sunrise, DateTime.utc(2026, 3, 20, 13, 57), minutes: 5);
      expectNear(t.sunset, DateTime.utc(2026, 3, 21, 2, 5), minutes: 5);
    });

    test('the far north: no sunrise in winter, no sunset in summer', () {
      final winter = SunTimes.on(localDay(DateTime.utc(2026, 12, 21, 12)), tromso);
      expect(winter.alwaysDown, isTrue);
      expect(winter.sunrise, isNull);
      final summer = SunTimes.on(localDay(DateTime.utc(2026, 6, 21, 12)), tromso);
      expect(summer.alwaysUp, isTrue);
    });
  });

  group('day or night at a known place', () {
    test('before sunrise is night, until sunrise', () {
      final s = skyAt(DateTime.utc(2026, 6, 21, 1).toLocal(), place: riyadh);
      expect(s.phase, SkyPhase.night);
      expectNear(s.nextChange, DateTime.utc(2026, 6, 21, 2, 4));
    });

    test('between sunrise and sunset is day, until sunset', () {
      final s = skyAt(DateTime.utc(2026, 6, 21, 10).toLocal(), place: riyadh);
      expect(s.phase, SkyPhase.day);
      expectNear(s.nextChange, DateTime.utc(2026, 6, 21, 15, 47));
    });

    test("after sunset is night, until tomorrow's sunrise", () {
      final s = skyAt(DateTime.utc(2026, 6, 21, 16).toLocal(), place: riyadh);
      expect(s.phase, SkyPhase.night);
      expectNear(s.nextChange, DateTime.utc(2026, 6, 22, 2, 4));
    });

    test('exactly at sunrise it is day; exactly at sunset, night', () {
      final t = SunTimes.on(localDay(DateTime.utc(2026, 6, 21, 9)), riyadh);
      expect(skyAt(t.sunrise!, place: riyadh).phase, SkyPhase.day);
      expect(skyAt(t.sunset!, place: riyadh).phase, SkyPhase.night);
    });

    test('a 6 pm sunset in London winter is already night', () {
      final s = skyAt(DateTime.utc(2026, 12, 21, 17).toLocal(), place: london);
      expect(s.phase, SkyPhase.night);
    });

    test('polar day and night', () {
      final noon = DateTime.utc(2026, 12, 21, 11).toLocal();
      expect(skyAt(noon, place: tromso).phase, SkyPhase.night);
      final midnight = DateTime.utc(2026, 6, 21, 23).toLocal();
      expect(skyAt(midnight, place: tromso).phase, SkyPhase.day);
    });
  });

  group('without a place: day from 06:00 to 18:00', () {
    test('the four parts of the day', () {
      var s = skyAt(DateTime(2026, 1, 1, 5, 59));
      expect(s.phase, SkyPhase.night);
      expect(s.nextChange, DateTime(2026, 1, 1, 6));

      s = skyAt(DateTime(2026, 1, 1, 6));
      expect(s.phase, SkyPhase.day);
      expect(s.nextChange, DateTime(2026, 1, 1, 18));

      s = skyAt(DateTime(2026, 1, 1, 18));
      expect(s.phase, SkyPhase.night);
      expect(s.nextChange, DateTime(2026, 1, 2, 6));

      s = skyAt(DateTime(2026, 12, 31, 23, 30));
      expect(s.phase, SkyPhase.night);
      expect(s.nextChange, DateTime(2027, 1, 1, 6));
    });

    test('a broken place falls back to the same hours', () {
      final s = skyAt(
        DateTime(2026, 1, 1, 12),
        place: (latitude: double.nan, longitude: 0),
      );
      expect(s.phase, SkyPhase.day);
      expect(s.nextChange, DateTime(2026, 1, 1, 18));
    });
  });

  group('SkyClock', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SkyClock.resetForTests();
    });
    tearDown(SkyClock.resetForTests);

    testWidgets('changes by itself at sunset while it is running', (
      tester,
    ) async {
      final sunset = SunTimes.on(
        localDay(DateTime.utc(2026, 6, 21, 9)),
        riyadh,
      ).sunset!;
      var now = sunset.subtract(const Duration(seconds: 10));
      final clock = SkyClock(
        now: () => now,
        locate: () async => riyadh,
        followApp: false,
      );
      await tester.pump(); // finds the place
      expect(clock.value, SkyPhase.day);

      now = now.add(const Duration(seconds: 12));
      await tester.pump(const Duration(seconds: 12));
      expect(clock.value, SkyPhase.night);
      clock.dispose();
    });

    testWidgets('uses 06:00–18:00 until the place is known, then the place', (
      tester,
    ) async {
      // 17:30 UTC: night in Riyadh. On the phone's own clock it may be
      // either, so set "now" to 17:30 local for the fallback hours instead.
      var now = DateTime(2026, 6, 21, 17, 30);
      final clock = SkyClock(
        now: () => now,
        locate: () async => null,
        followApp: false,
      );
      await tester.pump();
      expect(clock.value, SkyPhase.day); // before 18:00, no place

      now = DateTime.utc(2026, 6, 21, 17, 30).toLocal();
      await SkyClock.rememberPlace(riyadh);
      expect(clock.value, SkyPhase.night); // after sunset in Riyadh
      clock.dispose();
    });

    testWidgets('a saved place is used after a restart', (tester) async {
      SharedPreferences.setMockInitialValues({
        'sky_latitude': riyadh.latitude,
        'sky_longitude': riyadh.longitude,
      });
      final clock = SkyClock(
        now: () => DateTime.utc(2026, 6, 21, 1).toLocal(),
        locate: () async => null,
        followApp: false,
      );
      await tester.pump();
      expect(SkyClock.knownPlace.value, riyadh);
      expect(clock.value, SkyPhase.night);
      clock.dispose();
    });

    testWidgets('checks again when the app comes back', (tester) async {
      var now = DateTime(2026, 1, 1, 12);
      final clock = SkyClock(now: () => now, locate: () async => null);
      await tester.pump();
      expect(clock.value, SkyPhase.day);

      // Asleep through the evening (its timer may be held back meanwhile).
      void go(AppLifecycleState state) =>
          tester.binding.handleAppLifecycleStateChanged(state);
      go(AppLifecycleState.inactive);
      go(AppLifecycleState.hidden);
      go(AppLifecycleState.paused);
      now = DateTime(2026, 1, 1, 21);
      go(AppLifecycleState.hidden);
      go(AppLifecycleState.inactive);
      go(AppLifecycleState.resumed);
      expect(clock.value, SkyPhase.night);
      clock.dispose();
    });
  });

  group('Virtual Farm sky', () {
    setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
    tearDown(() {
      SkyClock.clockForTests = null;
      SkyClock.resetForTests();
      FarmStore.plantsLoaded.value = false;
    });

    Future<void> showFarm(WidgetTester tester, DateTime at) async {
      SkyClock.clockForTests = () =>
          SkyClock(now: () => at, locate: () async => null, followApp: false);
      FarmStore.plantsLoaded.value = false;
      await tester.pumpWidget(const MaterialApp(home: VirtualFarmScreen()));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Color? titleColor(WidgetTester tester) =>
        tester.widget<Text>(find.text('My Farm')).style?.color;

    testWidgets('by day: the day sky and the usual dark title', (
      tester,
    ) async {
      await showFarm(tester, DateTime(2026, 1, 1, 12));
      expect(
        tester.widget<FarmSky>(find.byType(FarmSky)).phase,
        SkyPhase.day,
      );
      expect(titleColor(tester)!.computeLuminance(), lessThan(0.2));
    });

    testWidgets('by night: the night sky and a light title', (tester) async {
      await showFarm(tester, DateTime(2026, 1, 1, 22));
      expect(
        tester.widget<FarmSky>(find.byType(FarmSky)).phase,
        SkyPhase.night,
      );
      expect(titleColor(tester)!.computeLuminance(), greaterThan(0.8));
    });

    testWidgets('the sky stays still: it is outside the zoomable farm', (
      tester,
    ) async {
      await showFarm(tester, DateTime(2026, 1, 1, 22));
      expect(
        find.descendant(
          of: find.byType(InteractiveViewer),
          matching: find.byType(FarmSky),
        ),
        findsNothing,
      );
      final sky = tester.getRect(find.byType(FarmSky));
      final before = sky;
      // Zoom in with the + button: the farm moves, the sky doesn't.
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.getRect(find.byType(FarmSky)), before);
      // It covers the whole screen.
      expect(sky, Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio);
    });
  });
}
