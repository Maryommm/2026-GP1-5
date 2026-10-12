import 'package:flutter/foundation.dart';

import '../models/farm_plant.dart';

/// The user's farm while the app is open: how many lands, and the plants in
/// the order they were added. Plant number i sits in square i, filling each
/// land ([squaresPerLand] squares) before the next.
///
/// TODO(backend): Load the user's lands and plants from the database when
///   the app starts, and save every change. Prototype: kept in memory only,
///   so the farm is empty again after the app restarts.
class FarmStore {
  FarmStore._();

  /// Squares along each side of a land: 5 × 5 = 25 squares, one plant each,
  /// with room to breathe between them.
  static const squaresPerSide = 5;
  static const squaresPerLand = squaresPerSide * squaresPerSide;

  /// The farm grows to at most 3 × 3 lands.
  static const maxLands = 9;

  static final lands = ValueNotifier<int>(1);
  static final plants = ValueNotifier<List<FarmPlant>>(const []);

  /// True when every square on every land has a plant.
  static bool get landsFull =>
      plants.value.length >= lands.value * squaresPerLand;

  static void addPlant(FarmPlant plant) {
    assert(!landsFull, 'Add a land before adding more plants.');
    plants.value = [...plants.value, plant];
  }

  /// Replaces plant number [index] (e.g. after editing its schedules or
  /// adding to its growth timeline). It keeps its square.
  static void updatePlant(int index, FarmPlant plant) {
    plants.value = [...plants.value]..[index] = plant;
  }

  static void addLand() {
    if (lands.value < maxLands) lands.value++;
  }
}
