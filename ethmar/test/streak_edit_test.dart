// The streak when care schedules are edited during a day.
//
// A day of one user, without Firestore: each step does what the app's
// service does, with the same functions (see PlantService): ticking
// today's task (setTaskDone), ticking a missed one late (setLateTaskDone:
// the streak doesn't change), editing a plant (editPlant) and opening the
// app (checkStreak).
import 'package:ethmar/models/crop_catalog.dart';
import 'package:ethmar/models/daily_task.dart';
import 'package:ethmar/models/farm_plant.dart';
import 'package:ethmar/models/farm_stats.dart';
import 'package:ethmar/models/plant_edit.dart';
import 'package:ethmar/models/streak.dart';
import 'package:ethmar/models/task_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const at8 = TimeOfDay(hour: 8, minute: 0);
const at18 = TimeOfDay(hour: 18, minute: 0);

DateTime nov(int day) => DateTime(2026, 11, day);
CareDone done(DateTime on, [DateTime? due]) =>
    CareDone(date: on, due: due ?? on);

FarmPlant plant(String id, {CareSchedule? water, CareSchedule? fertilize}) =>
    FarmPlant(
      id: id,
      crop: cropCatalog.first,
      name: id,
      irrigation: water,
      fertilization: fertilize,
      plantedAt: nov(1),
      createdAt: nov(1),
      updatedAt: nov(1),
    );

/// One user's plants, task logs and streak.
class Farm {
  Farm(this.plants, this.stats);

  List<FarmPlant> plants;
  FarmStats stats;
  final logs = <String, TaskLog>{};

  /// Set when an edit or tick reported a lost streak.
  int lost = 0;

  DateTime now = DateTime(2026, 11, 22, 9);
  DateTime get today => DateTime(now.year, now.month, now.day);

  TaskLog get todayLog =>
      logs[TaskLog.dateKey(today)] ?? TaskLog(date: TaskLog.dateKey(today));

  /// Daily Tasks and Home's card: the same list.
  List<DailyTask> get tasks => tasksForDay(plants, today, logs, now);
  String get count => '${tasks.where((t) => t.done).length}/${tasks.length}';

  FarmPlant byId(String id) => plants.firstWhere((p) => p.id == id);

  void _replace(FarmPlant p) =>
      plants = [for (final q in plants) q.id == p.id ? p : q];

  FarmPlant _withSchedule(FarmPlant p, TaskType type, CareSchedule s) =>
      FarmPlant.fromMap(p.id!, {
        ...p.toMap(),
        type == TaskType.watering ? 'irrigation' : 'fertilization': s.toMap(),
      });

  /// Ticks (or un-ticks) today's task, as PlantService.setTaskDone.
  void tick(String id, TaskType type, {bool isDone = true}) {
    final taskId =
        '${id}_${type == TaskType.watering ? 'irrigation' : 'fertilization'}';
    final todayIds = [for (final t in tasks) t.id];
    final completed = {...todayLog.completed};
    isDone ? completed.add(taskId) : completed.remove(taskId);
    final checked = streakAfterMissedDays(stats, plants, today);
    final after = streakAfterToggle(
      checked,
      today: today,
      allDone: todayIds.isNotEmpty && completed.containsAll(todayIds),
      previousTaskDay: previousTaskDay(plants, today),
    );
    if (streakBroken(stats, checked, plants)) lost = stats.currentStreak;
    stats = after;
    logs[todayLog.date] = TaskLog(
      date: todayLog.date,
      completed: [...completed],
      late: todayLog.late,
    );
    final p = byId(id);
    final s = p.scheduleOf(type)!;
    _replace(
      _withSchedule(
        p,
        type,
        isDone ? s.markedDone(done(today)) : s.markedUndone(today),
      ),
    );
  }

  /// Ticks a missed task of [due] late, today, as setLateTaskDone: the
  /// streak isn't touched.
  void tickLate(String id, TaskType type, DateTime due) {
    final key = TaskLog.dateKey(due);
    final log = logs[key] ?? TaskLog(date: key);
    final taskId =
        '${id}_${type == TaskType.watering ? 'irrigation' : 'fertilization'}';
    logs[key] = TaskLog(
      date: key,
      completed: log.completed,
      late: [...log.late, taskId],
      lateOn: {...log.lateOn, taskId: TaskLog.dateKey(today)},
    );
    final p = byId(id);
    _replace(
      _withSchedule(p, type, p.scheduleOf(type)!.markedDone(done(today, due))),
    );
  }

  /// Saves the Edit Plant form of [id], as PlantService.editPlant.
  void edit(String id, {CareSchedule? water, CareSchedule? fertilize}) {
    final opened = byId(id);
    CareSchedule? form(CareSchedule? s) =>
        s == null ? null : CareSchedule(s.repeat, s.time);
    final edit = PlantEdit(
      opened: opened,
      name: opened.name,
      irrigation: water ?? form(opened.irrigation),
      fertilization: fertilize ?? form(opened.fertilization),
    );
    final data = opened.toMap();
    final update = edit.updateOver(data, now, now);
    if (update.isEmpty) return;
    final before = plants;
    _replace(FarmPlant.fromMap(id, PlantEdit.applied(data, update)));
    final after = streakAfterScheduleChange(
      stats,
      before: before,
      after: plants,
      now: now,
      todayLog: todayLog,
    );
    if (streakBroken(stats, after, before)) lost = stats.currentStreak;
    stats = after;
  }

  /// Deletes plants [ids] at once (My Plants' multi-select), as
  /// FarmStore.deletePlant and PlantService.deletePlant: each delete
  /// counts the others being deleted as gone. They finish in [ids] order.
  void delete(List<String> ids) {
    var deleting = {...ids};
    for (final id in ids) {
      final deleted = byId(id);
      final others = [
        for (final p in plants)
          if (!deleting.contains(p.id) || p.id == id) p,
      ];
      final remaining = [
        for (final p in others)
          if (p.id != id) p,
      ];
      final after = streakAfterPlantDeleted(
        stats,
        before: [...remaining, deleted],
        after: remaining,
        now: now,
        todayLog: todayLog,
      );
      if (streakBroken(stats, after, [...remaining, deleted])) {
        lost = stats.currentStreak;
      }
      stats = after;
      plants = [
        for (final p in plants)
          if (p.id != id) p,
      ];
      deleting = {...deleting}..remove(id);
    }
  }

  /// The app opens at [at], as PlantService.checkStreak.
  void open(DateTime at) {
    now = at;
    final after = streakAfterMissedDays(stats, plants, today);
    if (streakBroken(stats, after, plants)) lost = stats.currentStreak;
    stats = after;
  }

  /// A restart: everything read back from what was saved.
  void restart() {
    plants = [for (final p in plants) FarmPlant.fromMap(p.id!, p.toMap())];
    stats = FarmStats.fromMap(stats.toMap());
  }
}

/// Nov 22, 09:00. Due today: a's watering and fertilizing, b's watering
/// (daily, done yesterday) and d's (every 2 days, done Nov 20). c waters
/// every 14 days, last done Nov 10: next Nov 24. A 5-day streak up to
/// Nov 21.
Farm farm() => Farm(
  [
    plant(
      'a',
      water: CareSchedule(
        Repeat.everyDay,
        at8,
        since: nov(1),
        lastDone: done(nov(21)),
      ),
      fertilize: CareSchedule(
        Repeat.every3Days,
        at8,
        since: nov(1),
        lastDone: done(nov(19)),
      ),
    ),
    plant(
      'b',
      water: CareSchedule(
        Repeat.everyDay,
        at8,
        since: nov(1),
        lastDone: done(nov(21)),
      ),
    ),
    plant(
      'c',
      water: CareSchedule(
        Repeat.every2Weeks,
        at8,
        since: nov(1),
        lastDone: done(nov(10)),
      ),
    ),
    plant(
      'd',
      water: CareSchedule(
        Repeat.every2Days,
        at8,
        since: nov(1),
        lastDone: done(nov(20)),
      ),
    ),
  ],
  const FarmStats(currentStreak: 5, lastCompletedDate: '2026-11-21', lands: 1),
);

const water = TaskType.watering;
const fertilize = TaskType.fertilizing;

void doAll(Farm f) {
  for (final (id, type) in [
    ('a', water),
    ('a', fertilize),
    ('b', water),
    ('d', water),
  ]) {
    f.tick(id, type);
  }
}

void main() {
  test('setup: 4 tasks today, completing them all gives +1', () {
    final f = farm();
    expect(f.count, '0/4');
    doAll(f);
    expect(f.count, '4/4');
    expect(f.stats.currentStreak, 6);
    expect(f.stats.lastCompletedDate, '2026-11-22');
  });

  test('1. all done, then an edit adds a task today: today\'s +1 is taken '
      'back', () {
    final f = farm();
    doAll(f);
    // Every 7 days from Nov 10: Nov 17 has passed, so due today.
    f.edit('c', water: CareSchedule(Repeat.everyWeek, at8));
    expect(f.count, '4/5');
    expect(f.stats.currentStreak, 5);
    expect(f.stats.lastCompletedDate, '2026-11-21');
    expect(f.lost, 0);
  });

  test('2. the new task done: today counts again, once', () {
    final f = farm();
    doAll(f);
    f.edit('c', water: CareSchedule(Repeat.everyWeek, at8));
    f.tick('c', water);
    expect(f.count, '5/5');
    expect(f.stats.currentStreak, 6);
    // Un-ticking and ticking again doesn't add more.
    f.tick('c', water, isDone: false);
    expect(f.stats.currentStreak, 5);
    f.tick('c', water);
    f.tick('c', water);
    expect(f.stats.currentStreak, 6);
  });

  test('3. the new task left undone: the streak breaks the next day', () {
    final f = farm();
    doAll(f);
    f.edit('c', water: CareSchedule(Repeat.everyWeek, at8));
    f.open(DateTime(2026, 11, 23, 9));
    expect(f.stats.currentStreak, 0);
    expect(f.lost, 5);
  });

  test('3b. (the bug) without taking it back, it was never broken', () {
    // What happened before the fix: today stayed the last completed day,
    // and the next day's check starts after it.
    final f = farm();
    doAll(f);
    final kept = f.stats;
    f.edit('c', water: CareSchedule(Repeat.everyWeek, at8));
    expect(streakAfterMissedDays(kept, f.plants, nov(23)).currentStreak, 6);
  });

  test('4. an edit removes today\'s last unfinished task: today completes, '
      'once', () {
    final f = farm();
    f.tick('a', water);
    f.tick('a', fertilize);
    f.tick('b', water);
    expect(f.count, '3/4');
    expect(f.stats.currentStreak, 5);
    // d every 14 days from Nov 20: Dec 4, nothing today.
    f.edit('d', water: CareSchedule(Repeat.every2Weeks, at8));
    expect(f.count, '3/3');
    expect(f.stats.currentStreak, 6);
    expect(f.stats.lastCompletedDate, '2026-11-22');
    f.open(DateTime(2026, 11, 23, 9));
    expect(f.stats.currentStreak, 6);
  });

  test('5. a missed task done late after today is complete: no change', () {
    final f = farm();
    f.plants = [
      ...f.plants,
      // Every 7 days, done Nov 13: Nov 20 is missed.
      plant(
        'e',
        water: CareSchedule(
          Repeat.everyWeek,
          at8,
          since: nov(1),
          lastDone: done(nov(13)),
        ),
      ),
    ];
    doAll(f);
    expect(f.count, '4/4');
    final before = f.stats;
    f.tickLate('e', water, nov(20));
    expect(f.stats, same(before));
    expect(f.count, '4/4');
    expect(f.stats.currentStreak, 6);
  });

  test('6. yesterday\'s missed task done today gives nothing back', () {
    // Yesterday (Nov 21) b's watering wasn't done: the streak is lost.
    final f = farm();
    f.plants = [
      for (final p in f.plants)
        p.id == 'b'
            ? plant(
                'b',
                water: CareSchedule(
                  Repeat.everyDay,
                  at8,
                  since: nov(1),
                  lastDone: done(nov(20)),
                ),
              )
            : p,
    ];
    f.stats = const FarmStats(
      currentStreak: 5,
      lastCompletedDate: '2026-11-20',
      lands: 1,
    );
    f.open(DateTime(2026, 11, 22, 9));
    expect(f.stats.currentStreak, 0);
    f.tickLate('b', water, nov(21));
    expect(f.stats.currentStreak, 0);
    // Today's own tasks then start a new streak of 1, not 6.
    for (final t in [...f.tasks]) {
      f.tick(t.plantId, t.type);
    }
    expect(f.stats.currentStreak, 1);
  });

  test('7. a new time after today is complete changes nothing', () {
    final f = farm();
    doAll(f);
    final before = f.stats;
    for (final id in ['a', 'b', 'c', 'd']) {
      final s = f.byId(id).irrigation!;
      f.edit(id, water: CareSchedule(s.repeat, at18));
    }
    f.edit('a', fertilize: CareSchedule(Repeat.every3Days, at18));
    expect(f.stats, same(before));
    expect(f.count, '4/4');
  });

  test('8. several edits on one day never count today twice', () {
    final f = farm();
    doAll(f);
    for (var i = 0; i < 3; i++) {
      f.edit('c', water: CareSchedule(Repeat.everyWeek, at8));
      expect(f.count, '4/5');
      expect(f.stats.currentStreak, 5);
      f.edit('c', water: CareSchedule(Repeat.every2Weeks, at8));
      expect(f.count, '4/4');
      expect(f.stats.currentStreak, 6);
    }
    expect(f.stats.lastCompletedDate, '2026-11-22');
  });

  test('9. undo after an edit', () {
    final f = farm();
    doAll(f);
    f.edit('c', water: CareSchedule(Repeat.everyWeek, at8));
    f.tick('c', water);
    expect(f.stats.currentStreak, 6);
    f.tick('a', water, isDone: false);
    expect(f.count, '4/5');
    expect(f.stats.currentStreak, 5);
    f.tick('a', water);
    expect(f.stats.currentStreak, 6);
    // Undoing the new task, then editing it away: complete again, once.
    f.tick('c', water, isDone: false);
    expect(f.stats.currentStreak, 5);
    f.edit('c', water: CareSchedule(Repeat.every3Weeks, at8));
    // Every 21 days from Nov 10: Dec 1, nothing today.
    expect(f.count, '4/4');
    expect(f.stats.currentStreak, 6);
  });

  test(
    '10. editing one plant\'s fertilizing leaves other completions alone',
    () {
      final f = farm();
      doAll(f);
      f.edit('a', fertilize: CareSchedule(Repeat.everyWeek, at8));
      expect(f.count, '4/4');
      expect(f.byId('a').irrigation!.lastDone, done(nov(22)));
      expect(f.byId('a').fertilization!.lastDone, done(nov(22)));
      expect(f.stats.currentStreak, 6);
    },
  );

  test('11. after a restart, the same count and streak', () {
    final f = farm();
    doAll(f);
    f.edit('c', water: CareSchedule(Repeat.everyWeek, at8));
    final count = f.count;
    final streak = f.stats.currentStreak;
    f.restart();
    f.open(DateTime(2026, 11, 22, 10));
    expect(f.count, count);
    expect(f.stats.currentStreak, streak);
    f.tick('c', water);
    expect(f.stats.currentStreak, 6);
  });

  test('12. Home and Daily Tasks count the same tasks, each once', () {
    final f = farm();
    doAll(f);
    f.edit('c', water: CareSchedule(Repeat.everyWeek, at8));
    final ids = [for (final t in f.tasks) t.id];
    expect(ids.toSet(), hasLength(ids.length));
    // Home's card uses tasksForDay with the same logs: the same list.
    expect(
      [for (final t in tasksForDay(f.plants, f.today, f.logs, f.now)) t.key],
      [for (final t in f.tasks) t.key],
    );
  });

  group('deleting a plant', () {
    test(
      'D1. the plant with today\'s last unfinished task: today completes',
      () {
        final f = farm();
        f.tick('a', water);
        f.tick('a', fertilize);
        f.tick('b', water);
        expect(f.count, '3/4');
        expect(f.stats.currentStreak, 5);
        f.delete(['d']);
        expect(f.count, '3/3');
        expect(f.stats.currentStreak, 6);
        expect(f.stats.lastCompletedDate, '2026-11-22');
        // Kept the next day: today was completed.
        f.open(DateTime(2026, 11, 23, 9));
        expect(f.stats.currentStreak, 6);
      },
    );

    test('D2. a plant whose tasks were done: never counted, nothing given '
        'twice', () {
      final f = farm();
      doAll(f);
      expect(f.stats.currentStreak, 6);
      f.delete(['b']);
      expect(f.count, '3/3');
      expect(f.stats.currentStreak, 6);
      // Its done tasks don't help: a's done, d still to do.
      final g = farm();
      g.tick('a', water);
      g.tick('a', fertilize);
      g.delete(['a']);
      expect(g.count, '0/2');
      expect(g.stats.currentStreak, 5);
      expect(g.stats.lastCompletedDate, '2026-11-21');
    });

    test('D3. other unfinished tasks left: nothing given', () {
      final f = farm();
      f.tick('a', water);
      f.tick('a', fertilize);
      f.delete(['d']);
      expect(f.count, '2/3');
      expect(f.stats.currentStreak, 5);
      expect(f.stats.lastCompletedDate, '2026-11-21');
    });

    test('D4. the last plant: no tasks left, nothing given or taken', () {
      FarmPlant only() => plant(
        'x',
        water: CareSchedule(
          Repeat.everyDay,
          at8,
          since: nov(1),
          lastDone: done(nov(21)),
        ),
      );
      const streak = FarmStats(
        currentStreak: 5,
        lastCompletedDate: '2026-11-21',
        lands: 1,
      );
      // Its task not done.
      final f = Farm([only()], streak);
      f.delete(['x']);
      expect(f.count, '0/0');
      expect(f.stats, same(streak));
      // Done: today's +1 stays (deleting never takes it back).
      final g = Farm([only()], streak);
      g.tick('x', water);
      expect(g.stats.currentStreak, 6);
      g.delete(['x']);
      expect(g.stats.currentStreak, 6);
      // With no schedules left, the existing rule then ends the streak
      // when the app checks it, without "streak lost".
      g.open(DateTime(2026, 11, 22, 10));
      expect(g.stats.currentStreak, 0);
      expect(g.lost, 0);
    });

    test('D5. a plant with no task today: nothing changes', () {
      final f = farm();
      f.tick('a', water);
      f.tick('a', fertilize);
      f.tick('b', water);
      final before = f.stats;
      f.delete(['c']);
      expect(f.stats, same(before));
      expect(f.count, '3/4');
      // And after today is complete.
      doAll(f);
      f.delete(['d']);
      expect(f.stats.currentStreak, 6);
    });

    test('D6. never twice: deleting more, or several at once', () {
      final f = farm();
      f.tick('a', water);
      f.tick('a', fertilize);
      f.tick('b', water);
      f.delete(['d']);
      expect(f.stats.currentStreak, 6);
      f.delete(['c']);
      f.delete(['b']);
      expect(f.stats.currentStreak, 6);
      // Two unfinished plants deleted together (My Plants): +1 once.
      final g = farm();
      g.tick('a', water);
      g.tick('a', fertilize);
      expect(g.count, '2/4');
      g.delete(['b', 'd']);
      expect(g.count, '2/2');
      expect(g.stats.currentStreak, 6);
    });

    test('D7. a broken streak isn\'t brought back', () {
      // Nov 21 had tasks and wasn't completed.
      final f = farm();
      f.stats = const FarmStats(
        currentStreak: 5,
        lastCompletedDate: '2026-11-20',
        lands: 1,
      );
      f.tick('a', water);
      f.tick('a', fertilize);
      f.tick('b', water);
      expect(f.stats.currentStreak, 0);
      expect(f.lost, 5);
      f.delete(['d']);
      expect(f.stats.currentStreak, 1);
    });

    test('D8. a missed task done late still counts for nothing', () {
      final f = farm();
      f.plants = [
        ...f.plants,
        plant(
          'e',
          water: CareSchedule(
            Repeat.everyWeek,
            at8,
            since: nov(1),
            lastDone: done(nov(13)),
          ),
        ),
      ];
      f.tick('a', water);
      f.tick('a', fertilize);
      f.tick('b', water);
      f.tickLate('e', water, nov(20));
      expect(f.stats.currentStreak, 5);
      f.delete(['d']);
      expect(f.stats.currentStreak, 6);
      f.delete(['e']);
      expect(f.stats.currentStreak, 6);
    });
  });
}
