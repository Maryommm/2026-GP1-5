import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/daily_task.dart' show TaskType;
import '../models/farm_plant.dart';
import '../models/farm_spot.dart';
import '../models/farm_stats.dart';
import '../models/plant_edit.dart';
import '../models/streak.dart';
import '../models/task_log.dart';
import 'network_errors.dart';

/// Error when every square on every land already has a plant.
class FarmFullException implements Exception {
  const FarmFullException();
}

/// Reads and saves the signed-in user's plants, farm stats and task log in
/// Firestore. See farm_plant.dart, farm_stats.dart and task_log.dart for the
/// paths and fields.
///
/// Screens normally go through `FarmStore`, which keeps the latest values
/// ready for them.
class PlantService {
  PlantService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// The signed-in user's id. Throws a [StateError] if nobody is signed in.
  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No authenticated user is available.');
    return user.uid;
  }

  /// True while somebody is signed in.
  bool get signedIn => _auth.currentUser != null;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _plants(String uid) =>
      _userDoc(uid).collection('plants');

  DocumentReference<Map<String, dynamic>> _stats(String uid) =>
      _userDoc(uid).collection('stats').doc(FarmStats.docId);

  DocumentReference<Map<String, dynamic>> _taskLog(String uid, String date) =>
      _userDoc(uid).collection('taskLog').doc(date);

  CollectionReference<Map<String, dynamic>> _journey(
    String uid,
    String plantId,
  ) => _plants(uid).doc(plantId).collection('journey');

  /// Live journey timeline of [plantId], newest first. Empty when signed out.
  Stream<List<JourneyEntry>> watchJourney(String plantId) => _forEachUser(
    signedOut: const [],
    watch: (uid) => _journey(
      uid,
      plantId,
    ).snapshots().map((snapshot) => _readJourney(snapshot.docs)),
  );

  /// A new, unused id for a journey entry of [plantId]. The photo is
  /// uploaded under it first, then the entry is saved with it.
  String newJourneyEntryId(String plantId) => _journey(_uid, plantId).doc().id;

  /// Saves journey entry [entryId] of [plantId]. The date is the server's
  /// time of saving; the rules accept no other.
  ///
  /// Saved on the server or not at all (see [SaveOnServer.saveOnServer]):
  /// offline it fails, and the photo already uploaded for it is deleted,
  /// so an entry can't reach the server later pointing at a deleted photo.
  Future<void> saveJourneyEntry(
    String plantId,
    String entryId, {
    required JourneyPhoto photo,
    String? notes,
  }) {
    final entry = _journey(_uid, plantId).doc(entryId);
    return _firestore.saveOnServer<void>((transaction) async {
      transaction.set(entry, {
        'date': FieldValue.serverTimestamp(),
        'notes': notes,
        'photo': photo.toMap(),
      });
    });
  }

  /// Builds the entries, newest first. One bad document is skipped.
  List<JourneyEntry> _readJourney(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final entries = <JourneyEntry>[];
    for (final doc in docs) {
      var data = doc.data();
      // Saved on this phone but not yet on the server: the server's date
      // isn't known yet, so show it as now.
      if (data['date'] == null && doc.metadata.hasPendingWrites) {
        data = {...data, 'date': Timestamp.now()};
      }
      try {
        entries.add(JourneyEntry.fromMap(doc.id, data));
      } on FormatException catch (e) {
        debugPrint('Skipping journey entry ${doc.id}: $e');
      }
    }
    return entries..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Live list of the user's plants, sorted by land, then square. Empty when
  /// signed out; it switches over when another user signs in.
  ///
  /// The plants have no journey entries: those live in their own subcollection
  /// (see [watchJourney]).
  Stream<List<FarmPlant>> watchPlants() => _forEachUser(
    signedOut: const [],
    watch: (uid) =>
        _plants(uid).snapshots().map((snapshot) => _readPlants(snapshot.docs)),
  );

  /// Live farm stats. Accounts that haven't saved any yet get the defaults
  /// (1 land, no streak).
  Stream<FarmStats> watchStats() => _forEachUser(
    signedOut: const FarmStats(),
    watch: (uid) => _stats(uid).snapshots().map(_readStats),
  );

  /// A new, unused id for a plant. The Add Plant screen keeps one for all
  /// its tries, so a try that did reach the server isn't added twice.
  String newPlantId() => _plants(_uid).doc().id;

  /// Saves a new plant on the first free square of the user's [lands], and
  /// returns it with its id, land and square. [id] is from [newPlantId];
  /// if a plant with it is already saved (an earlier try that went through
  /// though its answer was lost), that one is returned and nothing changes.
  ///
  /// The squares taken are read from the server, and the plant is saved
  /// there or not at all (see [SaveOnServer.saveOnServer]): offline, this
  /// fails within [serverTimeout] instead of waiting for the connection.
  /// Throws a [FarmFullException] if there is no free square.
  Future<FarmPlant> addPlant(
    FarmPlant plant, {
    required int lands,
    String? id,
  }) async {
    final plants = _plants(_uid);
    final doc = plants.doc(id);
    final current = await withServerTimeout(
      plants.get(const GetOptions(source: Source.server)),
    );
    for (final saved in current.docs) {
      if (saved.id == doc.id) return FarmPlant.fromMap(saved.id, saved.data());
    }
    final spot = firstFreeSpot(_readPlants(current.docs), lands);
    if (spot == null) throw const FarmFullException();

    final placed = plant.placed(
      id: doc.id,
      land: spot.land,
      square: spot.square,
    );
    return _firestore.saveOnServer<FarmPlant>((transaction) async {
      final saved = await transaction.get(doc);
      final data = saved.data();
      if (data != null) return FarmPlant.fromMap(doc.id, data);
      transaction.set(doc, placed.toMap());
      return placed;
    });
  }

  /// Saves the changes made on the Edit Plant screen: in one transaction,
  /// reads the plant as it is saved now and updates only the fields the
  /// user changed (see [PlantEdit.updateOver]). A task done meanwhile
  /// (its `lastDone`, `previousDone` or the other schedule) is never
  /// overwritten with the screen's older copy. If the plant changes before
  /// the transaction ends, Firestore runs it again on the new values.
  ///
  /// The streak is updated in the same transaction when the edit changes
  /// whether today is finished (see [streakAfterScheduleChange]): a task
  /// added to a completed today takes today's +1 back. [plants] are the
  /// user's plants (this one is read fresh).
  ///
  /// Returns the streak that was lost because a day was missed (0 if
  /// none), for Home to tell the user. Throws an [ArgumentError] if the
  /// plant was never saved (no id), and a [StateError] if it no longer
  /// exists.
  Future<int> editPlant(PlantEdit edit, {required List<FarmPlant> plants}) async {
    final id = edit.opened.id;
    if (id == null) {
      throw ArgumentError.value(edit, 'edit', 'The plant has no id.');
    }
    final uid = _uid;
    final plant = _plants(uid).doc(id);
    final stats = _stats(uid);
    return _firestore.saveOnServer<int>((transaction) async {
      final now = DateTime.now();
      final log = _taskLog(uid, TaskLog.dateKey(now));
      final data = (await transaction.get(plant)).data();
      if (data == null) throw StateError('Plant $id no longer exists.');
      final statsSnapshot = await transaction.get(stats);
      final logSnapshot = await transaction.get(log);
      final update = edit.updateOver(data, now, now);
      if (update.isEmpty) return 0;

      final others = [for (final p in plants) if (p.id != id) p];
      final beforePlants = [...others, FarmPlant.fromMap(id, data)];
      final afterPlants = [
        ...others,
        FarmPlant.fromMap(id, PlantEdit.applied(data, update)),
      ];
      final before = _readStats(statsSnapshot);
      final after = streakAfterScheduleChange(
        before,
        before: beforePlants,
        after: afterPlants,
        now: now,
        todayLog: _readLog(log.id, logSnapshot.data()),
      );

      transaction.update(plant, {
        for (final MapEntry(:key, :value) in update.entries)
          key: value is DeleteField ? FieldValue.delete() : value,
      });
      if (after.currentStreak != before.currentStreak ||
          after.lastCompletedDate != before.lastCompletedDate) {
        transaction.set(stats, after.toMap());
      }
      return streakBroken(before, after, beforePlants)
          ? before.currentStreak
          : 0;
    });
  }

  /// Deletes a plant and then its journey entries. Firestore doesn't delete
  /// subcollections by itself.
  ///
  /// The plant is deleted in a transaction that also updates the streak
  /// (see [streakAfterPlantDeleted]): if it had today's last unfinished
  /// task, today is completed. Both happen, or neither (a transaction
  /// needs the server, so offline it fails and nothing changes). [others]
  /// are the user's other plants that stay: not this one, nor ones whose
  /// delete has already succeeded.
  ///
  /// If the connection is lost and it isn't known whether the delete went
  /// through, the server is asked: a plant already gone counts as deleted.
  /// Otherwise the error is thrown, the plant stays, and trying again is
  /// safe (deleting a plant that is already gone changes nothing).
  ///
  /// The journey entries are removed afterwards, without waiting: left
  /// behind, they only take space.
  ///
  /// Returns the streak that was lost because a day was missed (0 if
  /// none), for Home to tell the user.
  Future<int> deletePlant(
    String plantId, {
    List<FarmPlant> others = const [],
  }) async {
    final uid = _uid;
    final plant = _plants(uid).doc(plantId);
    int lost;
    try {
      lost = await _deletePlantAndUpdateStreak(uid, plant, others);
    } catch (e) {
      if (!isNetworkError(e) || !await _goneOnServer(plant)) rethrow;
      lost = 0;
    }
    unawaited(
      _deleteJourney(plant).catchError(
        (Object e) => debugPrint('Journey entries of $plantId kept: $e'),
      ),
    );
    return lost;
  }

  /// True only when the server says [doc] doesn't exist.
  Future<bool> _goneOnServer(DocumentReference<Object?> doc) async {
    try {
      return !(await withServerTimeout(
        doc.get(const GetOptions(source: Source.server)),
      )).exists;
    } catch (_) {
      return false; // Still unknown: report the failure.
    }
  }

  /// Deletes every journey entry of [plant]. A batch can hold at most 500
  /// writes.
  Future<void> _deleteJourney(DocumentReference<Object?> plant) async {
    final journey = await plant.collection('journey').get();
    final refs = [...journey.docs.map((doc) => doc.reference)];
    for (var start = 0; start < refs.length; start += 500) {
      final batch = _firestore.batch();
      for (final ref in refs.skip(start).take(500)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  Future<int> _deletePlantAndUpdateStreak(
    String uid,
    DocumentReference<Map<String, dynamic>> plant,
    List<FarmPlant> others,
  ) {
    final plantId = plant.id;
    final stats = _stats(uid);
    return _firestore.saveOnServer<int>((transaction) async {
      final now = DateTime.now();
      final log = _taskLog(uid, TaskLog.dateKey(now));
      final data = (await transaction.get(plant)).data();
      final statsSnapshot = await transaction.get(stats);
      final logSnapshot = await transaction.get(log);
      transaction.delete(plant);
      if (data == null) return 0; // Already gone: nothing changes today.
      final FarmPlant deleted;
      try {
        deleted = FarmPlant.fromMap(plantId, data);
      } on FormatException {
        return 0; // Unreadable, so it never had tasks on the screens.
      }
      final remaining = [for (final p in others) if (p.id != plantId) p];
      final beforePlants = [...remaining, deleted];
      final before = _readStats(statsSnapshot);
      final after = streakAfterPlantDeleted(
        before,
        before: beforePlants,
        after: remaining,
        now: now,
        todayLog: _readLog(log.id, logSnapshot.data()),
      );
      if (after.currentStreak != before.currentStreak ||
          after.lastCompletedDate != before.lastCompletedDate) {
        transaction.set(stats, after.toMap());
      }
      return streakBroken(before, after, beforePlants)
          ? before.currentStreak
          : 0;
    });
  }

  /// Saves the number of lands. Changes only that field, so the streak in
  /// the same document stays as it is.
  Future<void> saveLands(int lands) async {
    final stats = _stats(_uid);
    await _firestore.saveOnServer<void>((transaction) async {
      final snapshot = await transaction.get(stats);
      if (snapshot.exists) {
        transaction.update(stats, {'lands': lands});
      } else {
        transaction.set(stats, FarmStats(lands: lands).toMap());
      }
    });
  }

  /// Live task log of the day [date] ("yyyy-mm-dd", see [TaskLog.dateKey]).
  /// An empty log when nothing is done yet or when signed out.
  Stream<TaskLog> watchTaskLog(String date) => _forEachUser(
    signedOut: TaskLog(date: date),
    watch: (uid) => _taskLog(uid, date).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return TaskLog(date: date);
      try {
        return TaskLog.fromMap(date, data);
      } on FormatException catch (e) {
        debugPrint('Using an empty task log: $e');
        return TaskLog(date: date);
      }
    }),
  );

  /// The plant's schedule of [type] with its done days changed by [change],
  /// as the fields to update; null when there is nothing to change (no such
  /// plant or schedule any more, or the same done days).
  ///
  /// Only `lastDone`, `previousDone` and, when an un-tick moves it, `since`
  /// are written (as dotted paths), so a name or schedule saved at the same
  /// moment isn't overwritten.
  @visibleForTesting
  static Map<String, Object>? doneDaysUpdate(
    Map<String, dynamic>? plant,
    TaskType type,
    CareSchedule Function(CareSchedule) change,
  ) {
    if (plant == null) return null;
    final field = switch (type) {
      TaskType.watering => 'irrigation',
      TaskType.fertilizing => 'fertilization',
    };
    final CareSchedule? schedule;
    try {
      schedule = CareSchedule.fromMap(plant[field]);
    } on FormatException {
      return null;
    }
    if (schedule == null) return null;
    final changed = change(schedule);
    final sinceChanged = changed.since != schedule.since;
    if (changed.lastDone == schedule.lastDone &&
        changed.previousDone == schedule.previousDone &&
        !sinceChanged) {
      return null;
    }
    return {
      '$field.lastDone': changed.lastDone?.toMap() ?? FieldValue.delete(),
      '$field.previousDone':
          changed.previousDone?.toMap() ?? FieldValue.delete(),
      if (sinceChanged)
        '$field.since': changed.since == null
            ? FieldValue.delete()
            : CareDone.dateKey(changed.since!),
    };
  }

  /// Marks task [taskId] of [today] as done (or not done), and updates the
  /// streak in the same transaction, so the log and the streak always agree.
  /// The plant [plantId]'s schedule of [type] records it too (see
  /// [CareSchedule.markedDone] and [CareSchedule.markedUndone]), so its next
  /// task counts from today, or as before once un-ticked.
  ///
  /// [todayTaskIds] are the ids of every task due today and [plants] the
  /// user's plants; they decide whether the day is complete and whether an
  /// earlier day was missed (see streak.dart).
  ///
  /// Returns the streak that was lost because a day was missed (0 if none),
  /// for Home to tell the user.
  Future<int> setTaskDone({
    required DateTime today,
    required String plantId,
    required TaskType type,
    required String taskId,
    required bool done,
    required List<String> todayTaskIds,
    required List<FarmPlant> plants,
  }) async {
    final uid = _uid;
    final log = _taskLog(uid, TaskLog.dateKey(today));
    final stats = _stats(uid);
    final plant = _plants(uid).doc(plantId);
    return _firestore.saveOnServer<int>((transaction) async {
      final logSnapshot = await transaction.get(log);
      final statsSnapshot = await transaction.get(stats);
      final plantSnapshot = await transaction.get(plant);

      final saved = _readLog(log.id, logSnapshot.data());
      final completed = {...saved.completed};
      done ? completed.add(taskId) : completed.remove(taskId);

      final before = _readStats(statsSnapshot);
      final checked = streakAfterMissedDays(before, plants, today);
      final after = streakAfterToggle(
        checked,
        today: today,
        allDone: todayTaskIds.isNotEmpty && completed.containsAll(todayTaskIds),
        previousTaskDay: previousTaskDay(plants, today),
      );

      final day = DateTime(today.year, today.month, today.day);
      final doneDays = doneDaysUpdate(
        plantSnapshot.data(),
        type,
        (s) => done
            ? s.markedDone(CareDone(date: day, due: day))
            : s.markedUndone(day),
      );

      transaction.set(
        log,
        TaskLog(
          date: log.id,
          completed: [...completed],
          late: saved.late,
          lateOn: saved.lateOn,
        ).toMap(),
      );
      transaction.set(stats, after.toMap());
      if (doneDays != null) transaction.update(plant, doneDays);
      return streakBroken(before, checked, plants) ? before.currentStreak : 0;
    });
  }

  /// Marks task [taskId] of the past day [day] as done late on [doneOn]
  /// (or not done). That day's log keeps it with the day it was really
  /// done, and the plant [plantId]'s schedule of [type] records it, so its
  /// next task counts from [doneOn]. The streak doesn't change: a task done
  /// after its day never adds to it.
  Future<void> setLateTaskDone({
    required DateTime day,
    required DateTime doneOn,
    required String plantId,
    required TaskType type,
    required String taskId,
    required bool done,
  }) async {
    final uid = _uid;
    final log = _taskLog(uid, TaskLog.dateKey(day));
    final plant = _plants(uid).doc(plantId);
    await _firestore.saveOnServer<void>((transaction) async {
      final saved = _readLog(log.id, (await transaction.get(log)).data());
      final plantSnapshot = await transaction.get(plant);
      // Done on time after all (e.g. on another phone): nothing to change.
      if (saved.isCompleted(taskId)) return;
      final late = {...saved.late};
      final lateOn = {...saved.lateOn};
      if (done) {
        late.add(taskId);
        lateOn[taskId] = TaskLog.dateKey(doneOn);
      } else {
        late.remove(taskId);
        lateOn.remove(taskId);
      }
      final doneDays = doneDaysUpdate(
        plantSnapshot.data(),
        type,
        (s) => done
            ? s.markedDone(CareDone(date: doneOn, due: day))
            : s.markedUndone(day),
      );
      transaction.set(
        log,
        TaskLog(
          date: log.id,
          completed: saved.completed,
          late: [...late],
          lateOn: lateOn,
        ).toMap(),
      );
      if (doneDays != null) transaction.update(plant, doneDays);
    });
  }

  /// Resets the streak to 0 if a day with tasks was missed, or if the user
  /// has no plants. Call when the app opens or comes back on a new day.
  ///
  /// Returns the streak that was lost because a day was missed (0 if none).
  /// The reset happens once, so this reports a lost streak only once.
  Future<int> checkStreak(DateTime today) async {
    final uid = _uid;
    final plants = _readPlants((await _plants(uid).get()).docs);
    final stats = _stats(uid);
    return _firestore.saveOnServer<int>((transaction) async {
      final before = _readStats(await transaction.get(stats));
      final after = streakAfterMissedDays(before, plants, today);
      if (after.currentStreak == before.currentStreak) return 0;
      transaction.set(stats, after.toMap());
      return streakBroken(before, after, plants) ? before.currentStreak : 0;
    });
  }

  /// The saved log of day [date], or an empty one (also when it's bad).
  TaskLog _readLog(String date, Map<String, dynamic>? data) {
    if (data == null) return TaskLog(date: date);
    try {
      return TaskLog.fromMap(date, data);
    } on FormatException catch (e) {
      debugPrint('Starting the task log of $date again: $e');
      return TaskLog(date: date);
    }
  }

  /// The saved stats, or the defaults when there are none (or they're bad).
  FarmStats _readStats(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) return const FarmStats();
    try {
      return FarmStats.fromMap(data);
    } on FormatException catch (e) {
      debugPrint('Using default farm stats: $e');
      return const FarmStats();
    }
  }

  /// Builds the plants from their documents. One bad document is skipped, so
  /// it can't take the whole farm down with it.
  List<FarmPlant> _readPlants(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final plants = <FarmPlant>[];
    for (final doc in docs) {
      try {
        final plant = FarmPlant.fromMap(doc.id, doc.data());
        if (isOnFarm(plant)) {
          plants.add(plant);
        } else {
          debugPrint('Skipping plant ${doc.id}: its spot is off the farm.');
        }
      } on FormatException catch (e) {
        debugPrint('Skipping plant ${doc.id}: $e');
      }
    }
    return inFarmOrder(plants);
  }

  /// Runs [watch] for whoever is signed in, starting over when that changes,
  /// so one user never sees another user's data.
  Stream<T> _forEachUser<T>({
    required T signedOut,
    required Stream<T> Function(String uid) watch,
  }) {
    late final StreamController<T> controller;
    StreamSubscription<User?>? authChanges;
    StreamSubscription<T>? userData;

    controller = StreamController<T>(
      onListen: () {
        authChanges = _auth.authStateChanges().listen((user) {
          userData?.cancel();
          userData = null;
          if (user == null) {
            controller.add(signedOut);
          } else {
            userData = watch(
              user.uid,
            ).listen(controller.add, onError: controller.addError);
          }
        }, onError: controller.addError);
      },
      onCancel: () async {
        await userData?.cancel();
        await authChanges?.cancel();
      },
    );
    return controller.stream;
  }
}
