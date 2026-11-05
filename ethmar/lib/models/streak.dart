/// The daily streak rules, kept apart from Firestore so they can be tested.
///
/// - The streak goes up by 1 on a day when every task of that day is done.
/// - Un-ticking a task on a completed day takes that 1 back.
/// - When the app opens, a day with tasks between the last completed day
///   and today that wasn't completed resets the streak to 0. Days with no
///   tasks don't break it.
/// - With no plants, or no plant with a watering or fertilizing schedule,
///   there are no tasks, so the streak stays at 0.
library;

import 'care_task.dart';
import 'farm_plant.dart';
import 'farm_stats.dart';
import 'task_log.dart';

/// The streak after the app opens on [today]: 0 if a day with tasks was
/// missed since [FarmStats.lastCompletedDate], or if no plant has an active
/// care schedule (including when there are no plants).
/// [FarmStats.lastCompletedDate] is kept, so Home can show "streak lost".
FarmStats streakAfterMissedDays(
  FarmStats stats,
  List<FarmPlant> plants,
  DateTime today,
) {
  if (stats.currentStreak == 0) return stats;
  final last = _parseDate(stats.lastCompletedDate);
  final hasSchedules =
      plants.any((p) => p.irrigation != null || p.fertilization != null);
  if (!hasSchedules || last == null) return _withStreak(stats, 0);

  final day = _dateOnly(today);
  // More than a year away: certainly missed, and not worth scanning.
  if (day.difference(last).inDays > 366) return _withStreak(stats, 0);
  for (var d = _nextDay(last); d.isBefore(day); d = _nextDay(d)) {
    if (dueTasks(plants, d).isNotEmpty) return _withStreak(stats, 0);
  }
  return stats;
}

/// The streak after a task of [today] is ticked or un-ticked.
///
/// [allDone] says whether every task of today is now done. When a completed
/// day becomes incomplete again, the +1 is taken back, and the last
/// completed day goes back to [previousTaskDay] (see [previousTaskDay]).
FarmStats streakAfterToggle(
  FarmStats stats, {
  required DateTime today,
  required bool allDone,
  required DateTime? previousTaskDay,
}) {
  final key = TaskLog.dateKey(today);
  if (allDone) {
    if (stats.lastCompletedDate == key) return stats;
    return FarmStats(
      currentStreak: stats.currentStreak + 1,
      lastCompletedDate: key,
      lands: stats.lands,
    );
  }
  if (stats.lastCompletedDate != key) return stats;
  final streak = stats.currentStreak > 0 ? stats.currentStreak - 1 : 0;
  return FarmStats(
    currentStreak: streak,
    lastCompletedDate: streak == 0 || previousTaskDay == null
        ? null
        : TaskLog.dateKey(previousTaskDay),
    lands: stats.lands,
  );
}

/// The last day before [today] that had tasks, within a year, or null.
///
/// While a streak is running, every day with tasks was completed, so this
/// is the completed day before today.
DateTime? previousTaskDay(List<FarmPlant> plants, DateTime today) {
  var d = _dateOnly(today);
  for (var i = 0; i < 366; i++) {
    d = DateTime(d.year, d.month, d.day - 1);
    if (dueTasks(plants, d).isNotEmpty) return d;
  }
  return null;
}

FarmStats _withStreak(FarmStats stats, int streak) => FarmStats(
  currentStreak: streak,
  lastCompletedDate: stats.lastCompletedDate,
  lands: stats.lands,
);

DateTime _dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

DateTime _nextDay(DateTime d) => DateTime(d.year, d.month, d.day + 1);

/// "yyyy-mm-dd" (see [TaskLog.dateKey]) to a local date, or null.
DateTime? _parseDate(String? key) {
  if (key == null) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
  if (match == null) return null;
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}
