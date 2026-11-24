import 'dart:math' as math;

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

  // -------------------------------------------------------------------------
  // A phone whose time zone is far from where it is (an emulator set to
  // Riyadh time but placed in California, or a traveller). Every test fixes
  // the phone's time zone with utcOffset, so none depends on this computer's.
  // -------------------------------------------------------------------------

  group('time zone far from the place', () {
    const riyadhTime = Duration(hours: 3);
    const SkyPlace mountainView = (latitude: 37.4234, longitude: -122.0840);

    // Mountain View, 24 Nov 2026: sunrise about 06:58 PST (14:58 UTC, 17:58
    // in Riyadh), sunset about 16:53 PST (00:53 UTC on the 25th, 03:53 in
    // Riyadh).
    final sunrise = DateTime.utc(2026, 11, 24, 14, 58);
    final sunset = DateTime.utc(2026, 11, 25, 0, 53);

    SkyState at(DateTime utc) =>
        skyAt(utc.toLocal(), place: mountainView, utcOffset: riyadhTime);

    test('before California sunrise (17:00 Riyadh): night until sunrise', () {
      final s = at(DateTime.utc(2026, 11, 24, 14));
      expect(s.phase, SkyPhase.night);
      expectNear(s.nextChange, sunrise, minutes: 5);
    });

    test('after it (18:30 Riyadh): day until California sunset', () {
      final s = at(DateTime.utc(2026, 11, 24, 15, 30));
      expect(s.phase, SkyPhase.day);
      expectNear(s.nextChange, sunset, minutes: 5);
    });

    test('daylight carries on past midnight on the phone', () {
      // 23:59 and 00:01 and 02:30 Riyadh time: the sun is still up there.
      for (final utc in [
        DateTime.utc(2026, 11, 24, 20, 59),
        DateTime.utc(2026, 11, 24, 21, 1),
        DateTime.utc(2026, 11, 24, 23, 30),
      ]) {
        final s = at(utc);
        expect(s.phase, SkyPhase.day, reason: '$utc');
        expectNear(s.nextChange, sunset, minutes: 5);
      }
    });

    test('night after California sunset (04:30 Riyadh), until sunrise', () {
      final s = at(DateTime.utc(2026, 11, 25, 1, 30));
      expect(s.phase, SkyPhase.night);
      expectNear(s.nextChange, DateTime.utc(2026, 11, 25, 14, 59), minutes: 5);
    });

    test('Riyadh on Riyadh time is unchanged', () {
      final noon = skyAt(
        DateTime.utc(2026, 11, 24, 9).toLocal(),
        place: riyadh,
        utcOffset: riyadhTime,
      );
      expect(noon.phase, SkyPhase.day);
      final night = skyAt(
        DateTime.utc(2026, 11, 24, 20).toLocal(), // 23:00 in Riyadh
        place: riyadh,
        utcOffset: riyadhTime,
      );
      expect(night.phase, SkyPhase.night);
    });

    test('polar day and night still hold all day', () {
      for (final offset in const [Duration.zero, riyadhTime, Duration(hours: -8)]) {
        expect(
          skyAt(DateTime.utc(2026, 12, 21, 11).toLocal(),
                  place: tromso, utcOffset: offset)
              .phase,
          SkyPhase.night,
        );
        expect(
          skyAt(DateTime.utc(2026, 6, 21, 23).toLocal(),
                  place: tromso, utcOffset: offset)
              .phase,
          SkyPhase.day,
        );
      }
    });
  });

  group('matches where the sun really is', () {
    // Places all round the world, each with phone time zones near and far
    // from it, over two days every 10 minutes (crossing midnight on the
    // phone and in UTC). Day must be exactly when the sun's edge is above
    // the horizon, by a separate formula (NOAA solar position), except
    // within a few minutes of sunrise and sunset.
    const places = <String, SkyPlace>{
      'Mountain View': (latitude: 37.42, longitude: -122.08),
      'New York': (latitude: 40.71, longitude: -74.01),
      'London': (latitude: 51.51, longitude: -0.13),
      'Riyadh': (latitude: 24.71, longitude: 46.68),
      'Tokyo': (latitude: 35.68, longitude: 139.69),
      'Sydney': (latitude: -33.87, longitude: 151.21),
      'Fiji': (latitude: -17.71, longitude: 178.07),
    };
    const offsets = [-12, -8, -5, 0, 3, 9, 14];

    for (final MapEntry(key: name, value: place) in places.entries) {
      test(name, () {
        for (final hours in offsets) {
          final offset = Duration(hours: hours);
          for (final start in [
            DateTime.utc(2026, 3, 20),
            DateTime.utc(2026, 6, 21),
            DateTime.utc(2026, 11, 24),
            DateTime.utc(2026, 12, 31, 12),
          ]) {
            for (var m = 0; m < 48 * 60; m += 10) {
              final t = start.add(Duration(minutes: m));
              final elevation = _sunElevation(t, place);
              // Too close to the horizon to tell the two formulas apart.
              if ((elevation + 0.833).abs() < 1.2) continue;
              final s = skyAt(t.toLocal(), place: place, utcOffset: offset);
              expect(
                s.phase,
                elevation > -0.833 ? SkyPhase.day : SkyPhase.night,
                reason: '$name, UTC$hours, at $t (sun at '
                    '${elevation.toStringAsFixed(1)}°)',
              );
              // The next change is ahead, and within a day.
              expect(s.nextChange.isAfter(t), isTrue, reason: '$t');
              expect(
                s.nextChange.difference(t),
                lessThanOrEqualTo(const Duration(hours: 25)),
                reason: '$name, UTC$hours, at $t',
              );
            }
          }
        }
      });
    }
  });

  group('first look at the farm', () {
    setUp(() {
      GoogleFonts.config.allowRuntimeFetching = false;
      SkyClock.resetForTests();
    });
    tearDown(() {
      SkyClock.clockForTests = null;
      SkyClock.resetForTests();
      FarmStore.plantsLoaded.value = false;
    });

    // 16:30 in Riyadh: day by the 06:00–18:00 guess, but night in
    // California, which is the saved place.
    final now = DateTime.utc(2026, 11, 24, 13, 30).toLocal();
    const SkyPlace mountainView = (latitude: 37.4234, longitude: -122.0840);

    FadeTransition nightLayer(WidgetTester tester) => tester.widget(
      find.descendant(
        of: find.byType(FarmSky),
        matching: find.byType(FadeTransition),
      ),
    );

    testWidgets('no day sky first: the saved place decides the first scene', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'sky_latitude': mountainView.latitude,
        'sky_longitude': mountainView.longitude,
      });
      SkyClock.clockForTests = () => SkyClock(
        now: () => now,
        locate: () async => null,
        followApp: false,
        utcOffset: const Duration(hours: 3),
      );
      expect(skyAt(now, utcOffset: const Duration(hours: 3)).phase,
          SkyPhase.day); // what the guess alone would show
      FarmStore.plantsLoaded.value = false;

      await tester.pumpWidget(const MaterialApp(home: VirtualFarmScreen()));
      // Frame by frame: never a day sky on screen.
      var shown = false;
      for (var i = 0; i < 30; i++) {
        final sky = tester.widget<FarmSky>(find.byType(FarmSky));
        if (sky.ready) {
          expect(sky.phase, SkyPhase.night, reason: 'frame $i');
          if (!shown) {
            // Already fully night on its first frame: no fade from day.
            expect(nightLayer(tester).opacity.value, 1, reason: 'frame $i');
            shown = true;
          }
        } else {
          // Not ready: no scene drawn at all (just the page's cream).
          expect(
            find.descendant(
              of: find.byType(FarmSky),
              matching: find.byType(FadeTransition),
            ),
            findsNothing,
          );
        }
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(shown, isTrue);
    });

    testWidgets('no saved place: the 06:00–18:00 guess, shown at once', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      SkyClock.clockForTests = () => SkyClock(
        now: () => now,
        locate: () async => null,
        followApp: false,
        utcOffset: const Duration(hours: 3),
      );
      FarmStore.plantsLoaded.value = false;
      await tester.pumpWidget(const MaterialApp(home: VirtualFarmScreen()));
      await tester.pump(const Duration(milliseconds: 50));
      final sky = tester.widget<FarmSky>(find.byType(FarmSky));
      expect(sky.ready, isTrue);
      expect(sky.phase, SkyPhase.day);
      expect(nightLayer(tester).opacity.value, 0);
      await tester.pump(const Duration(seconds: 1)); // let the entrance finish
    });

    testWidgets('a broken saved place is ignored', (tester) async {
      SharedPreferences.setMockInitialValues({
        'sky_latitude': 500.0,
        'sky_longitude': -122.0,
      });
      SkyClock.clockForTests = () => SkyClock(
        now: () => now,
        locate: () async => null,
        followApp: false,
        utcOffset: const Duration(hours: 3),
      );
      FarmStore.plantsLoaded.value = false;
      await tester.pumpWidget(const MaterialApp(home: VirtualFarmScreen()));
      await tester.pump(const Duration(milliseconds: 50));
      expect(SkyClock.knownPlace.value, isNull);
      expect(tester.widget<FarmSky>(find.byType(FarmSky)).phase, SkyPhase.day);
      await tester.pump(const Duration(seconds: 1)); // let the entrance finish
    });

    testWidgets('a real sunrise later still fades smoothly', (tester) async {
      SharedPreferences.setMockInitialValues({
        'sky_latitude': mountainView.latitude,
        'sky_longitude': mountainView.longitude,
      });
      // Ten seconds before California sunrise.
      final sunrise = SunTimes.on(
        DateTime(2026, 11, 24),
        mountainView,
        utcOffset: const Duration(hours: 3),
      ).sunrise!;
      var time = sunrise.subtract(const Duration(seconds: 10));
      SkyClock.clockForTests = () => SkyClock(
        now: () => time,
        locate: () async => null,
        followApp: false,
        utcOffset: const Duration(hours: 3),
      );
      FarmStore.plantsLoaded.value = false;
      await tester.pumpWidget(const MaterialApp(home: VirtualFarmScreen()));
      await tester.pump(const Duration(milliseconds: 50));
      expect(nightLayer(tester).opacity.value, 1);

      time = time.add(const Duration(seconds: 12));
      await tester.pump(const Duration(seconds: 12)); // the sunrise timer
      expect(tester.widget<FarmSky>(find.byType(FarmSky)).phase, SkyPhase.day);
      await tester.pump(FarmSky.fade ~/ 2);
      final halfway = nightLayer(tester).opacity.value;
      expect(halfway, inExclusiveRange(0.05, 0.95));
      await tester.pump(FarmSky.fade);
      expect(nightLayer(tester).opacity.value, 0);
    });
  });
}

/// How high the sun stands at [utc] seen from [place], in degrees (NOAA's
/// general solar position formulas; separate from the app's sunrise
/// equation, to check it).
double _sunElevation(DateTime utc, SkyPlace place) {
  final start = DateTime.utc(utc.year);
  final dayOfYear = utc.difference(start).inMinutes / 1440;
  // NOAA's fractional year: (day of year − 1) + (hour − 12) / 24.
  final g = 2 * math.pi / 365 * (dayOfYear - 0.5);
  final eqTime = 229.18 *
      (0.000075 +
          0.001868 * math.cos(g) -
          0.032077 * math.sin(g) -
          0.014615 * math.cos(2 * g) -
          0.040849 * math.sin(2 * g));
  final decl = 0.006918 -
      0.399912 * math.cos(g) +
      0.070257 * math.sin(g) -
      0.006758 * math.cos(2 * g) +
      0.000907 * math.sin(2 * g) -
      0.002697 * math.cos(3 * g) +
      0.00148 * math.sin(3 * g);
  final minutes = utc.hour * 60 + utc.minute + utc.second / 60;
  final trueSolar = minutes + eqTime + 4 * place.longitude;
  final hourAngle = (trueSolar / 4 - 180) * math.pi / 180;
  final lat = place.latitude * math.pi / 180;
  final cosZenith = math.sin(lat) * math.sin(decl) +
      math.cos(lat) * math.cos(decl) * math.cos(hourAngle);
  return 90 - math.acos(cosZenith.clamp(-1.0, 1.0)) * 180 / math.pi;
}
