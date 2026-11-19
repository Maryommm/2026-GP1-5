import 'package:ethmar/models/care_task.dart';
import 'package:ethmar/models/crop_catalog.dart';
import 'package:ethmar/models/daily_task.dart';
import 'package:ethmar/models/farm_plant.dart';
import 'package:ethmar/models/farm_stats.dart';
import 'package:ethmar/models/streak.dart';
import 'package:ethmar/models/task_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FarmPlant plant(String id, Repeat repeat, {DateTime? planted}) => FarmPlant(
      id: id,
      crop: cropCatalog.first,
      name: 'Mint',
      irrigation: CareSchedule(repeat, const TimeOfDay(hour: 8, minute: 0)),
      plantedAt: planted ?? DateTime(2026, 11, 1),
    );

FarmStats stats(int streak, String? last) =>
    FarmStats(currentStreak: streak, lastCompletedDate: last, lands: 2);

void main() {
  final daily = [plant('a', Repeat.everyDay)];
  final every3 = [plant('a', Repeat.every3Days)];

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
          stats(4, '2026-11-03'), daily, DateTime(2026, 11, 5, 9));
      expect(after.currentStreak, 0);
      // Kept, so Home shows "streak lost".
      expect(after.lastCompletedDate, '2026-11-03');
    });

    test('yesterday completed keeps the streak', () {
      final after = streakAfterMissedDays(
          stats(4, '2026-11-04'), daily, DateTime(2026, 11, 5, 9));
      expect(after.currentStreak, 4);
    });

    test('days without tasks in between do not break it', () {
      // Every 3 days from Nov 1: tasks on 1, 4, 7. Nov 5 and 6 have none.
      final after = streakAfterMissedDays(
          stats(2, '2026-11-04'), every3, DateTime(2026, 11, 7, 9));
      expect(after.currentStreak, 2);
    });

    test('today not done yet is not a missed day', () {
      final after = streakAfterMissedDays(
          stats(1, '2026-11-04'), daily, DateTime(2026, 11, 5, 23));
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

    test('only the last 3 days, most recent first', () {
      final missed = missedTasks(daily, today, const {});
      expect([for (final t in missed) TaskLog.dateKey(t.day)],
          ['2026-11-09', '2026-11-08', '2026-11-07']);
      expect(missed.every((t) => t.status == TaskStatus.missed), isTrue);
    });

    test('a task done on its day is not missed', () {
      final missed = missedTasks(
          daily, today, logs({'2026-11-09': ['a_irrigation']}));
      expect([for (final t in missed) TaskLog.dateKey(t.day)],
          ['2026-11-08', '2026-11-07']);
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

  group('streak lost', () {
    test('a missed day breaks the streak and is reported', () {
      final before = stats(4, '2026-11-03');
      final after = streakAfterMissedDays(before, daily, DateTime(2026, 11, 5));
      expect(streakBroken(before, after, daily), isTrue);
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
      final after = streakAfterMissedDays(before, daily, DateTime(2026, 11, 5));
      expect(streakBroken(before, after, daily), isFalse);
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
