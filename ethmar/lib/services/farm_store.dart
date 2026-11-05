import 'package:flutter/foundation.dart';

import '../models/farm_plant.dart';
import '../models/farm_spot.dart';
import '../models/farm_stats.dart';
import '../models/task_log.dart';
import 'plant_service.dart';

/// The user's farm while the app is open: the latest lands and plants from
/// Firestore, ready for the screens to read and listen to.
///
/// Changes go through the methods below and are saved by [PlantService].
/// [plants] and [lands] then update by themselves, from the live streams.
class FarmStore {
  FarmStore._();

  static const squaresPerSide = FarmGrid.squaresPerSide;
  static const squaresPerLand = FarmGrid.squaresPerLand;
  static const maxLands = FarmGrid.maxLands;

  static final lands = ValueNotifier<int>(1);

  /// Sorted by land, then square.
  static final plants = ValueNotifier<List<FarmPlant>>(const []);

  /// The streak and lands, as saved (Home shows the streak).
  static final stats = ValueNotifier<FarmStats>(const FarmStats());

  static final _service = PlantService();

  /// The latest plants and lands, exactly as saved.
  static List<FarmPlant> _savedPlants = const [];
  static int _savedLands = 1;

  /// TODO(growth): Save entries in Firestore and load them for each plant.
  ///   Prototype: kept in memory by plant id, so they're gone after a restart.
  static final _growth = <String, List<GrowthEntry>>{};

  static bool _started = false;

  /// Starts following the user's farm. Call once, after Firebase is ready.
  /// It follows sign-in and sign-out by itself.
  static void start() {
    if (_started) return;
    _started = true;
    _service.watchPlants().listen((saved) {
      _savedPlants = saved;
      _publish();
    }, onError: (Object e) => debugPrint('Could not load the plants: $e'));
    _service.watchStats().listen((saved) {
      stats.value = saved;
      _savedLands = saved.lands;
      _publish();
    }, onError: (Object e) => debugPrint('Could not load the lands: $e'));
  }

  /// Lands go first: the farm needs a land under every plant it draws.
  static void _publish() {
    lands.value = landsToShow(_savedLands, _savedPlants);
    plants.value = [
      for (final plant in _savedPlants)
        (_growth[plant.id] ?? const <GrowthEntry>[]).fold(
          plant,
          (p, entry) => p.withGrowth(entry),
        ),
    ];
  }

  /// True when every square on every land has a plant.
  static bool get landsFull =>
      plants.value.length >= lands.value * squaresPerLand;

  /// The plant with this id, or null if it's gone (e.g. just deleted).
  static FarmPlant? plantById(String id) =>
      plants.value.where((p) => p.id == id).firstOrNull;

  /// Saves a new plant on the first free square and returns it.
  /// Throws a [FarmFullException] if there is no free square.
  static Future<FarmPlant> addPlant(FarmPlant plant) =>
      _service.addPlant(plant, lands: lands.value);

  /// Saves a plant's changes (e.g. after editing its schedules). It keeps
  /// its square.
  static Future<void> updatePlant(FarmPlant plant) =>
      _service.updatePlant(plant);

  /// Deletes a plant and its growth entries.
  static Future<void> deletePlant(String plantId) async {
    await _service.deletePlant(plantId);
    _growth.remove(plantId);
  }

  /// Adds to a plant's growth timeline, in memory for now (see [_growth]).
  static void addGrowth(String plantId, GrowthEntry entry) {
    _growth[plantId] = [...?_growth[plantId], entry];
    _publish();
  }

  /// Live task log of the day [date] ("yyyy-mm-dd", see [TaskLog.dateKey]).
  static Stream<TaskLog> watchTaskLog(String date) =>
      _service.watchTaskLog(date);

  /// Marks a task of [today] done or not done, and updates the streak.
  /// [todayTaskIds] are the ids of every task due today.
  static Future<void> setTaskDone({
    required DateTime today,
    required String taskId,
    required bool done,
    required List<String> todayTaskIds,
  }) => _service.setTaskDone(
    today: today,
    taskId: taskId,
    done: done,
    todayTaskIds: todayTaskIds,
    plants: _savedPlants,
  );

  /// Resets the streak if a day with tasks was missed (see streak.dart).
  static Future<void> checkStreak() => _service.checkStreak(DateTime.now());

  /// Saves one more land, up to [maxLands].
  static Future<void> addLand() async {
    if (lands.value < maxLands) await _service.saveLands(lands.value + 1);
  }
}
