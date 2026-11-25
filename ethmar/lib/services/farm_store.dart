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

/// Deletes the plants [ids] one after another with [deleteOne], and
/// returns the error of each one that couldn't be deleted.
///
/// [deleteOne] gets the ids already deleted, so the streak counts only
/// deletes that succeeded: while a plant with a task still to do isn't
/// confirmed gone, today can't be completed by deleting the others. A
/// failure doesn't stop the rest. No delete is tried twice.
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
/// [plants] and [lands] then update by themselves, from the live streams.
class FarmStore {
  FarmStore._();

  static const squaresPerSide = FarmGrid.squaresPerSide;
  static const squaresPerLand = FarmGrid.squaresPerLand;
  static const maxLands = FarmGrid.maxLands;

  static final lands = ValueNotifier<int>(1);

  /// Sorted by land, then square.
  static final plants = ValueNotifier<List<FarmPlant>>(const []);

  /// True once the signed-in user's plants have arrived. Until then an empty
  /// [plants] doesn't mean the farm is empty.
  static final plantsLoaded = ValueNotifier<bool>(false);

  /// The streak and lands, as saved (Home shows the streak).
  static final stats = ValueNotifier<FarmStats>(const FarmStats());

  static final _service = PlantService();
  static final _photos = JourneyPhotoService();

  /// The latest plants and lands, exactly as saved.
  static List<FarmPlant> _savedPlants = const [];
  static int _savedLands = 1;

  static bool _started = false;

  /// Starts following the user's farm. Call once, after Firebase is ready.
  /// It follows sign-in and sign-out by itself.
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

  /// Lands go first: the farm needs a land under every plant it draws.
  static void _publish() {
    lands.value = landsToShow(_savedLands, _savedPlants);
    plants.value = _savedPlants;
  }

  /// True when every square on every land has a plant.
  static bool get landsFull =>
      plants.value.length >= lands.value * squaresPerLand;

  /// The plant with this id, or null if it's gone (e.g. just deleted).
  static FarmPlant? plantById(String id) =>
      plants.value.where((p) => p.id == id).firstOrNull;

  /// A new, unused plant id, for [addPlant].
  static String newPlantId() => _service.newPlantId();

  /// Saves a new plant on the first free square and returns it. Trying
  /// again with the same [id] (from [newPlantId]) never adds it twice.
  /// Throws a [FarmFullException] if there is no free square, and a
  /// network error (see isNetworkError) when offline.
  static Future<FarmPlant> addPlant(FarmPlant plant, {String? id}) =>
      _service.addPlant(plant, lands: lands.value, id: id);

  /// Saves the Edit Plant screen's changes: only the fields the user
  /// changed, over the plant as it is saved now (see
  /// [PlantService.editPlant]). It keeps its square. The streak follows
  /// today's tasks after the change (see streakAfterScheduleChange).
  static Future<void> editPlant(PlantEdit edit) async {
    final fake = editForTests;
    if (fake != null) return fake(edit);
    _reportLost(await _service.editPlant(edit, plants: _savedPlants));
  }

  /// Replaces [editPlant] in widget tests, which have no Firebase.
  @visibleForTesting
  static Future<void> Function(PlantEdit edit)? editForTests;

  /// Deletes running now, by plant id, so asking again joins the one
  /// already running instead of starting a second.
  static final _deletesRunning = <String, Future<void>>{};

  /// Deletes a plant, its journey entries and their photos. If it had
  /// today's last unfinished task, today is completed for the streak (see
  /// PlantService.deletePlant). Throws if it couldn't be deleted; the
  /// plant then stays.
  static Future<void> deletePlant(String plantId) async {
    final failed = await deletePlants([plantId]);
    if (failed[plantId] case final error?) throw error;
  }

  /// Deletes the plants [ids] one after another (see [deletePlantsInTurn])
  /// and returns the error of each one that couldn't be deleted; those
  /// stay on the farm. Each delete counts only the ones already deleted as
  /// gone, so a failed one can never complete today for the streak.
  static Future<Map<String, Object>> deletePlants(List<String> ids) =>
      deletePlantsInTurn(ids, _deleteOne);

  static Future<void> _deleteOne(String id, Set<String> deleted) {
    final running = _deletesRunning[id];
    if (running != null) return running;
    // A block: remove() returns this same future, which whenComplete
    // would otherwise wait for.
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
    // The plant is gone; a photo left behind only takes space.
    unawaited(
      _photos
          .deletePlantPhotos(id)
          .catchError((Object e) => debugPrint('Journey photos kept: $e')),
    );
  }

  /// Replaces [deletePlant]'s Firestore work in widget tests, which have
  /// no Firebase.
  @visibleForTesting
  static Future<void> Function(String plantId)? deleteForTests;

  /// Live journey timeline of [plantId], newest first.
  static Stream<List<JourneyEntry>> watchJourney(String plantId) =>
      (journeyForTests ?? _service.watchJourney)(plantId);

  /// Replaces [watchJourney] in widget tests, which have no Firebase.
  @visibleForTesting
  static Stream<List<JourneyEntry>> Function(String plantId)? journeyForTests;

  /// Adds [image] to [plantId]'s journey timeline, with optional [notes].
  /// The photo is uploaded first; if the entry then can't be saved, the
  /// photo is deleted again. Throws a [JourneyPhotoException] if the upload
  /// fails, or Firestore's error if saving does.
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

  /// Live task log of the day [date] ("yyyy-mm-dd", see [TaskLog.dateKey]).
  static Stream<TaskLog> watchTaskLog(String date) =>
      (taskLogForTests ?? _service.watchTaskLog)(date);

  /// Replaces [watchTaskLog] in widget tests, which have no Firebase.
  @visibleForTesting
  static Stream<TaskLog> Function(String date)? taskLogForTests;

  /// Marks a task of [today] done or not done, and updates the streak and
  /// the plant's next task (see PlantService.setTaskDone).
  /// [todayTaskIds] are the ids of every task due today.
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

  /// Marks a missed task of the past day [day] done late today, or not.
  /// The plant's next task then counts from today; the streak doesn't
  /// change.
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

  /// Replaces [setTaskDone] and [setLateTaskDone] in widget tests, which
  /// have no Firebase.
  @visibleForTesting
  static Future<void> Function(String taskId,
      {required bool done, required bool late})? taskForTests;

  /// Resets the streak if a day with tasks was missed (see streak.dart).
  static Future<void> checkStreak() async =>
      _reportLost(await _service.checkStreak(DateTime.now()));

  /// The streak just lost because a day was missed, until Home has told
  /// the user (it then sets it back to 0).
  static final streakLost = ValueNotifier<int>(0);

  static void _reportLost(int streak) {
    if (streak > 0) streakLost.value = streak;
  }

  /// Saves one more land, up to [maxLands].
  static Future<void> addLand() async {
    if (lands.value < maxLands) await _service.saveLands(lands.value + 1);
  }
}
