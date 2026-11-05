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

    test('is completed, overdue or upcoming', () {
      final empty = TaskLog(date: '2026-11-05');
      final done = TaskLog(date: '2026-11-05', completed: ['a_irrigation']);
      expect(DailyTask.from(task, done, DateTime(2026, 11, 5, 7)).status,
          TaskStatus.completed);
      expect(DailyTask.from(task, empty, DateTime(2026, 11, 5, 9)).status,
          TaskStatus.overdue);
      expect(DailyTask.from(task, empty, DateTime(2026, 11, 5, 7)).status,
          TaskStatus.upcoming);
    });
  });
}
