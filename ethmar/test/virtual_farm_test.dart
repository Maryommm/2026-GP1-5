import 'package:ethmar/data/sample_plants.dart';
import 'package:ethmar/models/crop_catalog.dart';
import 'package:ethmar/models/farm_plant.dart';
import 'package:ethmar/screens/virtual_farm_screen.dart';
import 'package:ethmar/services/farm_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// The plant drawn on the farm under this name.
Finder _plantNamed(String name) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == name,
);

// Lets the entrance and pop-in animations finish.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _showFarm(
  WidgetTester tester,
  List<FarmPlant> plants, {
  int lands = 2,
  bool loaded = true,
}) async {
  FarmStore.lands.value = lands;
  FarmStore.plants.value = plants;
  FarmStore.plantsLoaded.value = loaded;
  await tester.pumpWidget(const MaterialApp(home: VirtualFarmScreen()));
  await _settle(tester);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  tearDown(() {
    FarmStore.lands.value = 1;
    FarmStore.plants.value = const [];
    FarmStore.plantsLoaded.value = false;
  });

  testWidgets('every plant is drawn, on both lands', (tester) async {
    await _showFarm(tester, samplePlants);
    for (final plant in samplePlants) {
      expect(_plantNamed(plant.name), findsOneWidget);
    }
  });

  testWidgets('an empty farm prompts for the first plant', (tester) async {
    await _showFarm(tester, const []);
    expect(find.text('Your farm is empty'), findsOneWidget);
    expect(find.text('Add your first plant'), findsOneWidget);
    expect(find.text('Add Plant'), findsNothing);
  });

  testWidgets('no prompt while the plants are loading', (tester) async {
    await _showFarm(tester, const [], loaded: false);
    expect(find.text('Your farm is empty'), findsNothing);
  });

  testWidgets('no prompt once the farm has plants', (tester) async {
    await _showFarm(tester, samplePlants);
    expect(find.text('Your farm is empty'), findsNothing);
  });

  testWidgets('Add land appears only when every square is full', (
    tester,
  ) async {
    final full = [
      for (var square = 0; square < FarmStore.squaresPerLand; square++)
        FarmPlant(
          id: 'p$square',
          crop: cropCatalog.first,
          name: 'Plant $square',
          square: square,
        ),
    ];
    await _showFarm(tester, full.skip(1).toList(), lands: 1);
    expect(find.text('Add land'), findsNothing);

    FarmStore.plants.value = full;
    await _settle(tester);
    expect(find.text('Add land'), findsOneWidget);
  });

  testWidgets('removing a plant leaves the others in their squares', (
    tester,
  ) async {
    await _showFarm(tester, samplePlants);
    final before = {
      for (final p in samplePlants) p.name: tester.getCenter(_plantNamed(p.name)),
    };

    final remaining = samplePlants.where((p) => p.name != 'Basil').toList();
    FarmStore.plants.value = remaining;
    await _settle(tester);

    expect(_plantNamed('Basil'), findsNothing);
    for (final plant in remaining) {
      expect(tester.getCenter(_plantNamed(plant.name)), before[plant.name]);
    }
  });
}
