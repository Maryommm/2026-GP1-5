import 'package:ethmar/data/sample_plants.dart';
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

Future<void> _showFarm(WidgetTester tester, List<FarmPlant> plants) async {
  FarmStore.lands.value = 2;
  FarmStore.plants.value = plants;
  await tester.pumpWidget(const MaterialApp(home: VirtualFarmScreen()));
  await _settle(tester);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  tearDown(() {
    FarmStore.lands.value = 1;
    FarmStore.plants.value = const [];
  });

  testWidgets('every plant is drawn, on both lands', (tester) async {
    await _showFarm(tester, samplePlants);
    for (final plant in samplePlants) {
      expect(_plantNamed(plant.name), findsOneWidget);
    }
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
