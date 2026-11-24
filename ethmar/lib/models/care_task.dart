/// When watering and fertilizing are due: the one place that decides it, for
/// Daily Tasks, Home, Plant Details, the streak and the care reminders.
///
/// The rules, for one plant and one type (watering and fertilizing never
/// affect each other):
/// - The first task is due on the schedule's start day
///   ([CareSchedule.since]; for older schedules without one, on the
///   planting-day rhythm from the day the plant was last saved).
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
/// With nothing done, the tasks therefore come every [activeStep] days:
/// every [Repeat.days] days, or, for schedules shorter than the missed
/// days, the first of those days after them (every 4 days for daily and
/// every-2-days watering, every 6 for every 3 days).
///
/// Days are counted on calendar dates, so a daylight-saving change never
/// moves a task's day or its time of day.
library;

import 'daily_task.dart' show TaskType, missedTaskDays;
import 'farm_plant.dart';
import 'task_log.dart';

/// One care task on a given day: which plant, what to do, and when.
class CareTask {
  const CareTask({required this.plant, required this.type, required this.at});

  final FarmPlant plant;
  final TaskType type;

  /// The alarm time: the day of the task at the schedule's time.
  final DateTime at;
}

/// Days between tasks while none is done: [every], or the first multiple of
/// it after a missed task's [missedTaskDays] days.
int activeStep(int every) =>
    every * ((missedTaskDays + 1 + every - 1) ~/ every);

/// Where one plant's watering or fertilizing stands on [today]: the task to
/// do now (missed or due today), whether today's is done, and when the next
/// one is. Build it with [careState].
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

  /// The date this state is for.
  final DateTime today;

  /// The latest time the task was done, as far as is known (null if never):
  /// the schedule counts from its [CareDone.date].
  final CareDone? anchor;

  /// The first task after [anchor] (or the schedule's first task if it was
  /// never done). With nothing done, the tasks are on this day and every
  /// [activeStep] days after it.
  final DateTime start;

  /// A missed task that can still be done (late), or null.
  final DateTime? missed;

  /// A task is due today and isn't done yet.
  final bool dueToday;

  /// Today's task is done (on time).
  final bool doneToday;

  /// The schedule's usual rhythm falls on today, but the [missed] task
  /// takes its place, so there is no second task today.
  final bool suppressedToday;

  /// The next task that isn't done, today or later: today's when
  /// [dueToday], otherwise a later day (after the missed one's days).
  final DateTime next;

  /// The task to show as the current one: the missed task if there is one,
  /// otherwise [next].
  DateTime get nextDue => missed ?? next;

  /// The task log id, e.g. "{plantId}_irrigation".
  String get taskId => careTaskId(plant.id ?? '', type);

  /// [day] at the schedule's time.
  DateTime at(DateTime day) => DateTime(
    day.year,
    day.month,
    day.day,
    schedule.time.hour,
    schedule.time.minute,
  );

  /// The days with a task from [from] to [to] (both dates included),
  /// assuming none of them gets done (as when the app isn't opened). Used
  /// for the reminders: doing a task changes the plant, and the reminders
  /// are planned again.
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

/// The task log id of [type] for plant [plantId].
String careTaskId(String plantId, TaskType type) => switch (type) {
  TaskType.watering => TaskLog.irrigationTaskId(plantId),
  TaskType.fertilizing => TaskLog.fertilizationTaskId(plantId),
};

/// Where [plant]'s task of [type] stands on the date of [now], or null if
/// that schedule is switched off.
///
/// [logs] are task logs by date key (see [TaskLog.dateKey]), usually today's
/// and those of the [missedTaskDays] days before. They are optional: the
/// plant's saved [CareSchedule.lastDone] is enough. When given, they also
/// count ticks not saved on the plant yet (or done before it was kept),
/// and a [CareSchedule.lastDone] that a log no longer shows (un-ticked) is
/// set aside.
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
    plant,
    careTaskId(plant.id ?? '', type),
    today,
    logs,
  );
  final start = anchor == null
      ? _firstDay(schedule, plant)
      : _nextAfter(anchor, schedule);

  final t = _dayNumber(today), s = _dayNumber(start);
  int? missed;
  var dueToday = false;
  int next;
  if (s >= t) {
    next = s;
    dueToday = s == t;
  } else {
    // The latest task on or before today, none done since the anchor.
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

/// [careState] for each saved plant's watering and fertilizing that is
/// switched on.
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

/// The care tasks that were (or will be) on the date of [day], in time
/// order: for a past day, the tasks the user had that day, whether done or
/// not; for a later day, the tasks it will have if none is done before.
///
/// Worked out from what each plant's schedule saves (its start day and the
/// last two times the task was done), without the task logs. Used for the
/// streak: a day with tasks that wasn't completed breaks it.
List<CareTask> dueTasks(List<FarmPlant> plants, DateTime day) {
  final tasks = <CareTask>[
    for (final plant in plants)
      for (final type in TaskType.values)
        if (plant.scheduleOf(type) case final schedule?)
          if (_hadTask(schedule, plant, day))
            CareTask(plant: plant, type: type, at: _atTime(day, schedule)),
  ];
  tasks.sort((a, b) => a.at.compareTo(b.at));
  return tasks;
}

/// Whether the schedule had a task on [day] (see [dueTasks]).
bool _hadTask(CareSchedule schedule, FarmPlant plant, DateTime day) {
  final every = schedule.repeat.days;
  final step = activeStep(every);
  final d = _dayNumber(day);
  bool onChain(DateTime from) {
    final s = _dayNumber(from);
    return d >= s && (d - s) % step == 0;
  }

  // The known times it was done, the latest first. Between two of them,
  // the tasks came every activeStep days from the earlier one.
  final done = [
    if (schedule.lastDone case final last?) last,
    if (schedule.previousDone case final previous?) previous,
  ]..sort((a, b) => a == b ? 0 : (b.isAfter(a) ? 1 : -1));
  for (final (i, time) in done.indexed) {
    final due = _dayNumber(time.due), date = _dayNumber(time.date);
    if (d == due) return true;
    if (d > date) {
      // After the latest time it was done, the schedule's start day
      // counts too (a new repeat); between two done days it can't.
      return onChain(
        i == 0 ? _nextAfter(time, schedule) : _addDays(time.date, every),
      );
    }
    // Between a missed task and the day it was done late: no other task.
    if (d > due) return false;
  }
  return onChain(_firstDay(schedule, plant));
}

/// The latest known time the task [id] was done: the plant's saved
/// [CareSchedule.lastDone] (or [CareSchedule.previousDone] if the latest
/// was un-ticked), or a tick in [logs], whichever is later.
CareDone? _anchor(
  CareSchedule schedule,
  FarmPlant plant,
  String id,
  DateTime today,
  Map<String, TaskLog> logs,
) {
  CareDone? best;
  // A saved time still counts unless its day's log is known and no longer
  // has the task (it was un-ticked and the plant isn't updated yet).
  for (final saved in [schedule.lastDone, schedule.previousDone]) {
    if (saved == null) continue;
    final log = logs[TaskLog.dateKey(saved.due)];
    if (log != null && !log.isDone(id)) continue;
    if (saved.isAfter(best)) best = saved;
  }
  // Ticks in the logs, from the schedule's start (a tick of an older,
  // changed schedule doesn't count).
  final first = schedule.since ?? _dateOnly(plant.updatedAt);
  for (final log in logs.values) {
    final day = TaskLog.parseKey(log.date);
    if (day == null || day.isBefore(first) || day.isAfter(today)) continue;
    CareDone? tick;
    if (log.isCompleted(id)) {
      tick = CareDone(date: day, due: day);
    } else if (log.isDoneLate(id)) {
      // Ticked late before the day was kept: it was at least a day later.
      var on = log.lateDoneOn(id) ?? _addDays(day, 1);
      if (on.isAfter(today)) on = today;
      tick = CareDone(date: on, due: day);
    }
    if (tick != null && tick.isAfter(best)) best = tick;
  }
  return best;
}

/// The first task after the task was done at [done]: [Repeat.days] days
/// after the day it was really done, but not before the schedule's start
/// day (after a new repeat, a day already passed becomes the start day).
DateTime _nextAfter(CareDone done, CareSchedule schedule) {
  final next = _addDays(done.date, schedule.repeat.days);
  final since = schedule.since;
  return since != null && since.isAfter(next) ? since : next;
}

/// The schedule's first task when it was never done: its start day, or for
/// older schedules without one, the first planting-day rhythm day from the
/// plant's last save.
DateTime _firstDay(CareSchedule schedule, FarmPlant plant) =>
    schedule.since ??
    CareSchedule.firstDayFrom(
      plant.plantedAt,
      schedule.repeat.days,
      plant.updatedAt.isAfter(plant.plantedAt)
          ? plant.updatedAt
          : plant.plantedAt,
    );

DateTime _dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

DateTime _addDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

/// Days since 1 January 1970 for the date of [t]. Counted on UTC dates, so
/// a daylight-saving change can't make a day 23 or 25 hours long.
int _dayNumber(DateTime t) =>
    DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// The local date of a [_dayNumber].
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
