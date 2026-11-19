import 'package:flutter/material.dart';

import 'care_task.dart';
import 'crop_recommendation.dart' show BiText;
import 'farm_plant.dart';
import 'task_log.dart';

/// How many days a missed task stays on Daily Tasks: a task of Monday shows
/// under "Missed tasks" on Tuesday, Wednesday and Thursday, then goes.
const missedTaskDays = 3;

/// The tasks of [day] for the saved [plants], in time order, ticked from
/// [log]. Used by Daily Tasks and by Home's "Today's Tasks" card.
List<DailyTask> tasksForDay(
  List<FarmPlant> plants,
  DateTime day,
  TaskLog log,
  DateTime now,
) => [
  for (final task in dueTasks(_saved(plants), day))
    DailyTask.from(task, log, now),
];

/// The tasks of the last [missedTaskDays] days before [today] that weren't
/// done on their day, the most recent first. [logs] holds the task log of
/// each of those days, by date key; a day without one counts as empty.
///
/// A task done late stays in the list as [TaskStatus.doneLate], so it can
/// be un-ticked. Days before the plant was added to the app are skipped:
/// a plant planted last week but added today missed nothing.
List<DailyTask> missedTasks(
  List<FarmPlant> plants,
  DateTime today,
  Map<String, TaskLog> logs,
) {
  final missed = <DailyTask>[];
  for (var back = 1; back <= missedTaskDays; back++) {
    final day = DateTime(today.year, today.month, today.day - back);
    final key = TaskLog.dateKey(day);
    final log = logs[key] ?? TaskLog(date: key);
    for (final task in dueTasks(_saved(plants), day)) {
      if (day.isBefore(_dateOnly(task.plant.createdAt))) continue;
      final id = DailyTask.taskId(task);
      if (log.isCompleted(id)) continue;
      missed.add(DailyTask(
        id: id,
        plant: BiText(task.plant.name, task.plant.name),
        type: task.type,
        day: day,
        time: TimeOfDay.fromDateTime(task.at),
        status: log.isDoneLate(id) ? TaskStatus.doneLate : TaskStatus.missed,
      ));
    }
  }
  return missed;
}

List<FarmPlant> _saved(List<FarmPlant> plants) => [
  for (final p in plants)
    if (p.id != null) p,
];

DateTime _dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

/// What the task asks the user to do.
enum TaskType { watering, fertilizing }

/// Where a task stands.
///
/// Today's tasks are [upcoming] before their time, [due] once it has passed,
/// and [completed] when ticked. A task only becomes [missed] after midnight,
/// when its day is over; ticking it then makes it [doneLate], which doesn't
/// count for the streak.
enum TaskStatus { completed, due, upcoming, missed, doneLate }

/// One care task as the Daily Tasks page shows it: which plant, what to do,
/// on which day and at what time, and where it stands.
class DailyTask {
  const DailyTask({
    required this.id,
    required this.plant,
    required this.type,
    required this.day,
    required this.time,
    required this.status,
  });

  /// The task of [task]'s day: completed if [log] has it, otherwise due once
  /// its time has passed at [now], and upcoming before that.
  factory DailyTask.from(CareTask task, TaskLog log, DateTime now) {
    final id = taskId(task);
    return DailyTask(
      id: id,
      // The user's own name for the plant, the same in both languages.
      plant: BiText(task.plant.name, task.plant.name),
      type: task.type,
      day: _dateOnly(task.at),
      time: TimeOfDay.fromDateTime(task.at),
      status: log.isCompleted(id)
          ? TaskStatus.completed
          : task.at.isBefore(now)
          ? TaskStatus.due
          : TaskStatus.upcoming,
    );
  }

  /// The task's id in the task log, e.g. "{plantId}_irrigation".
  static String taskId(CareTask task) => switch (task.type) {
    TaskType.watering => TaskLog.irrigationTaskId(task.plant.id!),
    TaskType.fertilizing => TaskLog.fertilizationTaskId(task.plant.id!),
  };

  final String id;
  final BiText plant;
  final TaskType type;

  /// The date the task was for (no time).
  final DateTime day;
  final TimeOfDay time;
  final TaskStatus status;

  /// Ticked, on time or late.
  bool get done =>
      status == TaskStatus.completed || status == TaskStatus.doneLate;

  /// From an earlier day (under "Missed tasks").
  bool get isPast => status == TaskStatus.missed || status == TaskStatus.doneLate;

  /// Unique on the page: the same plant can have a task today and a missed
  /// one from yesterday, with the same task id.
  String get key => '${TaskLog.dateKey(day)}/$id';
}
