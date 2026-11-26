/// Decides when watering and fertilizing are due. Daily Tasks, Home,
/// Plant Details, the streak and the reminders all use these rules.
///
/// The rules, for one plant and one type (watering and fertilizing never
/// affect each other):
/// - The first task is due on the schedule's start day
///   ([CareSchedule.since]).
/// - Once a task is done, on time, early on its day, or late, the next one
///   is due [Repeat.days] days after the day it was really done
///   ([CareSchedule.lastDone]), at the schedule's time, but never before
///   the start day (after a new repeat whose day has already passed, the
///   next task is due on the day it was changed).
/// - A task that isn't done on its day is missed for the next
///   [missedTaskDays] days, and can still be done then (late). Meanwhile
///   no other task of the same type is due for that plant, so there are
///   never two to do at once.
/// - If it still isn't done, it expires (it stays not done) and the
///   schedule carries on as it was: the next task is the first of the
///   usual days after the missed ones. Skipped tasks don't pile up.
///
/// So when nothing is done, a task comes every [activeStep] days.
///
/// Days are counted by calendar date, so daylight saving time never moves
/// a task.
library;

import 'daily_task.dart' show TaskType, missedTaskDays;
import 'farm_plant.dart';
import 'task_log.dart';

/// One care task on a given day: which plant, what to do, and when.
class CareTask {
  const CareTask({required this.plant, required this.type, required this.at});

  final FarmPlant plant;
  final TaskType type;

  /// The reminder time: the task's day at the schedule's time.
  final DateTime at;
}

/// How many days apart the tasks are when none of them is done.
/// It is [every], or the first multiple of [every] that comes after the
/// missed days.
int activeStep(int every) =>
    every * ((missedTaskDays + 1 + every - 1) ~/ every);

/// The state of one plant's watering or fertilizing on [today]: what task
/// to do now, whether today's task is done, and when the next one is.
/// Create it with [careState].
class CareState {
  const CareState._({
    required this.plant,
    required this.type,
    required this.schedule,
    required this.today,
    required this.anchor,
    required this.start,
    required this.missed,
    required this.dueToday,
    required this.doneToday,
    required this.suppressedToday,
    required this.next,
  });

  final FarmPlant plant;
  final TaskType type;
  final CareSchedule schedule;

  /// The day this state is for.
  final DateTime today;

  /// The last time the task was done (null if never). The schedule counts
  /// from this date.
  final CareDone? anchor;

  /// The first task after [anchor], or the schedule's first task if it was
  /// never done. If nothing is done, tasks fall on this day and then every
  /// [activeStep] days.
  final DateTime start;

  /// A missed task that can still be done late, or null.
  final DateTime? missed;

  /// True if a task is due today and is not done yet.
  final bool dueToday;

  /// True if today's task was done on time.
  final bool doneToday;

  /// True if a task would normally be due today, but the [missed] task takes
  /// its place (so there are not two tasks today).
  final bool suppressedToday;

  /// The next task that is not done yet: today's task if [dueToday],
  /// otherwise a later day.
  final DateTime next;

  /// The task to show as current: the missed one if there is one,
  /// otherwise [next].
  DateTime get nextDue => missed ?? next;

  /// The task log id, for example "{plantId}_irrigation".
  String get taskId => careTaskId(plant.id ?? '', type);

  /// [day] at the schedule's time.
  DateTime at(DateTime day) => DateTime(
    day.year,
    day.month,
    day.day,
    schedule.time.hour,
    schedule.time.minute,
  );

  /// All the days that have a task between [from] and [to] (both included),
  /// assuming none of them gets done. Used to plan the reminders.
  Iterable<DateTime> taskDays(DateTime from, DateTime to) sync* {
    final step = activeStep(schedule.repeat.days);
    final s = _dayNumber(start), end = _dayNumber(to);
    var d = _dayNumber(from);
    if (d < s) d = s;
    final off = (d - s) % step;
    if (off != 0) d += step - off;
    for (; d <= end; d += step) {
      yield _fromDayNumber(d);
    }
  }
}

/// The task log id for [type] on plant [plantId].
String careTaskId(String plantId, TaskType type) => switch (type) {
  TaskType.watering => TaskLog.irrigationTaskId(plantId),
  TaskType.fertilizing => TaskLog.fertilizationTaskId(plantId),
};

/// The state of [plant]'s [type] task on the date of [now], or null if that
/// schedule is turned off.
///
/// [logs] are task logs by date key (see [TaskLog.dateKey]). They are
/// optional because the plant's saved [CareSchedule.lastDone] is enough.
/// When given, they also include ticks that are not saved on the plant
/// yet, and ignore a saved tick that was un-ticked.
CareState? careState(
  FarmPlant plant,
  TaskType type,
  DateTime now, {
  Map<String, TaskLog> logs = const {},
}) {
  final schedule = plant.scheduleOf(type);
  if (schedule == null) return null;
  final today = _dateOnly(now);
  final every = schedule.repeat.days;
  final step = activeStep(every);
  final anchor = _anchor(
    schedule,
    careTaskId(plant.id ?? '', type),
    today,
    logs,
  );
  final start = anchor == null ? schedule.since : _nextAfter(anchor, schedule);

  final t = _dayNumber(today), s = _dayNumber(start);
  int? missed;
  var dueToday = false;
  int next;
  if (s >= t) {
    next = s;
    dueToday = s == t;
  } else {
    // The latest task on or before today, with nothing done since the anchor.
    final latest = s + (t - s) ~/ step * step;
    if (latest == t) {
      next = t;
      dueToday = true;
    } else {
      if (latest + missedTaskDays >= t) missed = latest;
      next = latest + step;
    }
  }
  final onRhythm = t >= s && (t - s) % every == 0;
  return CareState._(
    plant: plant,
    type: type,
    schedule: schedule,
    today: today,
    anchor: anchor,
    start: start,
    missed: missed == null ? null : _fromDayNumber(missed),
    dueToday: dueToday,
    doneToday: anchor != null && anchor.due == today && anchor.date == today,
    suppressedToday: missed != null && onRhythm,
    next: _fromDayNumber(next),
  );
}

/// [careState] for every watering and fertilizing schedule that is turned
/// on.
List<CareState> careStates(
  List<FarmPlant> plants,
  DateTime now, {
  Map<String, TaskLog> logs = const {},
}) => [
  for (final plant in plants)
    if (plant.id != null)
      for (final type in TaskType.values)
        if (careState(plant, type, now, logs: logs) case final state?) state,
];

/// The care tasks of [day], sorted by time.
/// For a past day: the tasks the user had that day, done or not.
/// For a future day: the tasks it will have if nothing is done before then.
///
/// This only uses what each schedule saves (start day and the last two
/// done times), not the task logs. Used for the streak: a day with tasks
/// that was not completed breaks it.
List<CareTask> dueTasks(List<FarmPlant> plants, DateTime day) {
  final tasks = <CareTask>[
    for (final plant in plants)
      for (final type in TaskType.values)
        if (plant.scheduleOf(type) case final schedule?)
          if (_hadTask(schedule, day))
            CareTask(plant: plant, type: type, at: _atTime(day, schedule)),
  ];
  tasks.sort((a, b) => a.at.compareTo(b.at));
  return tasks;
}

/// Whether the schedule had a task on [day] (see [dueTasks]).
bool _hadTask(CareSchedule schedule, DateTime day) {
  final every = schedule.repeat.days;
  final step = activeStep(every);
  final d = _dayNumber(day);
  bool onChain(DateTime from) {
    final s = _dayNumber(from);
    return d >= s && (d - s) % step == 0;
  }

  // The known done times, newest first. Between two of them, tasks came
  // every activeStep days starting from the older one.
  final done = [
    if (schedule.lastDone case final last?) last,
    if (schedule.previousDone case final previous?) previous,
  ]..sort((a, b) => a == b ? 0 : (b.isAfter(a) ? 1 : -1));
  for (final (i, time) in done.indexed) {
    final due = _dayNumber(time.due), date = _dayNumber(time.date);
    if (d == due) return true;
    if (d > date) {
      // After the newest done time, the start day also counts (in case the
      // repeat changed). Between two done times it can't.
      return onChain(
        i == 0 ? _nextAfter(time, schedule) : _addDays(time.date, every),
      );
    }
    // Between a missed task and the day it was done late there is no other
    // task.
    if (d > due) return false;
  }
  return onChain(schedule.since);
}

/// The last known time task [id] was done: from the plant's saved
/// [CareSchedule.lastDone] (or [CareSchedule.previousDone] if the latest
/// was un-ticked), or from a tick in [logs], whichever is newer.
CareDone? _anchor(
  CareSchedule schedule,
  String id,
  DateTime today,
  Map<String, TaskLog> logs,
) {
  CareDone? best;
  // A saved time still counts, unless that day's log is loaded and no longer
  // has the task (it was un-ticked but the plant isn't updated yet).
  for (final saved in [schedule.lastDone, schedule.previousDone]) {
    if (saved == null) continue;
    final log = logs[TaskLog.dateKey(saved.due)];
    if (log != null && !log.isDone(id)) continue;
    if (saved.isAfter(best)) best = saved;
  }
  // Ticks in the logs, from the schedule's start (a tick of an older,
  // changed schedule doesn't count).
  final first = schedule.since;
  for (final log in logs.values) {
    final day = TaskLog.parseKey(log.date);
    if (day == null || day.isBefore(first) || day.isAfter(today)) continue;
    CareDone? tick;
    if (log.isCompleted(id)) {
      tick = CareDone(date: day, due: day);
    } else if (log.isDoneLate(id)) {
      // Ticked late before we kept the real day: it was at least one day later.
      var on = log.lateDoneOn(id) ?? _addDays(day, 1);
      if (on.isAfter(today)) on = today;
      tick = CareDone(date: on, due: day);
    }
    if (tick != null && tick.isAfter(best)) best = tick;
  }
  return best;
}

/// The next task after one done at [done]: [Repeat.days] days after the
/// day it was actually done, but not before the schedule's start day.
DateTime _nextAfter(CareDone done, CareSchedule schedule) {
  final next = _addDays(done.date, schedule.repeat.days);
  return schedule.since.isAfter(next) ? schedule.since : next;
}

DateTime _dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

DateTime _addDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

/// Number of days since 1 January 1970 for the date of [t]. It uses UTC
/// dates so daylight saving can't make a day 23 or 25 hours long.
int _dayNumber(DateTime t) =>
    DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// Turns a [_dayNumber] back into a local date.
DateTime _fromDayNumber(int n) {
  final utc = DateTime.fromMillisecondsSinceEpoch(
    n * Duration.millisecondsPerDay,
    isUtc: true,
  );
  return DateTime(utc.year, utc.month, utc.day);
}

DateTime _atTime(DateTime day, CareSchedule schedule) => DateTime(
  day.year,
  day.month,
  day.day,
  schedule.time.hour,
  schedule.time.minute,
);
