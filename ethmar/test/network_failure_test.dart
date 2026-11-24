// Saving while the connection fails: editing a plant, deleting one or
// several, and ticking tasks. Firebase isn't used: FarmStore's test hooks
// stand in for the saves, failing with the errors Firestore gives when the
// server can't be reached. The batch deletes are checked against a
// simulated server that applies the app's own streak rule.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:ethmar/models/crop_catalog.dart';
import 'package:ethmar/models/daily_task.dart';
import 'package:ethmar/models/farm_plant.dart';
import 'package:ethmar/models/farm_stats.dart';
import 'package:ethmar/models/plant_edit.dart';
import 'package:ethmar/models/streak.dart';
import 'package:ethmar/models/task_log.dart';
import 'package:ethmar/screens/daily_tasks_screen.dart';
import 'package:ethmar/screens/edit_plant_screen.dart';
import 'package:ethmar/services/farm_store.dart';
import 'package:ethmar/services/network_errors.dart';
import 'package:ethmar/widgets/ethmar_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const at8 = TimeOfDay(hour: 8, minute: 0);

FirebaseException offline() =>
    FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
FirebaseException timedOut() =>
    FirebaseException(plugin: 'cloud_firestore', code: 'deadline-exceeded');

DateTime dayOnly(DateTime t) => DateTime(t.year, t.month, t.day);

FarmPlant plant(String id, {CareSchedule? water, String name = 'Mint'}) =>
    FarmPlant(
      id: id,
      crop: cropCatalog.first,
      name: name,
      irrigation: water,
      plantedAt: DateTime(2026, 11, 1),
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    );

CareDone done(DateTime on) => CareDone(date: on, due: on);

DateTime nov(int day) => DateTime(2026, 11, day);

/// The server's side of a batch delete: the plants and the streak. A delete
/// that fails changes nothing; one that works deletes the plant and applies
/// the streak rule with the plants the app says stay.
class Server {
  Server(this.plants, this.stats, {this.failing = const {}});

  List<FarmPlant> plants;
  FarmStats stats;
  final Set<String> failing;
  final now = DateTime(2026, 11, 22, 9);
  final tried = <String>[];

  /// Today's log: a was ticked today.
  late final TaskLog log =
      TaskLog(date: TaskLog.dateKey(now), completed: ['a_irrigation']);

  /// [deleted] as FarmStore passes it: the ids already deleted.
  Future<void> delete(String id, Set<String> deleted) async {
    tried.add(id);
    if (failing.contains(id)) throw offline();
    final gone = plants.firstWhere((p) => p.id == id);
    // What FarmStore sends: its plants, without this one or deleted ones.
    final others = [
      for (final p in plants)
        if (p.id != id && !deleted.contains(p.id)) p,
    ];
    stats = streakAfterPlantDeleted(stats,
        before: [...others, gone], after: others, now: now, todayLog: log);
    plants = [for (final p in plants) if (p.id != id) p];
  }

  List<DailyTask> get today => tasksForDay(plants, now, {log.date: log}, now);
}

/// Nov 22. a: done today. b, c: due today, not done. z: nothing today.
/// A 5-day streak up to Nov 21.
Server server({Set<String> failing = const {}}) => Server([
  plant('a', water: CareSchedule(Repeat.everyDay, at8,
      since: nov(1), lastDone: done(nov(22)))),
  plant('b', water: CareSchedule(Repeat.everyDay, at8,
      since: nov(1), lastDone: done(nov(21)))),
  plant('c', water: CareSchedule(Repeat.everyDay, at8,
      since: nov(1), lastDone: done(nov(21)))),
  plant('z', water: CareSchedule(Repeat.every2Weeks, at8,
      since: nov(1), lastDone: done(nov(20)))),
], const FarmStats(currentStreak: 5, lastCompletedDate: '2026-11-21', lands: 1),
    failing: failing);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('connection errors are told apart from other failures', () {
    expect(isNetworkError(offline()), isTrue);
    expect(isNetworkError(timedOut()), isTrue);
    expect(isNetworkError(TimeoutException('slow')), isTrue);
    expect(isNetworkError(FirebaseException(
        plugin: 'cloud_firestore', code: 'permission-denied')), isFalse);
    expect(isNetworkError(StateError('gone')), isFalse);
  });

  group('deleting several plants', () {
    test('B1. all succeed: today completes once', () {
      final s = server();
      expect(s.today.where((t) => !t.done), hasLength(2));
      return deletePlantsInTurn(['b', 'c'], s.delete).then((failed) {
        expect(failed, isEmpty);
        expect(s.stats.currentStreak, 6);
        expect(s.stats.lastCompletedDate, '2026-11-22');
        expect(s.today.every((t) => t.done), isTrue);
      });
    });

    test('B2. one fails: no streak, it and its task stay', () async {
      for (final order in [['b', 'c'], ['c', 'b']]) {
        final s = server(failing: {'b'});
        final failed = await deletePlantsInTurn(order, s.delete);
        expect(failed.keys, ['b']);
        expect(isNetworkError(failed['b']!), isTrue);
        expect(s.stats.currentStreak, 5, reason: '$order');
        expect(s.plants.map((p) => p.id), contains('b'));
        expect(s.today.where((t) => !t.done).single.plantId, 'b');
      }
    });

    test('B3. the failed one had nothing to do: today still completes', () async {
      final s = server(failing: {'z'});
      final failed = await deletePlantsInTurn(['z', 'b', 'c'], s.delete);
      expect(failed.keys, ['z']);
      expect(s.stats.currentStreak, 6);
    });

    test('B4. every task gone: no streak for an empty day', () async {
      final s = server();
      await deletePlantsInTurn(['a', 'b', 'c', 'z'], s.delete);
      expect(s.today, isEmpty);
      expect(s.stats.currentStreak, 5);
    });

    test('B5. a done plant deleted too: its task never counts, +1 once',
        () async {
      // a's task was done; deleting it leaves b and c to do: nothing.
      final s = server();
      await deletePlantsInTurn(['a'], s.delete);
      expect(s.stats.currentStreak, 5);
      // Deleting b and c too leaves no task at all: an empty day isn't
      // completed, so a's done task never earns it.
      await deletePlantsInTurn(['b', 'c'], s.delete);
      expect(s.today, isEmpty);
      expect(s.stats.currentStreak, 5);
      // With a kept: deleting b and c completes today, once.
      final t = server();
      await deletePlantsInTurn(['b', 'c'], t.delete);
      expect(t.stats.currentStreak, 6);
      await deletePlantsInTurn(['z'], t.delete);
      expect(t.stats.currentStreak, 6);
    });

    test('B6. each plant is tried once, even if asked twice', () async {
      final s = server(failing: {'b'});
      await deletePlantsInTurn(['b', 'c', 'b', 'c'], s.delete);
      expect(s.tried, ['b', 'c']);
    });

    test('B7. retrying after a failure completes today, once', () async {
      final s = server(failing: {'b'});
      await deletePlantsInTurn(['b', 'c'], s.delete);
      expect(s.stats.currentStreak, 5);
      s.failing.clear();
      final failed = await deletePlantsInTurn(['b'], s.delete);
      expect(failed, isEmpty);
      expect(s.stats.currentStreak, 6);
    });
  });

  group('FarmStore.deletePlant', () {
    tearDown(() => FarmStore.deleteForTests = null);

    test('D1. a second request while one runs joins it', () async {
      var calls = 0;
      final gate = Completer<void>();
      FarmStore.deleteForTests = (_) {
        calls++;
        return gate.future;
      };
      final first = FarmStore.deletePlant('p');
      final second = FarmStore.deletePlant('p');
      gate.complete();
      await Future.wait([first, second]);
      expect(calls, 1);
    });

    test('D2. a failure is thrown, and trying again runs again', () async {
      var calls = 0;
      FarmStore.deleteForTests = (_) async {
        calls++;
        if (calls == 1) throw offline();
      };
      await expectLater(FarmStore.deletePlant('p'), throwsA(isA<FirebaseException>()));
      await FarmStore.deletePlant('p');
      expect(calls, 2);
    });
  });

  test('a retried edit or tick writes nothing twice', () {
    // An edit that did reach the server: saving it again changes nothing.
    final opened = plant('p', water: CareSchedule(Repeat.everyWeek, at8,
        since: nov(1), lastDone: done(nov(20))));
    final edit = PlantEdit(
      opened: opened,
      name: 'New name',
      irrigation: const CareSchedule(Repeat.every3Days, TimeOfDay(hour: 18, minute: 0)),
      fertilization: null,
    );
    final data = opened.toMap();
    final saved = PlantEdit.applied(data, edit.updateOver(data, nov(22), nov(22)));
    expect(edit.updateOver(saved, nov(22), nov(22)), isEmpty);
    // A tick saved twice: the same done day, the same streak.
    final s = opened.irrigation!.markedDone(done(nov(22)));
    expect(s.markedDone(done(nov(22))).previousDone, s.previousDone);
    const stats = FarmStats(currentStreak: 3, lastCompletedDate: '2026-11-21', lands: 1);
    final once = streakAfterToggle(stats,
        today: nov(22), allDone: true, previousTaskDay: nov(21));
    final twice = streakAfterToggle(once,
        today: nov(22), allDone: true, previousTaskDay: nov(21));
    expect(twice.currentStreak, once.currentStreak);
  });

  group('Edit Plant', () {
    late List<PlantEdit> saves;
    late Future<void> Function(PlantEdit) answer;

    setUp(() {
      saves = [];
      answer = (_) async {};
      FarmStore.editForTests = (edit) {
        saves.add(edit);
        return answer(edit);
      };
      FarmStore.plants.value = [
        plant('p', name: 'Mint',
            water: CareSchedule(Repeat.everyWeek, at8, since: nov(1))),
      ];
    });

    tearDown(() {
      FarmStore.editForTests = null;
      FarmStore.plants.value = const [];
    });

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: Text('Home screen'))));
      tester.state<NavigatorState>(find.byType(Navigator)).push(
          MaterialPageRoute<void>(
              builder: (_) => const EditPlantScreen(plantId: 'p')));
      await settle(tester);
      await tester.enterText(find.byType(EditableText), 'Garden mint');
      await settle(tester);
    }

    Future<void> save(WidgetTester tester) async {
      await tester.tap(find.text('Save'));
      await settle(tester);
    }

    const networkMessage =
        "Couldn't save changes. Check your internet connection and try again.";

    testWidgets('E1. offline: stays open, keeps the form, says why', (tester) async {
      answer = (_) async => throw offline();
      await open(tester);
      await save(tester);
      expect(find.byType(EditPlantScreen), findsOneWidget);
      expect(find.text('Garden mint'), findsOneWidget);
      expect(find.text(networkMessage), findsOneWidget);
      expect(find.text('Home screen'), findsNothing);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('E2. connection lost while saving: one save, then the error',
        (tester) async {
      final gate = Completer<void>();
      answer = (_) => gate.future;
      await open(tester);
      await save(tester);
      // Still saving (the button shows a spinner): tapping again sends
      // nothing more.
      expect(find.text('Save'), findsNothing);
      await tester.tap(find.byType(EthmarButton), warnIfMissed: false);
      await tester.tap(find.byType(EthmarButton), warnIfMissed: false);
      await settle(tester);
      expect(saves, hasLength(1));
      gate.completeError(timedOut());
      await settle(tester);
      expect(find.byType(EditPlantScreen), findsOneWidget);
      expect(find.text('Garden mint'), findsOneWidget);
      expect(find.text(networkMessage), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('E3. trying again with the same values, then it closes',
        (tester) async {
      var attempt = 0;
      answer = (_) async {
        if (++attempt == 1) throw offline();
      };
      await open(tester);
      await save(tester);
      expect(find.byType(EditPlantScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      await save(tester);
      expect(saves, hasLength(2));
      expect(saves.last.name, 'Garden mint');
      expect(saves.last.irrigation!.repeat, Repeat.everyWeek);
      expect(find.byType(EditPlantScreen), findsNothing);
      expect(find.text('Home screen'), findsOneWidget);
    });

    testWidgets('E4. another failure doesn\'t blame the connection',
        (tester) async {
      answer = (_) async => throw StateError('Plant p no longer exists.');
      await open(tester);
      await save(tester);
      expect(find.text("Couldn't save changes. Please try again."),
          findsOneWidget);
      expect(find.text(networkMessage), findsNothing);
      expect(find.byType(EditPlantScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });
  });

  group('Daily Tasks', () {
    final today = dayOnly(DateTime.now());
    final todayKey = TaskLog.dateKey(today);
    final twoDaysAgo = DateTime(today.year, today.month, today.day - 2);
    final missedKey = TaskLog.dateKey(twoDaysAgo);

    late List<(String, bool, bool)> calls;
    late Future<void> Function(String id, bool done, bool late) answer;
    late Map<String, StreamController<TaskLog>> logs;

    setUp(() {
      calls = [];
      answer = (id, done, late) async {};
      logs = {};
      FarmStore.taskLogForTests = (date) {
        final controller = logs[date] = StreamController<TaskLog>();
        controller.add(TaskLog(date: date));
        return controller.stream;
      };
      FarmStore.taskForTests = (id, {required done, required late}) {
        calls.add((id, done, late));
        return answer(id, done, late);
      };
      FarmStore.plants.value = [
        // Due today.
        plant('p', water: CareSchedule(Repeat.everyDay, at8, since: today)),
        // Never done since two days ago: missed.
        plant('m', name: 'Basil',
            water: CareSchedule(Repeat.everyDay, at8, since: twoDaysAgo)),
      ];
    });

    tearDown(() {
      for (final c in logs.values) {
        c.close();
      }
      FarmStore.taskLogForTests = null;
      FarmStore.taskForTests = null;
      FarmStore.plants.value = const [];
    });

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: DailyTasksScreen()));
      await settle(tester);
    }

    Finder box(String key) => find.descendant(
        of: find.byKey(ValueKey(key)), matching: find.byType(Checkbox));
    bool ticked(WidgetTester tester, String key) =>
        tester.widget<Checkbox>(box(key)).value ?? false;

    final todayTask = '$todayKey/p_irrigation';
    final missedTask = '$missedKey/m_irrigation';
    const networkMessage =
        "Couldn't save the task. Check your connection and try again";

    testWidgets('T1. a tick that fails is taken back, and says why',
        (tester) async {
      answer = (_, _, _) async => throw offline();
      await open(tester);
      expect(ticked(tester, todayTask), isFalse);
      await tester.tap(box(todayTask));
      await settle(tester);
      expect(calls, [('p_irrigation', true, false)]);
      expect(ticked(tester, todayTask), isFalse);
      expect(find.text(networkMessage), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('T2. while it saves, more taps send nothing', (tester) async {
      final gate = Completer<void>();
      answer = (_, _, _) => gate.future;
      await open(tester);
      await tester.tap(box(todayTask));
      await tester.pump();
      // Shown as done while it saves.
      expect(ticked(tester, todayTask), isTrue);
      await tester.tap(box(todayTask));
      await tester.tap(box(todayTask));
      await settle(tester);
      expect(calls, hasLength(1));
      gate.completeError(timedOut());
      await settle(tester);
      expect(ticked(tester, todayTask), isFalse);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('T3. trying again after a failure saves it once',
        (tester) async {
      var attempt = 0;
      answer = (id, done, late) async {
        if (++attempt == 1) throw offline();
        // Saved: the log now has it.
        logs[todayKey]!.add(TaskLog(date: todayKey, completed: [id]));
      };
      await open(tester);
      await tester.tap(box(todayTask));
      await settle(tester);
      expect(ticked(tester, todayTask), isFalse);
      await tester.pump(const Duration(seconds: 10));
      await tester.tap(box(todayTask));
      await settle(tester);
      expect(ticked(tester, todayTask), isTrue);
      expect(calls, [
        ('p_irrigation', true, false),
        ('p_irrigation', true, false),
      ]);
    });

    testWidgets('T4. an undo that fails leaves it done', (tester) async {
      answer = (_, _, _) async => throw offline();
      await open(tester);
      logs[todayKey]!.add(TaskLog(date: todayKey, completed: ['p_irrigation']));
      await settle(tester);
      expect(ticked(tester, todayTask), isTrue);
      await tester.tap(box(todayTask));
      await settle(tester);
      expect(calls, [('p_irrigation', false, false)]);
      expect(ticked(tester, todayTask), isTrue);
      expect(find.text(networkMessage), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('T5. a late tick that fails stays missed', (tester) async {
      answer = (_, _, _) async => throw offline();
      await open(tester);
      expect(ticked(tester, missedTask), isFalse);
      await tester.tap(box(missedTask));
      await settle(tester);
      expect(calls, [('m_irrigation', true, true)]);
      expect(ticked(tester, missedTask), isFalse);
      expect(find.text(networkMessage), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('T6. another failure doesn\'t blame the connection',
        (tester) async {
      answer = (_, _, _) async => throw StateError('refused');
      await open(tester);
      await tester.tap(box(todayTask));
      await settle(tester);
      expect(find.text("Couldn't save the task. Please try again"),
          findsOneWidget);
      expect(find.text(networkMessage), findsNothing);
      await tester.pump(const Duration(seconds: 10));
    });
  });
}
