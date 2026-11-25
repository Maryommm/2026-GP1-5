import 'package:ethmar/data/sample_plants.dart';
import 'package:ethmar/models/crop_recommendation.dart' show CropCategory;
import 'package:ethmar/screens/my_plants_screen.dart';
import 'package:ethmar/services/farm_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  tearDown(() => FarmStore.plants.value = const []);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openScreen(WidgetTester tester) async {
    // Tall enough that every plant card is built, not just the first few.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    FarmStore.plants.value = samplePlants;
    await tester.pumpWidget(const MaterialApp(home: MyPlantsScreen()));
    await settle(tester);
  }

  Future<void> choose(WidgetTester tester, CropCategory? category) async {
    await tester.tap(find.byKey(const Key('plantsFilter')));
    await settle(tester);
    final option = find.byKey(Key('filterOption_${category?.name ?? 'all'}'));
    await tester.ensureVisible(option);
    await tester.tap(option);
    await settle(tester);
  }

  /// The sample plants' names in [category], or all of them.
  List<String> namesIn(CropCategory? category) => [
        for (final p in samplePlants)
          if (category == null || p.category == category) p.name,
      ];

  void expectShown(List<String> shown) {
    for (final p in samplePlants) {
      expect(
        find.text(p.name),
        shown.contains(p.name) ? findsOneWidget : findsNothing,
        reason: p.name,
      );
    }
  }

  // A category with some, but not all, sample plants, and one with none.
  final used = {for (final p in samplePlants) p.category};
  final some = used.first;
  final none = CropCategory.values.firstWhere((c) => !used.contains(c));

  testWidgets('the filter button shows the filtering options', (tester) async {
    await openScreen(tester);
    await tester.tap(find.byKey(const Key('plantsFilter')));
    await settle(tester);

    expect(find.text('Filter by category'), findsOneWidget);
    expect(find.byKey(const Key('filterOption_all')), findsOneWidget);
    for (final c in CropCategory.values) {
      expect(find.byKey(Key('filterOption_${c.name}')), findsOneWidget);
    }
  });

  testWidgets('a category shows only my plants in it', (tester) async {
    await openScreen(tester);
    await choose(tester, some);

    expect(namesIn(some).length, lessThan(samplePlants.length));
    expectShown(namesIn(some));
  });

  testWidgets('a category with no plants says so', (tester) async {
    await openScreen(tester);
    await choose(tester, none);

    expectShown(const []);
    expect(find.text('No Plants in This Category'), findsOneWidget);
  });

  testWidgets('clearing the filter shows all my plants again', (tester) async {
    await openScreen(tester);

    // From the chip under the header.
    await choose(tester, some);
    await tester.tap(find.byKey(const Key('clearPlantsFilter')));
    await settle(tester);
    expectShown(namesIn(null));

    // From the chip's X when nothing matches (the message has no button).
    await choose(tester, none);
    await tester.tap(find.byKey(const Key('clearPlantsFilter')));
    await settle(tester);
    expectShown(namesIn(null));

    // By picking "All" in the sheet.
    await choose(tester, some);
    await choose(tester, null);
    expectShown(namesIn(null));
  });
}
