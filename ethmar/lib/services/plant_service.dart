import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/farm_plant.dart';
import '../models/farm_spot.dart';
import '../models/farm_stats.dart';
import '../models/streak.dart';
import '../models/task_log.dart';

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

  /// Live list of the user's plants, sorted by land, then square. Empty when
  /// signed out; it switches over when another user signs in.
  ///
  /// The plants have no growth entries: those live in their own subcollection.
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

  /// Saves a new plant on the first free square of the user's [lands], and
  /// returns it with its id, land and square.
  /// Throws a [FarmFullException] if there is no free square.
  Future<FarmPlant> addPlant(FarmPlant plant, {required int lands}) async {
    final plants = _plants(_uid);
    final current = await plants.get();
    final spot = firstFreeSpot(_readPlants(current.docs), lands);
    if (spot == null) throw const FarmFullException();

    final doc = plants.doc();
    final saved = plant.placed(
      id: doc.id,
      land: spot.land,
      square: spot.square,
    );
    await doc.set(saved.toMap());
    return saved;
  }

  /// Saves the plant's fields over its document.
  /// Throws an [ArgumentError] if it has never been saved (no id).
  Future<void> updatePlant(FarmPlant plant) async {
    final id = plant.id;
    if (id == null) {
      throw ArgumentError.value(plant, 'plant', 'The plant has no id.');
    }
    await _plants(_uid).doc(id).set(plant.toMap());
  }

  /// Deletes a plant and all its growth entries. Firestore doesn't delete
  /// subcollections by itself.
  Future<void> deletePlant(String plantId) async {
    final plant = _plants(_uid).doc(plantId);
    final growth = await plant.collection('growth').get();

    // A batch can hold at most 500 writes. The plant goes last, so if a
    // batch fails it still exists and deleting it can be tried again.
    final refs = [...growth.docs.map((doc) => doc.reference), plant];
    for (var start = 0; start < refs.length; start += 500) {
      final batch = _firestore.batch();
      for (final ref in refs.skip(start).take(500)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  /// Saves the number of lands. Changes only that field, so the streak in
  /// the same document stays as it is.
  Future<void> saveLands(int lands) async {
    final stats = _stats(_uid);
    await _firestore.runTransaction<void>((transaction) async {
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

  /// Marks task [taskId] of [today] as done (or not done), and updates the
  /// streak in the same transaction, so the log and the streak always agree.
  ///
  /// [todayTaskIds] are the ids of every task due today and [plants] the
  /// user's plants; they decide whether the day is complete and whether an
  /// earlier day was missed (see streak.dart).
  Future<void> setTaskDone({
    required DateTime today,
    required String taskId,
    required bool done,
    required List<String> todayTaskIds,
    required List<FarmPlant> plants,
  }) async {
    final uid = _uid;
    final log = _taskLog(uid, TaskLog.dateKey(today));
    final stats = _stats(uid);
    await _firestore.runTransaction<void>((transaction) async {
      final logSnapshot = await transaction.get(log);
      final statsSnapshot = await transaction.get(stats);

      final completed = <String>{};
      final logData = logSnapshot.data();
      if (logData != null) {
        try {
          completed.addAll(TaskLog.fromMap(log.id, logData).completed);
        } on FormatException catch (e) {
          debugPrint('Starting today\'s task log again: $e');
        }
      }
      done ? completed.add(taskId) : completed.remove(taskId);

      final before = _readStats(statsSnapshot);
      final after = streakAfterToggle(
        streakAfterMissedDays(before, plants, today),
        today: today,
        allDone: todayTaskIds.isNotEmpty && completed.containsAll(todayTaskIds),
        previousTaskDay: previousTaskDay(plants, today),
      );

      transaction.set(log, TaskLog(date: log.id, completed: [...completed]).toMap());
      transaction.set(stats, after.toMap());
    });
  }

  /// Resets the streak to 0 if a day with tasks was missed, or if the user
  /// has no plants. Call when the app opens or comes back on a new day.
  Future<void> checkStreak(DateTime today) async {
    final uid = _uid;
    final plants = _readPlants((await _plants(uid).get()).docs);
    final stats = _stats(uid);
    await _firestore.runTransaction<void>((transaction) async {
      final before = _readStats(await transaction.get(stats));
      final after = streakAfterMissedDays(before, plants, today);
      if (after.currentStreak != before.currentStreak) {
        transaction.set(stats, after.toMap());
      }
    });
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
