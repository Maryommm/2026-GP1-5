// Plant Details layout: delete in the picture card's corner, the crop card
// (catalog name and category, not the user's name), the journey's empty
// text, the smaller upload button, the pencil-only edit button, and the
// watering and fertilizing rows (each "Not set" on its own), in English and
// Arabic, also on a 320-wide phone with 130% text.
import 'package:ethmar/l10n/app_strings.dart';
import 'package:ethmar/models/crop_catalog.dart';
import 'package:ethmar/models/farm_plant.dart';
import 'package:ethmar/models/task_log.dart';
import 'package:ethmar/screens/plant_details_screen.dart';
import 'package:ethmar/services/farm_store.dart';
import 'package:ethmar/widgets/care_icon.dart';
import 'package:ethmar/widgets/centered_header.dart';
import 'package:ethmar/widgets/plant_picture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const at8 = TimeOfDay(hour: 8, minute: 0);
final _now = DateTime.now();
final _today = DateTime(_now.year, _now.month, _now.day);
final tomato = cropCatalog.first; // Tomato, a vegetable.

FarmPlant plant({bool water = true, bool feed = true}) => FarmPlant(
  id: 'p',
  crop: tomato,
  name: 'Balcony buddy',
  irrigation:
      water ? CareSchedule(Repeat.every2Days, at8, since: _today) : null,
  fertilization:
      feed ? CareSchedule(Repeat.everyWeek, at8, since: _today) : null,
  plantedAt: _today,
  createdAt: _today,
  updatedAt: _today,
);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> open(
  WidgetTester tester,
  FarmPlant p, {
  Locale locale = const Locale('en'),
  double width = 400,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  FarmStore.plants.value = [p];
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const PlantDetailsScreen(plantId: 'p'),
  ));
  await settle(tester);
}

/// [button] is centred on the middle of [card]'s rounded top corner on the
/// end side (top left in Arabic, top right in English): a 36 circle half
/// out of the card, half in, with 48 to tap.
void expectOnCorner(
  WidgetTester tester,
  Finder button,
  Rect card, {
  required double radius,
  required bool rtl,
}) {
  final inset = radius * (1 - 0.7071067811865476);
  final corner = Offset(
    rtl ? card.left + inset : card.right - inset,
    card.top + inset,
  );
  final r = tester.getRect(button);
  expect(r.size, const Size(48, 48));
  expect((r.center - corner).distance, lessThan(0.5), reason: '$r $corner');
  // The visible circle crosses the card's outline.
  final circle = visibleCircle(tester, button);
  expect(circle.size, const Size(36, 36));
  expect(circle.top, lessThan(card.top));
  expect(circle.bottom, greaterThan(card.top));
}

/// The 36 circle a corner button draws (inside its 48 tap area).
Rect visibleCircle(WidgetTester tester, Finder button) => [
  for (final e
      in find.descendant(of: button, matching: find.byType(Material)).evaluate())
    tester.getRect(find.byWidget(e.widget)),
].firstWhere((r) => r.width == 36);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    FarmStore.journeyForTests = (_) => Stream.value(const []);
    FarmStore.taskLogForTests = (date) => Stream.value(TaskLog(date: date));
  });

  tearDown(() {
    FarmStore.plants.value = const [];
    FarmStore.journeyForTests = null;
    FarmStore.taskLogForTests = null;
  });

  for (final (locale, s, rtl) in [
    (const Locale('en'), S(AppStrings.en), false),
    (const Locale('ar'), S(AppStrings.ar), true),
  ]) {
    testWidgets('$locale: delete in the picture card, crop card, journey text, '
        'upload and edit buttons', (tester) async {
      await open(tester, plant(), locale: locale);
      expect(tester.takeException(), isNull);

      // The user's name is the title, and the delete button isn't in the header.
      final header = find.byType(EthmarCenteredHeader);
      expect(find.descendant(of: header, matching: find.text('Balcony buddy')),
          findsOneWidget);
      // Only the user's name: no crop name under it, and centred.
      expect(find.descendant(of: header, matching: find.byType(Text)),
          findsOneWidget);
      expect(tester.getCenter(find.text('Balcony buddy')).dx,
          closeTo(tester.getCenter(header).dx, 1));
      final delete = find.byKey(const ValueKey('delete-plant'));
      expect(find.descendant(of: header, matching: delete), findsNothing);

      // Delete: centred on the picture card's rounded top corner, end side
      // (on the border: part out, part in), clear of the picture.
      final frame = tester.getRect(find.byKey(const Key('plantPictureFrame')));
      expectOnCorner(tester, delete, frame, radius: 28, rtl: rtl);
      expect(tester.getRect(delete)
              .overlaps(tester.getRect(find.byType(PlantPicture))),
          isFalse);

      // The crop card: "Tomato - Vegetables" on one bold line, from the
      // catalog, not the user's name.
      final cropCard = find.byKey(const Key('plantCropCard'));
      final cropName = rtl ? tomato.name.ar : tomato.name.en;
      final cropLine = find.descendant(
          of: cropCard, matching: find.text('$cropName - ${s.cropCatVegetable}'));
      expect(cropLine, findsOneWidget);
      expect(tester.widget<Text>(cropLine).style!.fontSize, 15);
      expect(tester.widget<Text>(cropLine).style!.fontWeight, FontWeight.w700);
      expect(find.descendant(of: cropCard,
          matching: find.text('Balcony buddy')), findsNothing);
      // The days since planting, at the same slightly smaller size.
      expect(tester.widget<Text>(find.text(s.plantAge(0))).style!.fontSize, 15);
      // The watering card is gone (its frequency now in the schedule).
      expect(find.text(s.plantCropLabel), findsOneWidget);

      // The journey's empty text.
      expect(find.text(s.journeyEmpty), findsOneWidget);

      // Upload: a 36-high pill in a 48-high tap band.
      final upload = find.byKey(const Key('upload-picture'));
      expect(tester.getSize(upload).height, greaterThanOrEqualTo(48));
      final pill = find.descendant(of: upload, matching: find.byType(Material));
      expect(tester.getSize(pill).height, 36);
      expect(find.text(s.uploadPicture), findsOneWidget);

      // Edit: a pencil only, centred on the schedule card's corner too.
      final edit = find.byKey(const Key('edit-schedule'));
      final pencil =
          find.descendant(of: edit, matching: find.byType(IconButton));
      expect(tester.widget<IconButton>(pencil).tooltip, s.edit);
      expect(find.descendant(of: edit, matching: find.byIcon(Icons.edit_rounded)),
          findsOneWidget);
      expect(find.descendant(of: edit, matching: find.byType(Text)),
          findsNothing);
      final panel = tester.getRect(find
          .ancestor(of: find.text(s.careSchedule), matching: find.byType(Container))
          .first);
      expectOnCorner(tester, edit, panel, radius: 24, rtl: rtl);
    });

    testWidgets('$locale: watering and fertilizing rows, each "Not set" on '
        'its own', (tester) async {
      Finder row(String type) => find.byKey(Key('schedule_$type'));
      Finder inRow(String type, String text) =>
          find.descendant(of: row(type), matching: find.text(text));

      // Both set: frequency and when it's next due.
      await open(tester, plant(), locale: locale);
      expect(inRow('watering', Repeat.every2Days.label(s)), findsOneWidget);
      expect(inRow('fertilizing', Repeat.everyWeek.label(s)), findsOneWidget);
      expect(
        find.descendant(of: row('watering'),
            matching: find.textContaining(s.scheduleNext('').trim())),
        findsOneWidget,
      );
      // The drop at 18, the sack a little smaller (16) to look the same.
      final drop = find.descendant(
          of: row('watering'), matching: find.byIcon(Icons.water_drop_rounded));
      final sack = find.descendant(
          of: row('fertilizing'), matching: find.byType(FertilizerIcon));
      expect(tester.getSize(drop), const Size(18, 18));
      expect(tester.getSize(sack), const Size(16, 16));
      expect(tester.getCenter(drop).dx, tester.getCenter(sack).dx);

      // Watering only.
      await open(tester, plant(feed: false), locale: locale);
      expect(inRow('fertilizing', s.scheduleNotSet), findsOneWidget);
      expect(inRow('watering', s.scheduleNotSet), findsNothing);

      // Fertilizing only.
      await open(tester, plant(water: false), locale: locale);
      expect(inRow('watering', s.scheduleNotSet), findsOneWidget);
      expect(inRow('fertilizing', s.scheduleNotSet), findsNothing);

      // Neither: both rows still there, both "Not set".
      await open(tester, plant(water: false, feed: false), locale: locale);
      expect(row('watering'), findsOneWidget);
      expect(row('fertilizing'), findsOneWidget);
      expect(find.text(s.scheduleNotSet), findsNWidgets(2));
    });

    testWidgets('$locale: fits on 320 wide with 130% text', (tester) async {
      await open(tester, plant(), locale: locale, width: 320, textScale: 1.3);
      expect(tester.takeException(), isNull);
      for (final key in ['plantCropCard', 'upload-picture',
          'schedule_watering', 'schedule_fertilizing']) {
        final r = tester.getRect(find.byKey(Key(key)));
        expect(r.left, greaterThanOrEqualTo(0), reason: key);
        expect(r.right, lessThanOrEqualTo(320), reason: key);
      }
      // The corner buttons' circles are on screen (their invisible tap
      // areas may reach the very edge).
      for (final key in [const Key('edit-schedule'), const ValueKey('delete-plant')]) {
        final r = visibleCircle(tester, find.byKey(key));
        expect(r.left, greaterThanOrEqualTo(0), reason: '$key');
        expect(r.right, lessThanOrEqualTo(320), reason: '$key');
      }
    });
  }

  testWidgets('the band around the upload pill opens the picture choice too',
      (tester) async {
    await open(tester, plant());
    final upload = find.byKey(const Key('upload-picture'));
    await tester.ensureVisible(upload);
    await settle(tester);
    final pill = tester.getRect(
        find.descendant(of: upload, matching: find.byType(Material)));
    // Just above the pill, still inside the 48-high band.
    await tester.tapAt(Offset(pill.center.dx, pill.top - 4));
    await settle(tester);
    expect(find.byType(BottomSheet), findsOneWidget);
  });
}
