/// Where plants go on the farm: the grid size, and picking a spot for a new
/// plant. Nothing is saved here; the spot is stored in the plant's `land`
/// and `square` fields (see farm_plant.dart).
library;

import 'dart:math' as math;

import 'farm_plant.dart';

/// The size of the farm.
class FarmGrid {
  FarmGrid._();

  /// Squares on each side of a land: 5 × 5 = 25 squares, one plant each.
  static const squaresPerSide = 5;
  static const squaresPerLand = squaresPerSide * squaresPerSide;

  /// The farm can grow to at most 3 × 3 lands.
  static const maxLands = 9;
}

/// The first free square. Land 0 (squares 0-24) is filled before land 1,
/// and so on. Returns null when all [lands] are full.
({int land, int square})? firstFreeSpot(Iterable<FarmPlant> plants, int lands) {
  final taken = {for (final p in plants) (p.land, p.square)};
  for (var land = 0; land < lands; land++) {
    for (var square = 0; square < FarmGrid.squaresPerLand; square++) {
      if (!taken.contains((land, square))) {
        return (land: land, square: square);
      }
    }
  }
  return null;
}

/// False when [plant]'s saved spot is not a real square on the farm.
bool isOnFarm(FarmPlant plant) =>
    plant.land >= 0 &&
    plant.land < FarmGrid.maxLands &&
    plant.square >= 0 &&
    plant.square < FarmGrid.squaresPerLand;

/// [plants] sorted by land, then by square.
List<FarmPlant> inFarmOrder(Iterable<FarmPlant> plants) => [...plants]
  ..sort((a, b) {
    final byLand = a.land.compareTo(b.land);
    return byLand != 0 ? byLand : a.square.compareTo(b.square);
  });

/// How many lands to draw: [savedLands], or more if a plant is on a later
/// land. This way every plant always has a land under it (lands and plants
/// load separately).
int landsToShow(int savedLands, Iterable<FarmPlant> plants) =>
    plants.fold(savedLands, (lands, p) => math.max(lands, p.land + 1));
