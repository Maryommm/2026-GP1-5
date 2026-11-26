import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/daily_task.dart' show TaskType;
import '../models/farm_plant.dart';
import '../models/farm_spot.dart';
import '../models/farm_stats.dart';
import '../models/plant_edit.dart';
import '../models/task_log.dart';
import 'journey_photo_service.dart';
import 'plant_service.dart';

/// Deletes the plants [ids] one by one with [deleteOne], and returns the
/// error for each one that couldn't be deleted.
///
/// [deleteOne] gets the ids that were already deleted, so the streak only
/// counts deletes that worked. If one fails, the rest still run. No delete
/// is tried twice.
Future<Map<String, Object>> deletePlantsInTurn(
  List<String> ids,
  Future<void> Function(String id, Set<String> deleted) deleteOne,
) async {
  final deleted = <String>{};
  final failed = <String, Object>{};
  for (final id in {...ids}) {
    try {
      await deleteOne(id, Set.unmodifiable(deleted));
      deleted.add(id);
    } catch (e) {
      debugPrint('Could not delete plant $id: $e');
      failed[id] = e;
    }
  }
  return failed;
}

/// The user's farm while the app is open: the latest lands and plants from
/// Firestore, ready for the screens to read and listen to.
///
/// Changes go through the methods below and are saved by [PlantService].
/// [plants] and [lands] then update automatically from the live streams.
class FarmStore {
  FarmStore._();

  static const squaresPerSide = FarmGrid.squaresPerSide;
  static const squaresPerLand = FarmGrid.squaresPerLand;
  static const maxLands = FarmGrid.maxLands;

  static final lands = ValueNotifier<int>(1);

  /// Sorted by land, then by square.
  static final plants = ValueNotifier<List<FarmPlant>>(const []);

  /// True once the user's plants have loaded. Until then, an empty [plants]
  /// list doesn't mean the farm is empty.
  static final plantsLoaded = ValueNotifier<bool>(false);

  /// The saved streak and lands (Home shows the streak).
  static final stats = ValueNotifier<FarmStats>(const FarmStats());

  static final _service = PlantService();
  static final _photos = JourneyPhotoService();

  /// The latest plants and lands, exactly as saved.
  static List<FarmPlant> _savedPlants = const [];
  static int _savedLands = 1;

  static bool _started = false;

  /// Starts listening to the user's farm. Call once, after Firebase is ready.
  /// It handles sign-in and sign-out by itself.
  static void start() {
    if (_started) return;
    _started = true;
    _service.watchPlants().listen((saved) {
      _savedPlants = saved;
      _publish();
      plantsLoaded.value = _service.signedIn;
    }, onError: (Object e) => debugPrint('Could not load the plants: $e'));
    _service.watchStats().listen((saved) {
      stats.value = saved;
      _savedLands = saved.lands;
      _publish();
    }, onError: (Object e) => debugPrint('Could not load the lands: $e'));
  }

  /// Lands are updated first, because every plant needs a land under it.
  static void _publish() {
    lands.value = landsToShow(_savedLands, _savedPlants);
    plants.value = _savedPlants;
  }

  /// True when every square on every land has a plant.
  static bool get landsFull =>
      plants.value.length >= lands.value * squaresPerLand;

  /// The plant with this id, or null if it's gone (for example just deleted).
  static FarmPlant? plantById(String id) =>
      plants.value.where((p) => p.id == id).firstOrNull;

  /// A new, unused plant id for [addPlant].
  static String newPlantId() => _service.newPlantId();

  /// Saves a new plant on the first free square and returns it. Trying again
  /// with the same [id] (from [newPlantId]) never adds it twice.
  /// Throws a [FarmFullException] if there is no free square, and a network
  /// error (see isNetworkError) when offline.
  static Future<FarmPlant> addPlant(FarmPlant plant, {String? id}) =>
      _service.addPlant(plant, lands: lands.value, id: id);

  /// Saves the changes from the Edit Plant screen. Only the fields the user
  /// changed are written (see [PlantService.editPlant]). The plant keeps its
  /// square, and the streak is updated for today's tasks.
  static Future<void> editPlant(PlantEdit edit) async {
    final fake = editForTests;
    if (fake != null) return fake(edit);
    _reportLost(await _service.editPlant(edit, plants: _savedPlants));
  }

  /// Replaces [editPlant] in widget tests (they have no Firebase).
  @visibleForTesting
  static Future<void> Function(PlantEdit edit)? editForTests;

  /// Deletes that are running now, by plant id. Asking again waits for the
  /// running one instead of starting a second one.
  static final _deletesRunning = <String, Future<void>>{};

  /// Deletes a plant, its journey entries and their photos. If it had
  /// today's last unfinished task, today counts as completed for the streak.
  /// Throws if it couldn't be deleted, and the plant stays.
  static Future<void> deletePlant(String plantId) async {
    final failed = await deletePlants([plantId]);
    if (failed[plantId] case final error?) throw error;
  }

  /// Deletes the plants [ids] one by one (see [deletePlantsInTurn]) and
  /// returns the error for each one that couldn't be deleted. Those plants
  /// stay on the farm.
  static Future<Map<String, Object>> deletePlants(List<String> ids) =>
      deletePlantsInTurn(ids, _deleteOne);

  static Future<void> _deleteOne(String id, Set<String> deleted) {
    final running = _deletesRunning[id];
    if (running != null) return running;
    // Uses a block body: remove() returns this same future, and whenComplete
    // would wait for it.
    final delete = _deleteNow(id, deleted).whenComplete(() {
      _deletesRunning.remove(id);
    });
    _deletesRunning[id] = delete;
    return delete;
  }

  static Future<void> _deleteNow(String id, Set<String> deleted) async {
    final fake = deleteForTests;
    if (fake != null) return fake(id);
    _reportLost(await _service.deletePlant(
      id,
      others: [
        for (final p in _savedPlants)
          if (p.id != id && !deleted.contains(p.id)) p,
      ],
    ));
    // The plant is gone. A leftover photo only takes space, so we don't wait.
    unawaited(
      _photos
          .deletePlantPhotos(id)
          .catchError((Object e) => debugPrint('Journey photos kept: $e')),
    );
  }

  /// Replaces [deletePlant]'s Firestore work in widget tests (they have no
  /// Firebase).
  @visibleForTesting
  static Future<void> Function(String plantId)? deleteForTests;

  /// The live journey timeline of [plantId], newest first.
  static Stream<List<JourneyEntry>> watchJourney(String plantId) =>
      (journeyForTests ?? _service.watchJourney)(plantId);

  /// Replaces [watchJourney] in widget tests (they have no Firebase).
  @visibleForTesting
  static Stream<List<JourneyEntry>> Function(String plantId)? journeyForTests;

  /// Adds [image] to [plantId]'s journey timeline, with optional [notes].
  /// The photo is uploaded first. If the entry can't be saved after that,
  /// the photo is deleted. Throws a [JourneyPhotoException] if the upload
  /// fails, or Firestore's error if saving fails.
  static Future<void> addJourneyEntry(
    String plantId,
    XFile image, {
    String? notes,
  }) async {
    final entryId = _service.newJourneyEntryId(plantId);
    final photo = await _photos.upload(
      image,
      plantId: plantId,
      entryId: entryId,
    );
    try {
      await _service.saveJourneyEntry(
        plantId,
        entryId,
        photo: photo,
        notes: notes,
      );
    } catch (_) {
      unawaited(
        _photos
            .deleteEntryPhoto(plantId: plantId, entryId: entryId)
            .catchError((Object e) => debugPrint('Journey photo kept: $e')),
      );
      rethrow;
    }
  }

  /// The live task log for [date] ("yyyy-mm-dd", see [TaskLog.dateKey]).
  static Stream<TaskLog> watchTaskLog(String date) =>
      (taskLogForTests ?? _service.watchTaskLog)(date);

  /// Replaces [watchTaskLog] in widget tests (they have no Firebase).
  @visibleForTesting
  static Stream<TaskLog> Function(String date)? taskLogForTests;

  /// Marks a task of [today] as done or not done, and updates the streak and
  /// the plant's next task (see PlantService.setTaskDone).
  /// [todayTaskIds] are the ids of all tasks due today.
  static Future<void> setTaskDone({
    required DateTime today,
    required String plantId,
    required TaskType type,
    required String taskId,
    required bool done,
    required List<String> todayTaskIds,
  }) async {
    final fake = taskForTests;
    if (fake != null) return fake(taskId, done: done, late: false);
    _reportLost(await _service.setTaskDone(
      today: today,
      plantId: plantId,
      type: type,
      taskId: taskId,
      done: done,
      todayTaskIds: todayTaskIds,
      plants: _savedPlants,
    ));
  }

  /// Marks a missed task from [day] as done late today (or not done). The
  /// plant's next task then counts from today. The streak doesn't change.
  static Future<void> setLateTaskDone({
    required DateTime day,
    required String plantId,
    required TaskType type,
    required String taskId,
    required bool done,
  }) async {
    final fake = taskForTests;
    if (fake != null) return fake(taskId, done: done, late: true);
    await _service.setLateTaskDone(
      day: day,
      doneOn: DateTime.now(),
      plantId: plantId,
      type: type,
      taskId: taskId,
      done: done,
    );
  }

  /// Replaces [setTaskDone] and [setLateTaskDone] in widget tests (they have
  /// no Firebase).
  @visibleForTesting
  static Future<void> Function(String taskId,
      {required bool done, required bool late})? taskForTests;

  /// Resets the streak if a day with tasks was missed (see streak.dart).
  static Future<void> checkStreak() async =>
      _reportLost(await _service.checkStreak(DateTime.now()));

  /// The streak that was just lost because a day was missed. Home shows a
  /// message and then sets it back to 0.
  static final streakLost = ValueNotifier<int>(0);

  static void _reportLost(int streak) {
    if (streak > 0) streakLost.value = streak;
  }

  /// Adds one more land, up to [maxLands].
  static Future<void> addLand() async {
    if (lands.value < maxLands) await _service.saveLands(lands.value + 1);
  }
}
