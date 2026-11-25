// My Plants cards: the plant's own name, then when its watering and
// fertilizing are next due (or missed), read from careState; and the white,
// outlined picture frame shared with Plant Details.
import 'package:ethmar/data/sample_plants.dart';
import 'package:ethmar/l10n/app_strings.dart';
import 'package:ethmar/models/care_task.dart';
import 'package:ethmar/models/crop_catalog.dart';
import 'package:ethmar/models/daily_task.dart' show TaskType;
import 'package:ethmar/models/farm_plant.dart';
import 'package:ethmar/models/task_log.dart';
import 'package:ethmar/screens/my_plants_screen.dart';
import 'package:ethmar/screens/plant_details_screen.dart';
import 'package:ethmar/services/farm_store.dart';
import 'package:ethmar/theme/app_colors.dart';
import 'package:ethmar/widgets/care_icon.dart';
import 'package:ethmar/widgets/care_schedule_editor.dart';
import 'package:ethmar/widgets/plant_care_due.dart';
import 'package:ethmar/widgets/plant_picture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const at8 = TimeOfDay(hour: 8, minute: 0);
final en = S(AppStrings.en);
final ar = S(AppStrings.ar);

DateTime nov(int day) => DateTime(2026, 11, day);
CareDone done(DateTime on, [DateTime? due]) =>
    CareDone(date: on, due: due ?? on);

FarmPlant plant({
  String id = 'p',
  String name = 'Mint',
  CareSchedule? water,
  CareSchedule? fertilize,
}) => FarmPlant(
  id: id,
  crop: cropCatalog.first,
  name: name,
  irrigation: water,
  fertilization: fertilize,
  plantedAt: nov(1),
  createdAt: nov(1),
  updatedAt: nov(1),
);

/// Nov 22, 09:00.
final now = DateTime(2026, 11, 22, 9);

String waterText(S s, FarmPlant p) =>
    careDueText(s, careState(p, TaskType.watering, now)!, now);

Widget app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('ar')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('the due text comes from careState', () {
    test('next: today, tomorrow, in 2 days, in 5 days, in 12 days', () {
      // Every 7 days, done on each of these days: next due 7 days later.
      for (final (doneOn, english, arabic) in [
        (nov(15), 'Next watering: Today', 'الري القادم: اليوم'),
        (nov(16), 'Next watering: Tomorrow', 'الري القادم: غدًا'),
        (nov(17), 'Next watering: In 2 days', 'الري القادم: بعد يومين'),
        (nov(20), 'Next watering: In 5 days', 'الري القادم: بعد 5 أيام'),
      ]) {
        final p = plant(water: CareSchedule(Repeat.everyWeek, at8,
            since: nov(1), lastDone: done(doneOn)));
        expect(waterText(en, p), english);
        expect(waterText(ar, p), arabic);
      }
      final twoWeeks = plant(water: CareSchedule(Repeat.every2Weeks, at8,
          since: nov(1), lastDone: done(nov(20))));
      expect(waterText(en, twoWeeks), 'Next watering: In 12 days');
      expect(waterText(ar, twoWeeks), 'الري القادم: بعد 12 يومًا');
    });

    test('a missed task shows as missed, never as done or later', () {
      // Every 7 days, done Nov 13: Nov 20 was missed.
      final p = plant(water: CareSchedule(Repeat.everyWeek, at8,
          since: nov(1), lastDone: done(nov(13))));
      final state = careState(p, TaskType.watering, now)!;
      expect(state.missed, nov(20));
      expect(waterText(en, p), 'Watering missed: 2 days ago');
      expect(waterText(ar, p), 'ري فائت: قبل يومين');
      for (final (day, english) in [
        (21, 'Watering missed: Yesterday'),
        (23, 'Watering missed: 3 days ago'),
      ]) {
        final at = DateTime(2026, 11, day, 9);
        expect(careDueText(en, careState(p, TaskType.watering, at)!, at),
            english);
      }
      // Its window is over on Nov 24: the next one, with nothing made up.
      final later = DateTime(2026, 11, 24, 9);
      expect(careDueText(en, careState(p, TaskType.watering, later)!, later),
          'Next watering: In 3 days');
    });

    test('a task ticked today (in the log) moves to its next date', () {
      final p = plant(water: CareSchedule(Repeat.every3Days, at8,
          since: nov(1), lastDone: done(nov(19))));
      expect(waterText(en, p), 'Next watering: Today');
      final logs = {
        '2026-11-22': const TaskLog(
            date: '2026-11-22', completed: ['p_irrigation']),
      };
      expect(
        careDueText(en,
            careState(p, TaskType.watering, now, logs: logs)!, now),
        'Next watering: In 3 days',
      );
    });

    test('fertilizing has its own words', () {
      final p = plant(fertilize: CareSchedule(Repeat.everyWeek, at8,
          since: nov(1), lastDone: done(nov(16))));
      final state = careState(p, TaskType.fertilizing, now)!;
      expect(careDueText(en, state, now), 'Next fertilizing: Tomorrow');
      expect(careDueText(ar, state, now), 'التسميد القادم: غدًا');
    });
  });

  group('the lines under the name', () {
    final water = CareSchedule(Repeat.everyWeek, at8,
        since: nov(1), lastDone: done(nov(16)));
    final fertilize = CareSchedule(Repeat.every2Weeks, at8,
        since: nov(1), lastDone: done(nov(20)));

    Future<void> show(WidgetTester tester, FarmPlant p, Locale locale) =>
        tester.pumpWidget(app(
          Scaffold(body: PlantCareDue(plant: p, logs: const {}, now: now)),
          locale: locale,
        ));

    for (final (locale, s) in [(const Locale('en'), en), (const Locale('ar'), ar)]) {
      testWidgets('$locale: both, watering only, fertilizing only, none',
          (tester) async {
        await show(tester, plant(water: water, fertilize: fertilize), locale);
        expect(find.byKey(const Key('careDue_watering')), findsOneWidget);
        expect(find.byKey(const Key('careDue_fertilizing')), findsOneWidget);
        // Watering first, then fertilizing.
        expect(
          tester.getTopLeft(find.byKey(const Key('careDue_watering'))).dy <
              tester.getTopLeft(find.byKey(const Key('careDue_fertilizing'))).dy,
          isTrue,
        );
        expect(find.byIcon(Icons.water_drop_rounded), findsOneWidget);
        // The fertilizer sack, as on Daily Tasks.
        expect(find.byType(FertilizerIcon), findsOneWidget);

        await show(tester, plant(water: water), locale);
        expect(find.byKey(const Key('careDue_watering')), findsOneWidget);
        expect(find.byKey(const Key('careDue_fertilizing')), findsNothing);

        await show(tester, plant(fertilize: fertilize), locale);
        expect(find.byKey(const Key('careDue_watering')), findsNothing);
        expect(find.byKey(const Key('careDue_fertilizing')), findsOneWidget);

        await show(tester, plant(), locale);
        expect(find.text(s.careNone), findsOneWidget);
        expect(find.byIcon(Icons.water_drop_rounded), findsNothing);
      });
    }

    testWidgets('a missed task is shown in the error colour', (tester) async {
      await show(
        tester,
        plant(water: CareSchedule(Repeat.everyWeek, at8,
            since: nov(1), lastDone: done(nov(13)))),
        const Locale('en'),
      );
      final text = tester.widget<Text>(find.text('Watering missed: 2 days ago'));
      expect(text.style!.color, AppColors.error);
    });
  });

  group('My Plants and Plant Details', () {
    // Built around the real today, as the screens read the clock.
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);

    setUp(() {
      // Today's log has a's fertilizing ticked, as its lastDone says.
      FarmStore.taskLogForTests = (date) => Stream.value(TaskLog(
            date: date,
            completed: [
              if (date == TaskLog.dateKey(day)) 'a_fertilization',
            ],
          ));
      FarmStore.growthForTests = (_) => Stream.value(const []);
    });

    tearDown(() {
      FarmStore.plants.value = const [];
      FarmStore.taskLogForTests = null;
      FarmStore.growthForTests = null;
    });
    final longName = 'My very favourite tomato plant on the balcony';
    final plants = [
      plant(
        id: 'a',
        name: longName,
        water: CareSchedule(Repeat.everyDay, at8, since: day),
        fertilize: CareSchedule(Repeat.everyWeek, at8,
            since: day, lastDone: done(day)),
      ),
      plant(id: 'b', name: 'نعناع البلكونة الجميل جدًا جدًا'),
    ];

    for (final locale in [const Locale('en'), const Locale('ar')]) {
      testWidgets('$locale: name only, care lines, no overflow on a small '
          'screen with large text', (tester) async {
        // A small phone (320 is covered in my_plants_layout_test.dart).
        tester.view.physicalSize = const Size(360, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        FarmStore.plants.value = plants;
        await tester.pumpWidget(app(const MyPlantsScreen(), locale: locale));
        await settle(tester);
        expect(tester.takeException(), isNull);

        final s = locale.languageCode == 'ar' ? ar : en;
        // The user's name only: no crop name or category line.
        expect(find.text(longName), findsOneWidget);
        // (It read "Tomato · Vegetable".)
        expect(find.textContaining(' · '), findsNothing);
        final crop = cropCatalog.first.name;
        expect(find.text(locale.languageCode == 'ar' ? crop.ar : crop.en),
            findsNothing);
        // Plant a: watering due today, fertilizing in 7 days.
        expect(find.text(s.careNextWatering(s.careInDays(0))), findsOneWidget);
        expect(find.text(s.careNextFertilizing(s.careInDays(7))),
            findsOneWidget);
        // Plant b: no schedules.
        expect(find.text(s.careNone), findsOneWidget);
        // The long name wraps instead of running under the picture.
        final name = tester.getRect(find.text(longName));
        final frame = tester.getRect(find.byKey(const Key('plantPictureFrame_a')));
        expect(name.overlaps(frame), isFalse);
      });
    }

    testWidgets('fertilizing has the Daily Tasks sack everywhere; watering '
        'keeps its drop', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      FarmStore.plants.value = plants;
      // My Plants: plant a has both schedules.
      await tester.pumpWidget(app(const MyPlantsScreen()));
      await settle(tester);
      expect(find.byType(FertilizerIcon), findsOneWidget);
      expect(find.byIcon(Icons.water_drop_rounded), findsOneWidget);
      expect(find.byIcon(Icons.spa_rounded), findsNothing);
      // Plant Details: its care schedule rows.
      await tester.pumpWidget(app(const PlantDetailsScreen(plantId: 'a')));
      await settle(tester);
      expect(find.byType(FertilizerIcon), findsOneWidget);
      expect(find.byIcon(Icons.spa_rounded), findsNothing);
      // The schedule editor (adding or editing a plant).
      await tester.pumpWidget(app(Scaffold(
        body: CareScheduleCard(
          irrigation: ScheduleDraft(Repeat.everyDay, at8),
          fertilization: ScheduleDraft(Repeat.everyWeek, at8),
          onChanged: () {},
        ),
      )));
      await settle(tester);
      expect(find.byType(FertilizerIcon), findsOneWidget);
      expect(find.byIcon(Icons.water_drop_rounded), findsOneWidget);
      expect(find.byIcon(Icons.spa_rounded), findsNothing);
    });

    testWidgets('the picture frame is the same white, outlined box on both '
        'screens', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      FarmStore.plants.value = samplePlants;
      await tester.pumpWidget(app(const MyPlantsScreen()));
      await settle(tester);
      final id = samplePlants.first.id!;
      final card = tester.widget<Container>(
          find.byKey(Key('plantPictureFrame_$id')));
      expect(card.decoration, plantPictureFrame(16));

      await tester.pumpWidget(app(PlantDetailsScreen(plantId: id)));
      await settle(tester);
      final details = tester.widget<Container>(
          find.byKey(const Key('plantPictureFrame')));
      expect(details.decoration, plantPictureFrame(28));

      // White, with the outline of Home's category buttons.
      final frame = plantPictureFrame(16);
      expect(frame.color, AppColors.surface);
      expect((frame.border! as Border).top.color,
          AppColors.earthBrown.withValues(alpha: 0.35));
    });
  });
}
