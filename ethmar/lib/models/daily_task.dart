import 'package:flutter/material.dart';

import 'care_task.dart';
import 'crop_recommendation.dart' show BiText;
import 'farm_plant.dart';
import 'task_log.dart';

/// How many days a missed task stays on Daily Tasks. For example, a task
/// from Monday shows under "Missed tasks" on Tuesday, Wednesday and
/// Thursday, then it disappears.
const missedTaskDays = 3;

/// Today's tasks for [plants], sorted by time: each plant's watering and
/// fertilizing due on [today], plus the ones already done today. A plant
/// with a missed task of the same type gets no second task today.
/// [logs] are task logs by date key (today's and, ideally, the
/// [missedTaskDays] days before). Daily Tasks and Home's "Today's Tasks"
/// card both use this so they show the same tasks.
List<DailyTask> tasksForDay(
  List<FarmPlant> plants,
  DateTime today,
  Map<String, TaskLog> logs,
  DateTime now,
) {
  final day = _dateOnly(today);
  final key = TaskLog.dateKey(day);
  final log = logs[key] ?? TaskLog(date: key);
  final tasks = <DailyTask>[];
  for (final state in careStates(plants, day, logs: logs)) {
    final done = state.doneToday || log.isCompleted(state.taskId);
    if (!done && !state.dueToday) continue;
    final at = state.at(day);
    tasks.add(
      DailyTask(
        id: state.taskId,
        plantId: state.plant.id!,
        // The user's own name for the plant, the same in both languages.
        plant: BiText(state.plant.name, state.plant.name),
        type: state.type,
        day: day,
        time: state.schedule.time,
        status: done
            ? TaskStatus.completed
            : at.isBefore(now)
            ? TaskStatus.due
            : TaskStatus.upcoming,
      ),
    );
  }
  tasks.sort((a, b) => _minutes(a.time).compareTo(_minutes(b.time)));
  return tasks;
}

/// The missed tasks that can still be done, newest first. For each plant's
/// watering and fertilizing, this is the task from the last
/// [missedTaskDays] days that wasn't done. Tasks done late in those days
/// are included as [TaskStatus.doneLate] so they can be un-ticked.
/// [logs] holds the task logs of today and those days, by date key.
///
/// Days before the plant was added to the app are skipped, so a plant
/// planted last week but added today has no missed tasks.
List<DailyTask> missedTasks(
  List<FarmPlant> plants,
  DateTime today,
  Map<String, TaskLog> logs,
) {
  final day = _dateOnly(today);
  final missed = <DailyTask>[];
  for (final state in careStates(plants, day, logs: logs)) {
    final added = _dateOnly(state.plant.createdAt);
    final first = state.schedule.since;
    DailyTask task(DateTime on, TaskStatus status) => DailyTask(
      id: state.taskId,
      plantId: state.plant.id!,
      plant: BiText(state.plant.name, state.plant.name),
      type: state.type,
      day: on,
      time: state.schedule.time,
      status: status,
    );
    if (state.missed case final on? when !on.isBefore(added)) {
      missed.add(task(on, TaskStatus.missed));
    }
    // Done days the schedule still counts from, even if they are older than
    // its start day (kept when only the repeat changed).
    final kept = {
      state.schedule.lastDone?.due,
      state.schedule.previousDone?.due,
    };
    for (var back = 1; back <= missedTaskDays; back++) {
      final on = DateTime(day.year, day.month, day.day - back);
      if (on.isBefore(added)) continue;
      if (on.isBefore(first) && !kept.contains(on)) continue;
      if (logs[TaskLog.dateKey(on)]?.isDoneLate(state.taskId) ?? false) {
        missed.add(task(on, TaskStatus.doneLate));
      }
    }
  }
  missed.sort((a, b) {
    final byDay = b.day.compareTo(a.day);
    return byDay != 0 ? byDay : _minutes(a.time).compareTo(_minutes(b.time));
  });
  return missed;
}

int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

DateTime _dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

/// What the task asks the user to do.
enum TaskType { watering, fertilizing }

/// The status of a task.
///
/// Today's tasks are [upcoming] before their time, [due] after their time,
/// and [completed] when ticked. A task becomes [missed] only after
/// midnight. Ticking a missed task makes it [doneLate], which doesn't count
/// for the streak.
enum TaskStatus { completed, due, upcoming, missed, doneLate }

/// One care task as shown on the Daily Tasks page: the plant, what to do,
/// the day and time, and its status.
class DailyTask {
  const DailyTask({
    required this.id,
    required this.plantId,
    required this.plant,
    required this.type,
    required this.day,
    required this.time,
    required this.status,
  });

  /// Creates the task for [task]'s day: completed if [log] has it, due if its
  /// time has passed at [now], otherwise upcoming.
  factory DailyTask.from(CareTask task, TaskLog log, DateTime now) {
    final id = taskId(task);
    return DailyTask(
      id: id,
      plantId: task.plant.id!,
      // The user's own name for the plant, used in both languages.
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

  /// The task's id in the task log, for example "{plantId}_irrigation".
  static String taskId(CareTask task) => careTaskId(task.plant.id!, task.type);

  final String id;

  /// The plant's Firestore document id.
  final String plantId;
  final BiText plant;
  final TaskType type;

  /// The date the task was for (without the time).
  final DateTime day;
  final TimeOfDay time;
  final TaskStatus status;

  /// True if it was ticked, on time or late.
  bool get done =>
      status == TaskStatus.completed || status == TaskStatus.doneLate;

  /// From an earlier day (under "Missed tasks").
  bool get isPast =>
      status == TaskStatus.missed || status == TaskStatus.doneLate;

  /// A unique key on the page. The same plant can have a task today and a
  /// missed one from yesterday with the same task id, so the date is added.
  String get key => '${TaskLog.dateKey(day)}/$id';
}
