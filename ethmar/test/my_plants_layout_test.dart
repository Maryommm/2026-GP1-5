// My Plants layout: card heights with 0, 1 or 2 care schedules, long names,
// and the toolbar, select mode and filter sheet on a 320-wide phone with
// 130% text, in English and Arabic, without overflow.
import 'package:ethmar/models/crop_catalog.dart';
import 'package:ethmar/models/crop_recommendation.dart' show CropCategory;
import 'package:ethmar/models/farm_plant.dart';
import 'package:ethmar/models/task_log.dart';
import 'package:ethmar/screens/my_plants_screen.dart';
import 'package:ethmar/services/farm_store.dart';
import 'package:ethmar/theme/app_colors.dart';
import 'package:ethmar/widgets/character.dart';
import 'package:ethmar/widgets/ethmar_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const at8 = TimeOfDay(hour: 8, minute: 0);

final _now = DateTime.now();
final _today = DateTime(_now.year, _now.month, _now.day);

FarmPlant plant(String id, String name, {bool water = false, bool feed = false}) =>
    FarmPlant(
      id: id,
      crop: cropCatalog.first,
      name: name,
      irrigation:
          water ? CareSchedule(Repeat.everyDay, at8, since: _today) : null,
      fertilization:
          feed ? CareSchedule(Repeat.everyWeek, at8, since: _today) : null,
      plantedAt: _today,
      // Newest first on the screen: zero, one, two, then the long names.
      createdAt: _today.subtract(Duration(minutes: int.parse(id))),
      updatedAt: _today,
    );

final plants = [
  plant('1', 'Basil'),
  plant('2', 'Mint', water: true),
  plant('3', 'Tomato', water: true, feed: true),
  plant('4', 'My very favourite cherry tomato on the balcony',
      water: true, feed: true),
  plant('5', 'نعناع البلكونة المفضل عندي في الصيف', water: true),
];

Future<void> open(
  WidgetTester tester, {
  required Locale locale,
  double width = 400,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  FarmStore.plants.value = plants;
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const MyPlantsScreen(),
  ));
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The card around plant [id]'s picture.
Finder card(String id) => find
    .ancestor(
      of: find.byKey(Key('plantPictureFrame_$id')),
      matching: find.byType(InkWell),
    )
    .first;

void expectOnScreen(WidgetTester tester, Finder f, double width) {
  final r = tester.getRect(f);
  expect(r.left, greaterThanOrEqualTo(0), reason: '$f');
  expect(r.right, lessThanOrEqualTo(width), reason: '$f');
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    FarmStore.taskLogForTests = (date) => Stream.value(TaskLog(date: date));
  });

  tearDown(() {
    FarmStore.plants.value = const [];
    FarmStore.taskLogForTests = null;
  });

  group('plant count and select mode', () {
    final fruit =
        cropCatalog.firstWhere((c) => c.category == CropCategory.fruit);
    final mixed = [
      ...plants,
      FarmPlant(
        id: '6',
        crop: fruit,
        name: 'Lemon',
        plantedAt: _today,
        createdAt: _today.subtract(const Duration(minutes: 6)),
        updatedAt: _today,
      ),
    ];

    for (final (locale, count, selected, cancel, hint) in [
      (const Locale('en'), 'Plants: 6', '1 selected', 'Cancel',
          'Tap plants to select them'),
      (const Locale('ar'), 'عدد النباتات: 6', 'المحدد: 1', 'إلغاء',
          'اضغط على النباتات لتحديدها'),
    ]) {
      testWidgets('$locale: controls, then the count, then the cards; in '
          'select mode only the ticked count', (tester) async {
        await open(tester, locale: locale);
        FarmStore.plants.value = mixed;
        await settle(tester);
        final countText = find.byKey(const Key('plantCount'));
        expect(tester.widget<Text>(countText).data, count);
        // The app's standard black.
        expect(tester.widget<Text>(countText).style!.color,
            AppColors.textPrimary);
        final controls = tester.getRect(find.byKey(const Key('selectPlants')));
        final countRect = tester.getRect(countText);
        final firstCard = tester.getRect(card('1'));
        expect(controls.bottom, lessThanOrEqualTo(countRect.top));
        expect(countRect.bottom, lessThanOrEqualTo(firstCard.top));

        // Select mode: the plant count goes, with its space.
        await tester.tap(find.byKey(const Key('selectPlants')));
        await settle(tester);
        expect(countText, findsNothing);
        await tester.tap(card('1'));
        await settle(tester);
        expect(find.text(selected), findsOneWidget);
        expect(countText, findsNothing);
        // The hint takes the count's place: controls, hint, cards, with
        // no other gap.
        final hintText = find.byKey(const Key('selectPlantsHint'));
        expect(tester.widget<Text>(hintText).data, hint);
        final bar = tester.getRect(find.byKey(const Key('cancelSelecting')));
        final hintRect = tester.getRect(hintText);
        final cardTop = tester.getRect(card('1')).top;
        expect(bar.bottom, lessThanOrEqualTo(hintRect.top));
        expect(cardTop - hintRect.bottom, lessThanOrEqualTo(14));

        // Ticked: soft red with a red border; the others only a slightly
        // stronger outline, not greyed out.
        ShapeBorder shapeOf(String id) => tester
            .widget<Material>(find
                .ancestor(of: card(id), matching: find.byType(Material))
                .first)
            .shape!;
        Material materialOf(String id) => tester.widget<Material>(find
            .ancestor(of: card(id), matching: find.byType(Material))
            .first);
        expect(materialOf('1').color, AppColors.errorTint);
        expect((shapeOf('1') as RoundedRectangleBorder).side.color,
            AppColors.error);
        expect(materialOf('1').elevation, greaterThan(0));
        expect(materialOf('2').color, AppColors.surface);
        expect((shapeOf('2') as RoundedRectangleBorder).side.color,
            AppColors.earthBrown.withValues(alpha: 0.45));
        expect(materialOf('2').elevation, 0);
        // Tapping a ticked card again unticks it.
        await tester.tap(card('1'));
        await settle(tester);
        expect(materialOf('1').color, AppColors.surface);
        expect(find.text(selected), findsNothing);
        await tester.tap(card('1'));
        await settle(tester);
        // No green band behind the select-mode controls.
        expect(
          find.byWidgetPredicate((w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color == AppColors.forestTint),
          findsNothing,
        );
        // "X Cancel" leaves select mode and deletes nothing.
        final cancelButton = find.byKey(const Key('cancelSelecting'));
        expect(
          find.descendant(of: cancelButton, matching: find.text(cancel)),
          findsOneWidget,
        );
        expect(
          find.descendant(
              of: cancelButton, matching: find.byIcon(Icons.close_rounded)),
          findsOneWidget,
        );
        await tester.tap(cancelButton);
        await settle(tester);
        expect(find.byType(Checkbox), findsNothing);
        expect(FarmStore.plants.value, hasLength(6));
        // The plant count is back.
        expect(tester.widget<Text>(countText).data, count);
      });
    }

    testWidgets('the count follows the filter and deletions', (tester) async {
      await open(tester, locale: const Locale('en'));
      FarmStore.plants.value = mixed;
      await settle(tester);
      String count() =>
          tester.widget<Text>(find.byKey(const Key('plantCount'))).data!;
      expect(count(), 'Plants: 6');

      await tester.tap(find.byKey(const Key('plantsFilter')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('filterOption_fruit')));
      await settle(tester);
      expect(count(), 'Plants: 1');

      // A plant deleted (here, gone from the farm): the count follows.
      FarmStore.plants.value = [for (final p in mixed) if (p.id != '6') p];
      await settle(tester);
      expect(count(), 'Plants: 0');

      // Back to all plants.
      await tester.tap(find.byKey(const Key('plantsFilter')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('filterOption_all')));
      await settle(tester);
      expect(count(), 'Plants: 5');
    });
  });

  group('a category with no plants', () {
    // Every test plant is a tomato (vegetable); fruit has none.
    Future<void> chooseFruit(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('plantsFilter')));
      await settle(tester);
      final option = find.byKey(const Key('filterOption_fruit'));
      await tester.ensureVisible(option);
      await tester.tap(option);
      await settle(tester);
    }

    for (final (locale, title, body) in [
      (
        const Locale('en'),
        'No Plants in This Category',
        'You can select another category to view your plants.',
      ),
      (
        const Locale('ar'),
        'لا توجد نباتات من هذه الفئة',
        'يمكنك اختيار فئة أخرى لعرضها',
      ),
    ]) {
      testWidgets('$locale: surprised Thamoor, title and text, centred, no '
          'Clear filter button', (tester) async {
        await open(tester, locale: locale);
        await chooseFruit(tester);
        expect(tester.takeException(), isNull);

        expect(find.text(title), findsOneWidget);
        expect(find.text(body), findsOneWidget);
        final thamoor = find.byType(EthmarCharacter);
        expect(tester.widget<EthmarCharacter>(thamoor).name,
            'ethmar_buddy_surprised');
        // No big button in the message; the chip and Filter stay.
        final message = find.byKey(const Key('filterNoMatch'));
        expect(find.descendant(of: message, matching: find.byType(EthmarButton)),
            findsNothing);
        expect(find.byKey(const Key('clearPlantsFilter')), findsOneWidget);
        expect(find.byKey(const Key('plantsFilter')), findsOneWidget);

        // Centred across; up and down, a little above the middle of the
        // space under the count (about a third of the free space above,
        // two thirds below, with the 32 padding), and still inside it.
        final area = tester.getRect(message);
        final count = tester.getRect(find.byKey(const Key('plantCount')));
        expect(area.top, greaterThanOrEqualTo(count.bottom));
        final group = tester.getRect(thamoor).expandToInclude(
            tester.getRect(find.text(body)));
        expect(group.center.dx, closeTo(area.center.dx, 1));
        expect(group.center.dy, lessThan(area.center.dy));
        final above = group.top - area.top;
        final below = area.bottom - group.bottom;
        expect(above / (above + below), closeTo(0.35, 0.03));
        expect(above, greaterThan(0));

        // The chip's X brings every plant back.
        await tester.tap(find.byKey(const Key('clearPlantsFilter')));
        await settle(tester);
        expect(find.text(title), findsNothing);
        expect(find.text(plants.first.name), findsOneWidget);
      });

      testWidgets('$locale: fits on 320 wide with 130% text', (tester) async {
        await open(tester, locale: locale, width: 320, textScale: 1.3);
        await chooseFruit(tester);
        expect(tester.takeException(), isNull);
        expectOnScreen(tester, find.text(body), 320);
      });
    }

    testWidgets('the no-plants-at-all message is unchanged', (tester) async {
      await open(tester, locale: const Locale('en'));
      FarmStore.plants.value = const [];
      await settle(tester);
      expect(tester.widget<EthmarCharacter>(find.byType(EthmarCharacter)).name,
          'ethmar_buddy_seedling');
      expect(find.byType(EthmarButton), findsOneWidget);
      expect(find.text('No Plants in This Category'), findsNothing);
    });
  });

  testWidgets('cards: 0 and 1 schedules as compact as the picture allows, '
      '2 a little taller, never far apart', (tester) async {
    // Wide enough that the care lines stay on one line each with the test
    // font, whose letters are all as wide as they are tall.
    await open(tester, locale: const Locale('en'), width: 700);
    final zero = tester.getSize(card('1')).height;
    final one = tester.getSize(card('2')).height;
    final two = tester.getSize(card('3')).height;
    // 68 picture + 10 above + 10 below.
    expect(zero, 88);
    expect(one, 88);
    expect(two, greaterThanOrEqualTo(one));
    expect(two - zero, lessThanOrEqualTo(24));
    // Every picture frame is 68 x 68.
    expect(tester.getSize(find.byKey(const Key('plantPictureFrame_3'))),
        const Size(68, 68));
  });

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets('$locale, 320 wide, 130% text: toolbar, cards and long names '
        'fit', (tester) async {
      await open(tester, locale: locale, width: 320, textScale: 1.3);
      expect(tester.takeException(), isNull);
      expectOnScreen(tester, find.byKey(const Key('plantsFilter')), 320);
      expectOnScreen(tester, find.byKey(const Key('selectPlants')), 320);
      for (final id in ['4', '5']) {
        final name = find.text(plants[int.parse(id) - 1].name);
        expect(
          tester.getRect(name)
              .overlaps(tester.getRect(find.byKey(Key('plantPictureFrame_$id')))),
          isFalse,
        );
        expectOnScreen(tester, name, 320);
      }
    });

    testWidgets('$locale, 320 wide, 130% text: select mode fits', (tester) async {
      await open(tester, locale: locale, width: 320, textScale: 1.3);
      await tester.tap(find.byKey(const Key('selectPlants')));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expectOnScreen(tester, find.byKey(const Key('toggleAllPlants')), 320);
      expectOnScreen(tester, find.byKey(const Key('cancelSelecting')), 320);
      expect(find.byKey(const Key('plantCount')), findsNothing);
      expect(find.byType(Checkbox), findsNWidgets(plants.length));
      // Tick everything: "Deselect all" is the longest label.
      await tester.tap(find.byKey(const Key('toggleAllPlants')));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expectOnScreen(tester, find.byKey(const Key('toggleAllPlants')), 320);
      // Names still clear of their pictures with the boxes in.
      final name = find.text(plants[3].name);
      expect(
        tester.getRect(name)
            .overlaps(tester.getRect(find.byKey(const Key('plantPictureFrame_4')))),
        isFalse,
      );
    });

    testWidgets('$locale, 320 wide, 130% text: the filter sheet', (tester) async {
      await open(tester, locale: locale, width: 320, textScale: 1.3);
      await tester.tap(find.byKey(const Key('plantsFilter')));
      await settle(tester);
      expect(tester.takeException(), isNull);
      // Every category is still offered, empty ones too.
      expect(find.byKey(const Key('filterOption_all')), findsOneWidget);
      // Counts line up, and a zero is lighter.
      final all = find.byKey(const Key('filterCount_all'));
      final vegetable = find.byKey(const Key('filterCount_vegetable'));
      expect(tester.getRect(all).right, tester.getRect(vegetable).right);
      expect(tester.widget<Text>(all).style!.color, AppColors.textSecondary);
      final empty = find.byKey(const Key('filterCount_herb'));
      if (tester.widget<Text>(empty).data == '0') {
        expect(tester.widget<Text>(empty).style!.color, AppColors.textHint);
      }
    });
  }
}
