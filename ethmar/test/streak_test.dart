import 'package:ethmar/models/care_task.dart';
import 'package:ethmar/models/crop_catalog.dart';
import 'package:ethmar/models/daily_task.dart';
import 'package:ethmar/models/farm_plant.dart';
import 'package:ethmar/models/farm_stats.dart';
import 'package:ethmar/models/streak.dart';
import 'package:ethmar/models/task_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A plant watered [repeat], planted and added on Nov 1 (or [planted]).
/// [doneOn] is the last day its task was done, on time.
FarmPlant plant(
  String id,
  Repeat repeat, {
  DateTime? planted,
  DateTime? doneOn,
}) => FarmPlant(
      id: id,
      crop: cropCatalog.first,
      name: 'Mint',
      irrigation: CareSchedule(
        repeat,
        const TimeOfDay(hour: 8, minute: 0),
        lastDone: doneOn == null ? null : CareDone(date: doneOn, due: doneOn),
      ),
      plantedAt: planted ?? DateTime(2026, 11, 1),
      // Added to the app on its planting day, not changed since.
      createdAt: planted ?? DateTime(2026, 11, 1),
      updatedAt: planted ?? DateTime(2026, 11, 1),
    );

FarmStats stats(int streak, String? last) =>
    FarmStats(currentStreak: streak, lastCompletedDate: last, lands: 2);

void main() {
  final daily = [plant('a', Repeat.everyDay)];
  // Watered on the given day of November, the last completed day.
  List<FarmPlant> dailyDone(int day) =>
      [plant('a', Repeat.everyDay, doneOn: DateTime(2026, 11, day))];
  // Every 3 days, last done on Nov 4: next due on the 7th.
  final every3 = [
    plant('a', Repeat.every3Days, doneOn: DateTime(2026, 11, 4)),
  ];

  group('streak lost to missed tasks', () {
    final today = DateTime(2026, 11, 5, 9);

    test('a day with tasks after the last completed day was missed', () {
      expect(
          streakBrokenByMissedTasks(stats(0, '2026-11-03'), dailyDone(3), today),
          isTrue);
    });

    test('nothing missed while every task day was completed', () {
      expect(
          streakBrokenByMissedTasks(stats(2, '2026-11-04'), dailyDone(4), today),
          isFalse);
      // Today completed: a new streak has started.
      expect(
          streakBrokenByMissedTasks(stats(1, '2026-11-05'), dailyDone(5), today),
          isFalse);
    });

    test('days without tasks are not missed', () {
      // Done on the 4th, every 3 days: next due on the 7th.
      expect(
          streakBrokenByMissedTasks(
              stats(1, '2026-11-04'), every3, DateTime(2026, 11, 6)),
          isFalse);
      expect(
          streakBrokenByMissedTasks(
              stats(0, '2026-11-04'), every3, DateTime(2026, 11, 8)),
          isTrue);
    });

    test('no streak yet, or no plants: nothing to say', () {
      expect(streakBrokenByMissedTasks(stats(0, null), daily, today), isFalse);
      expect(
          streakBrokenByMissedTasks(stats(0, '2026-11-03'), const [], today),
          isFalse);
    });
  });

  group('completing a day', () {
    final today = DateTime(2026, 11, 5, 20);

    test('adds 1 and remembers the day, once', () {
      final after = streakAfterToggle(stats(2, '2026-11-04'),
          today: today, allDone: true, previousTaskDay: DateTime(2026, 11, 4));
      expect(after.currentStreak, 3);
      expect(after.lastCompletedDate, '2026-11-05');
      expect(after.lands, 2);
      final again = streakAfterToggle(after,
          today: today, allDone: true, previousTaskDay: DateTime(2026, 11, 4));
      expect(again.currentStreak, 3);
    });

    test('an unfinished day changes nothing', () {
      final before = stats(2, '2026-11-04');
      final after = streakAfterToggle(before,
          today: today, allDone: false, previousTaskDay: DateTime(2026, 11, 4));
      expect(after.currentStreak, 2);
      expect(after.lastCompletedDate, '2026-11-04');
    });

    test('un-ticking a task on a completed day takes the 1 back', () {
      final after = streakAfterToggle(stats(3, '2026-11-05'),
          today: today, allDone: false, previousTaskDay: DateTime(2026, 11, 4));
      expect(after.currentStreak, 2);
      expect(after.lastCompletedDate, '2026-11-04');
    });

    test('taking back a first day goes back to not started', () {
      final after = streakAfterToggle(stats(1, '2026-11-05'),
          today: today, allDone: false, previousTaskDay: DateTime(2026, 11, 4));
      expect(after.currentStreak, 0);
      expect(after.lastCompletedDate, isNull);
    });
  });

  group('checking missed days when the app opens', () {
    test('a day with tasks that was not completed resets the streak', () {
      final after = streakAfterMissedDays(
          stats(4, '2026-11-03'), dailyDone(3), DateTime(2026, 11, 5, 9));
      expect(after.currentStreak, 0);
      // Kept, so Home shows "streak lost".
      expect(after.lastCompletedDate, '2026-11-03');
    });

    test('yesterday completed keeps the streak', () {
      final after = streakAfterMissedDays(
          stats(4, '2026-11-04'), dailyDone(4), DateTime(2026, 11, 5, 9));
      expect(after.currentStreak, 4);
    });

    test('days without tasks in between do not break it', () {
      // Done on Nov 4, every 3 days: the next task is on the 7th, so Nov 5
      // and 6 have none.
      final after = streakAfterMissedDays(
          stats(2, '2026-11-04'), every3, DateTime(2026, 11, 7, 9));
      expect(after.currentStreak, 2);
    });

    test('today not done yet is not a missed day', () {
      final after = streakAfterMissedDays(
          stats(1, '2026-11-04'), dailyDone(4), DateTime(2026, 11, 5, 23));
      expect(after.currentStreak, 1);
    });

    test('plants with every schedule switched off: the streak goes to 0', () {
      final noSchedules = [
        FarmPlant(id: 'a', crop: cropCatalog.first, name: 'Mint',
            plantedAt: DateTime(2026, 11, 1)),
      ];
      expect(streakAfterMissedDays(stats(3, '2026-11-04'), noSchedules,
              DateTime(2026, 11, 5)).currentStreak, 0);
    });

    test('no plants: the streak stays at 0', () {
      expect(streakAfterMissedDays(stats(3, '2026-11-04'), const [],
              DateTime(2026, 11, 5)).currentStreak, 0);
      expect(streakAfterMissedDays(stats(0, null), const [],
              DateTime(2026, 11, 5)).currentStreak, 0);
    });
  });

  test('previousTaskDay skips days without tasks', () {
    expect(previousTaskDay(every3, DateTime(2026, 11, 7, 12)),
        DateTime(2026, 11, 4));
    expect(previousTaskDay(every3, DateTime(2026, 11, 1)), isNull);
  });

  group('daily task', () {
    final task = dueTasks(daily, DateTime(2026, 11, 5)).single;

    test('uses the task log id of its plant and type', () {
      expect(DailyTask.taskId(task), TaskLog.irrigationTaskId('a'));
      expect(task.type, TaskType.watering);
    });

    test('is completed, upcoming, or due once its time has passed', () {
      final empty = TaskLog(date: '2026-11-05');
      final done = TaskLog(date: '2026-11-05', completed: ['a_irrigation']);
      expect(DailyTask.from(task, done, DateTime(2026, 11, 5, 7)).status,
          TaskStatus.completed);
      expect(DailyTask.from(task, empty, DateTime(2026, 11, 5, 7)).status,
          TaskStatus.upcoming);
      // Its time has passed but the day isn't over: not missed yet.
      expect(DailyTask.from(task, empty, DateTime(2026, 11, 5, 23, 59)).status,
          TaskStatus.due);
    });
  });

  group('missed tasks', () {
    final today = DateTime(2026, 11, 10, 9);
    Map<String, TaskLog> logs(Map<String, List<String>> completed,
            [Map<String, List<String>> late = const {}]) =>
        {
          for (final d in {...completed.keys, ...late.keys})
            d: TaskLog(
                date: d,
                completed: completed[d] ?? const [],
                late: late[d] ?? const []),
        };

    test('one missed task at a time, from the last 3 days', () {
      // Done on Nov 6: due on the 7th, which was missed. Until it's done or
      // too old, the 8th, 9th and 10th have no watering of their own.
      final missed = missedTasks(dailyDone(6), today, const {});
      expect([for (final t in missed) TaskLog.dateKey(t.day)], ['2026-11-07']);
      expect(missed.single.status, TaskStatus.missed);
      expect(tasksForDay(dailyDone(6), today, const {}, today), isEmpty);
    });

    test('a task done on its day is not missed', () {
      final missed = missedTasks(
          daily, today, logs({'2026-11-09': ['a_irrigation']}));
      expect(missed, isEmpty);
      // Done on the 9th: the next one is due today.
      expect(tasksForDay(daily, today,
              logs({'2026-11-09': ['a_irrigation']}), today),
          hasLength(1));
    });

    test('a task done late stays in the list as done late', () {
      final missed = missedTasks(
          daily, today, logs(const {}, {'2026-11-08': ['a_irrigation']}));
      final late = missed.singleWhere((t) => t.status == TaskStatus.doneLate);
      expect(TaskLog.dateKey(late.day), '2026-11-08');
      expect(late.done, isTrue);
      expect(late.isPast, isTrue);
    });

    test('days before the plant was added to the app are skipped', () {
      final added = [
        FarmPlant(
          id: 'a',
          crop: cropCatalog.first,
          name: 'Mint',
          irrigation:
              const CareSchedule(Repeat.everyDay, TimeOfDay(hour: 8, minute: 0)),
          plantedAt: DateTime(2026, 11, 1),
          createdAt: DateTime(2026, 11, 9, 15),
          updatedAt: DateTime(2026, 11, 9, 15),
        ),
      ];
      expect([for (final t in missedTasks(added, today, const {})) t.day],
          [DateTime(2026, 11, 9)]);
    });

    test('each card has its own key, also for the same plant and type', () {
      final missed = missedTasks(daily, today, const {});
      expect({for (final t in missed) t.key}, hasLength(missed.length));
    });
  });

  group('a schedule only counts from the day it was set', () {
    const at8 = TimeOfDay(hour: 8, minute: 0);
    // Planted and added on Nov 1 with no schedule; daily watering set on
    // Nov 10.
    final noSchedule = FarmPlant(
      id: 'a',
      crop: cropCatalog.first,
      name: 'Mint',
      plantedAt: DateTime(2026, 11, 1),
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    );
    final today = DateTime(2026, 11, 10, 9);
    final watered = noSchedule.edited(
      name: 'Mint',
      irrigation: const CareSchedule(Repeat.everyDay, at8),
      fertilization: null,
      today: today,
    );

    test('a new schedule starts today', () {
      expect(watered.irrigation!.since, DateTime(2026, 11, 10));
      expect(dueTasks([watered], DateTime(2026, 11, 9)), isEmpty);
      expect(dueTasks([watered], DateTime(2026, 11, 10)), hasLength(1));
    });

    test('the days before it are not missed tasks', () {
      expect(missedTasks([watered], today, const {}), isEmpty);
    });

    test('the days before it do not break the streak', () {
      final before = stats(3, '2026-11-08');
      expect(streakAfterMissedDays(before, [watered], today).currentStreak, 3);
    });

    test('an unchanged schedule keeps its start day when saved again', () {
      final again = watered.edited(
        name: 'Mint 2',
        irrigation: const CareSchedule(Repeat.everyDay, at8),
        fertilization: null,
        today: DateTime(2026, 11, 15),
      );
      expect(again.irrigation!.since, DateTime(2026, 11, 10));
    });

    test('a changed schedule starts again on the day it changed', () {
      final changed = watered.edited(
        name: 'Mint',
        irrigation: const CareSchedule(Repeat.every2Days, at8),
        fertilization: null,
        today: DateTime(2026, 11, 15),
      );
      expect(changed.irrigation!.since, DateTime(2026, 11, 15));
    });

    test('the start day is saved and read back', () {
      final map = watered.irrigation!.toMap();
      expect(map['since'], '2026-11-10');
      expect(CareSchedule.fromMap(map)!.since, DateTime(2026, 11, 10));
      // Saved before start days were kept.
      expect(CareSchedule.fromMap({'everyDays': 1, 'time': '08:00'})!.since,
          isNull);
    });

    test('an older schedule without a start day counts from when the plant '
        'was last saved', () {
      // Added on Nov 1 without a schedule; daily watering set on Nov 9,
      // before start days were kept.
      final added = FarmPlant(
        id: 'b',
        crop: cropCatalog.first,
        name: 'Basil',
        irrigation: const CareSchedule(Repeat.everyDay, at8),
        plantedAt: DateTime(2026, 11, 1),
        createdAt: DateTime(2026, 11, 1),
        updatedAt: DateTime(2026, 11, 9, 15),
      );
      expect(dueTasks([added], DateTime(2026, 11, 8)), isEmpty);
      expect(dueTasks([added], DateTime(2026, 11, 9)), hasLength(1));
    });

    test('renaming a plant with an older schedule keeps its missed tasks', () {
      final old = FarmPlant(
        id: 'b',
        crop: cropCatalog.first,
        name: 'Basil',
        irrigation: const CareSchedule(Repeat.everyDay, at8),
        plantedAt: DateTime(2026, 11, 1),
        createdAt: DateTime(2026, 11, 1),
        updatedAt: DateTime(2026, 11, 5),
      );
      // Nov 7, 8 and 9 were missed. Renamed on Nov 10: same schedule.
      final renamed = old.edited(
        name: 'My basil',
        irrigation: const CareSchedule(Repeat.everyDay, at8),
        fertilization: null,
        today: today,
      );
      expect(renamed.irrigation!.since, DateTime(2026, 11, 5));
      // From Nov 5, nothing done: the 5th expired, the 9th is missed (one
      // missed task at a time).
      expect([for (final t in missedTasks([renamed], today, const {})) t.day],
          [DateTime(2026, 11, 9)]);
      expect([for (final t in missedTasks([old], today, const {})) t.day],
          [DateTime(2026, 11, 9)]);
      // And renaming again later still doesn't move it.
      final again = renamed.edited(
        name: 'Basil',
        irrigation: const CareSchedule(Repeat.everyDay, at8),
        fertilization: null,
        today: DateTime(2026, 11, 12),
      );
      expect(again.irrigation!.since, DateTime(2026, 11, 5));
    });
  });

  group('streak lost', () {
    test('a missed day breaks the streak and is reported', () {
      final before = stats(4, '2026-11-03');
      final after =
          streakAfterMissedDays(before, dailyDone(3), DateTime(2026, 11, 5));
      expect(streakBroken(before, after, dailyDone(3)), isTrue);
    });

    test('deleting every plant is not reported as a missed day', () {
      final before = stats(4, '2026-11-04');
      final after =
          streakAfterMissedDays(before, const [], DateTime(2026, 11, 5));
      expect(after.currentStreak, 0);
      expect(streakBroken(before, after, const []), isFalse);
    });

    test('a streak that carries on is not reported', () {
      final before = stats(4, '2026-11-04');
      final after =
          streakAfterMissedDays(before, dailyDone(4), DateTime(2026, 11, 5));
      expect(streakBroken(before, after, dailyDone(4)), isFalse);
    });
  });

  group('task log', () {
    test('keeps on-time and late tasks apart', () {
      final log = TaskLog.fromMap('2026-11-05', {
        'completed': ['a_irrigation'],
        'late': ['b_irrigation'],
      });
      expect(log.isCompleted('a_irrigation'), isTrue);
      expect(log.isCompleted('b_irrigation'), isFalse);
      expect(log.isDoneLate('b_irrigation'), isTrue);
      expect(log.toMap(), {
        'completed': ['a_irrigation'],
        'late': ['b_irrigation'],
      });
    });

    test('logs saved before late tasks existed still load', () {
      final log = TaskLog.fromMap('2026-11-05', {'completed': <String>[]});
      expect(log.late, isEmpty);
    });
  });
}
