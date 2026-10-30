/// Picking where a new plant goes on the farm. Nothing is saved here: the
/// result becomes the plant's `land` and `square` fields (see farm_plant.dart).
library;

import '../services/farm_store.dart';
import 'farm_plant.dart';

/// The first free square, filling land 0 (squares 0-24) before land 1, and
/// so on. Null when all [lands] are full: add a land first.
({int land, int square})? firstFreeSpot(Iterable<FarmPlant> plants, int lands) {
  final taken = {for (final p in plants) (p.land, p.square)};
  for (var land = 0; land < lands; land++) {
    for (var square = 0; square < FarmStore.squaresPerLand; square++) {
      if (!taken.contains((land, square))) {
        return (land: land, square: square);
      }
    }
  }
  return null;
}
