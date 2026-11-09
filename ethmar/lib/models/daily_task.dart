import 'package:flutter/material.dart';

import 'care_task.dart';
import 'crop_recommendation.dart' show BiText;
import 'farm_plant.dart';
import 'task_log.dart';

/// The tasks of [day] for the saved [plants], in time order, ticked from
/// [log]. Used by Daily Tasks and by Home's "Today's Tasks" card.
List<DailyTask> tasksForDay(
  List<FarmPlant> plants,
  DateTime day,
  TaskLog log,
  DateTime now,
) => [
  for (final task in dueTasks([
    for (final p in plants)
      if (p.id != null) p,
  ], day))
    DailyTask.from(task, log, now),
];

/// What the task asks the user to do.
enum TaskType { watering, fertilizing }

/// Where a task stands today.
enum TaskStatus { completed, overdue, upcoming }

/// One care task for today, as the Daily Tasks page shows it: which plant,
/// what to do, when, and where it stands.
class DailyTask {
  const DailyTask({
    required this.id,
    required this.plant,
    required this.type,
    required this.time,
    required this.status,
  });

  /// Today's task for [task]: completed if [log] has it, otherwise overdue
  /// once its time has passed at [now], and upcoming before that.
  factory DailyTask.from(CareTask task, TaskLog log, DateTime now) {
    final id = taskId(task);
    return DailyTask(
      id: id,
      // The user's own name for the plant, the same in both languages.
      plant: BiText(task.plant.name, task.plant.name),
      type: task.type,
      time: TimeOfDay.fromDateTime(task.at),
      status: log.isCompleted(id)
          ? TaskStatus.completed
          : task.at.isBefore(now)
          ? TaskStatus.overdue
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
  final TimeOfDay time;
  final TaskStatus status;
}
