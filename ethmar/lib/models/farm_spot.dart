/// Where plants sit on the farm: the size of the grid, and picking a spot for
/// a new plant. Nothing is saved here: a spot becomes the plant's `land` and
/// `square` fields (see farm_plant.dart).
library;

import 'dart:math' as math;

import 'farm_plant.dart';

/// The size of the farm.
class FarmGrid {
  FarmGrid._();

  /// Squares along each side of a land: 5 × 5 = 25 squares, one plant each,
  /// with room to breathe between them.
  static const squaresPerSide = 5;
  static const squaresPerLand = squaresPerSide * squaresPerSide;

  /// The farm grows to at most 3 × 3 lands.
  static const maxLands = 9;
}

/// The first free square, filling land 0 (squares 0-24) before land 1, and
/// so on. Null when all [lands] are full: add a land first.
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

/// False when [plant]'s saved spot isn't a real square on the farm.
bool isOnFarm(FarmPlant plant) =>
    plant.land >= 0 &&
    plant.land < FarmGrid.maxLands &&
    plant.square >= 0 &&
    plant.square < FarmGrid.squaresPerLand;

/// [plants] sorted by land, then square.
List<FarmPlant> inFarmOrder(Iterable<FarmPlant> plants) => [...plants]
  ..sort((a, b) {
    final byLand = a.land.compareTo(b.land);
    return byLand != 0 ? byLand : a.square.compareTo(b.square);
  });

/// How many lands to draw: [savedLands], or more if a plant sits further
/// out, so every plant always has a land under it (the lands and the plants
/// load separately).
int landsToShow(int savedLands, Iterable<FarmPlant> plants) =>
    plants.fold(savedLands, (lands, p) => math.max(lands, p.land + 1));
