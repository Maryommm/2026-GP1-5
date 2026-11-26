/// The daily streak rules. They are kept separate from Firestore so they
/// can be tested.
///
/// - The streak goes up by 1 on a day when all of that day's tasks are done.
/// - Un-ticking a task on a completed day takes that 1 back.
/// - When the app opens, if a day with tasks between the last completed day
///   and today was not completed, the streak resets to 0. Days with no
///   tasks don't break it.
/// - With no plants, or no plant with a schedule, there are no tasks, so
///   the streak stays at 0.
/// - A day only counts if its tasks are done on that same day. A missed
///   task done later adds nothing.
library;

import 'care_task.dart';
import 'daily_task.dart' show tasksForDay;
import 'farm_plant.dart';
import 'farm_stats.dart';
import 'task_log.dart';

/// The streak when the app opens on [today]. It is 0 if a day with tasks
/// was missed since [FarmStats.lastCompletedDate], or if no plant has an
/// active schedule. [FarmStats.lastCompletedDate] is kept so Home can show
/// "streak lost".
FarmStats streakAfterMissedDays(
  FarmStats stats,
  List<FarmPlant> plants,
  DateTime today,
) {
  if (stats.currentStreak == 0) return stats;
  final last = _parseDate(stats.lastCompletedDate);
  if (!_hasSchedules(plants) || last == null) return _withStreak(stats, 0);

  final day = _dateOnly(today);
  // More than a year ago: definitely missed, no need to check each day.
  if (day.difference(last).inDays > 366) return _withStreak(stats, 0);
  for (var d = _nextDay(last); d.isBefore(day); d = _nextDay(d)) {
    if (dueTasks(plants, d).isNotEmpty) return _withStreak(stats, 0);
  }
  return stats;
}

/// True when going from [before] to [after] broke a running streak because
/// a day with tasks was missed, so Home can tell the user. False when it
/// went to 0 only because no plant has a schedule anymore.
bool streakBroken(FarmStats before, FarmStats after, List<FarmPlant> plants) =>
    before.currentStreak > 0 &&
    after.currentStreak == 0 &&
    _hasSchedules(plants);

bool _hasSchedules(List<FarmPlant> plants) =>
    plants.any((p) => p.irrigation != null || p.fertilization != null);

/// True when the streak was lost because a day with tasks (after the last
/// completed day and before [today]) was not completed. Daily Tasks and
/// Home then show a message. It becomes false again once a new day is
/// completed.
///
/// False when there never was a streak, or when the streak ended for
/// another reason (for example no plants have a schedule).
bool streakBrokenByMissedTasks(
  FarmStats stats,
  List<FarmPlant> plants,
  DateTime today,
) {
  final last = _parseDate(stats.lastCompletedDate);
  if (last == null) return false;
  final day = _dateOnly(today);
  // Missed for over a year: the streak is gone, but no need to tell the user.
  if (day.difference(last).inDays > 366) return false;
  for (var d = _nextDay(last); d.isBefore(day); d = _nextDay(d)) {
    if (dueTasks(plants, d).isNotEmpty) return true;
  }
  return false;
}

/// The streak after a task of [today] is ticked or un-ticked.
///
/// [allDone] says whether all of today's tasks are now done. If a
/// completed day becomes incomplete again, the +1 is taken back and the
/// last completed day goes back to [previousTaskDay].
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

/// The streak after a plant's schedule is edited at [now]. [before] are the
/// plants before the edit, [after] are the plants now, and [todayLog] is
/// today's task log.
///
/// Today counts as completed only while all of today's tasks are done
/// (same as [streakAfterToggle]):
/// - If the edit adds a task to a completed day, today's +1 is taken back.
///   Ticking the new task gives it back.
/// - If the edit removes today's last unfinished task, the day becomes
///   completed (once).
/// - Anything else (for example only a new time) leaves the streak as it
///   is. Earlier days are checked with [before], the old schedules.
FarmStats streakAfterScheduleChange(
  FarmStats stats, {
  required List<FarmPlant> before,
  required List<FarmPlant> after,
  required DateTime now,
  required TaskLog todayLog,
}) {
  final today = _dateOnly(now);
  bool allDone(List<FarmPlant> plants) {
    final tasks = tasksForDay(plants, today, {todayLog.date: todayLog}, now);
    return tasks.isNotEmpty && tasks.every((t) => t.done);
  }

  final done = allDone(after);
  if (done == allDone(before)) return stats;
  return streakAfterToggle(
    done ? streakAfterMissedDays(stats, before, today) : stats,
    today: today,
    allDone: done,
    previousTaskDay: previousTaskDay(before, today),
  );
}

/// The streak after a plant is deleted at [now]. [before] are the plants
/// with it, [after] without it, and [todayLog] is today's task log.
///
/// This works like an edit that removes the plant's tasks from today
/// ([streakAfterScheduleChange]): if the plant had today's last unfinished
/// task, the day becomes completed (once). Deleting can't add a task, so it
/// never takes today's +1 back.
///
/// If no tasks are left today (for example the last plant was deleted),
/// nothing changes. The streak goes back to 0 the next time the app checks
/// it ([streakAfterMissedDays]).
FarmStats streakAfterPlantDeleted(
  FarmStats stats, {
  required List<FarmPlant> before,
  required List<FarmPlant> after,
  required DateTime now,
  required TaskLog todayLog,
}) {
  final today = _dateOnly(now);
  if (tasksForDay(after, today, {todayLog.date: todayLog}, now).isEmpty) {
    return stats;
  }
  return streakAfterScheduleChange(
    stats,
    before: before,
    after: after,
    now: now,
    todayLog: todayLog,
  );
}

/// The last day before [today] that had tasks (within a year), or null.
/// While a streak is running, this is the completed day before today.
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

/// Converts "yyyy-mm-dd" (see [TaskLog.dateKey]) to a local date, or null.
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
