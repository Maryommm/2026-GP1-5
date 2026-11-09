import 'dart:async';

import 'package:ethmar/data/sample_plants.dart';
import 'package:ethmar/models/farm_plant.dart';
import 'package:ethmar/screens/plant_details_screen.dart';
import 'package:ethmar/services/farm_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  /// What the growth timeline shows; tests have no Firebase.
  late StreamController<List<GrowthEntry>> growth;

  setUp(() {
    growth = StreamController<List<GrowthEntry>>.broadcast();
    FarmStore.growthForTests = (_) => growth.stream;
  });

  tearDown(() {
    FarmStore.plants.value = const [];
    FarmStore.plantsLoaded.value = false;
    FarmStore.growthForTests = null;
    growth.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Opens the first sample plant's details from a start page.
  Future<NavigatorState> openDetails(WidgetTester tester) async {
    final navigator = GlobalKey<NavigatorState>();
    FarmStore.plants.value = samplePlants;
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: const Text('start')),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => PlantDetailsScreen(plantId: samplePlants.first.id!),
      ),
    );
    await settle(tester);
    expect(find.byType(PlantDetailsScreen), findsOneWidget);
    return navigator.currentState!;
  }

  group('closing', () {
    testWidgets('the screen closes when its plant is deleted', (tester) async {
      await openDetails(tester);

      FarmStore.plants.value = samplePlants.skip(1).toList();
      await settle(tester);

      expect(find.byType(PlantDetailsScreen), findsNothing);
      expect(find.text('start'), findsOneWidget);
    });

    testWidgets('it closes even when another screen is on top', (tester) async {
      final navigator = await openDetails(tester);
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const Text('on top')),
      );
      await settle(tester);

      FarmStore.plants.value = samplePlants.skip(1).toList();
      await settle(tester);
      expect(find.text('on top'), findsOneWidget);

      navigator.pop();
      await settle(tester);
      expect(find.byType(PlantDetailsScreen), findsNothing);
      expect(find.text('start'), findsOneWidget);
    });
  });

  group('growth timeline', () {
    // The sample tomato was planted on 1 September 2026.
    final photo = GrowthPhoto(
      publicId: GrowthPhoto.publicIdFor('uid', 'sample-tomato', 'e2'),
      version: 3,
      format: 'webp',
      width: 1600,
      height: 1200,
      bytes: 200000,
    );
    final newest = GrowthEntry(
      id: 'e2',
      date: DateTime(2026, 10, 5, 17, 45),
      notes: 'Flowers are opening.',
      photo: photo,
    );
    final oldest = GrowthEntry(
      id: 'e1',
      date: DateTime(2026, 9, 10, 9),
      photo: photo,
    );

    Future<void> showTimeline(
      WidgetTester tester,
      List<GrowthEntry> entries,
    ) async {
      await openDetails(tester);
      growth.add(entries);
      await settle(tester);
      await tester.scrollUntilVisible(find.text('Upload a picture'), 200);
      await settle(tester);
    }

    testWidgets('shows newest first, with the day of the plant\'s life', (
      tester,
    ) async {
      await showTimeline(tester, [newest, oldest]);

      final day34 = tester.getTopLeft(find.text('Day 34'));
      final day9 = tester.getTopLeft(find.text('Day 9'));
      expect(day34.dy, lessThan(day9.dy));
      expect(find.text('Flowers are opening.'), findsOneWidget);
    });

    testWidgets('notes are optional: no placeholder when there are none', (
      tester,
    ) async {
      await showTimeline(tester, [oldest]);

      expect(find.text('Day 9'), findsOneWidget);
      expect(find.text('—'), findsNothing);
    });

    testWidgets('each picture loads from its Cloudinary address', (
      tester,
    ) async {
      await showTimeline(tester, [newest]);

      final urls = tester
          .widgetList<Image>(find.byType(Image))
          .map((i) => i.image)
          .whereType<ResizeImage>()
          .map((r) => r.imageProvider)
          .whereType<NetworkImage>()
          .map((n) => n.url);
      expect(
        urls,
        contains(
          'https://res.cloudinary.com/k7otdsln/image/upload/v3/'
          'ethmar/plant-growth/uid/sample-tomato/e2.webp',
        ),
      );
    });

    testWidgets('with no pictures yet, it invites the first one', (
      tester,
    ) async {
      await showTimeline(tester, const []);

      expect(find.textContaining('No pictures yet'), findsOneWidget);
    });
  });
}
