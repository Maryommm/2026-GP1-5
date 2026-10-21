import 'package:flutter/material.dart';

import 'crop_recommendation.dart' show BiText;

/// What the task asks the user to do.
enum TaskType { watering, fertilizing }

/// Where a task stands today.
enum TaskStatus { completed, overdue, upcoming }

/// One care task for today: which plant, what to do, and when.
///
/// TODO(daily-tasks): Build these from the user's real care schedules.
///   For now the screen shows [sampleTasks].
class DailyTask {
  const DailyTask({
    required this.plant,
    required this.type,
    required this.time,
    required this.status,
  });

  final BiText plant;
  final TaskType type;
  final TimeOfDay time;
  final TaskStatus status;

  /// Made-up tasks to show the design (1 of 3 completed).
  static const sampleTasks = [
    DailyTask(
      plant: BiText('Mint', 'نعناع'),
      type: TaskType.watering,
      time: TimeOfDay(hour: 8, minute: 0),
      status: TaskStatus.completed,
    ),
    DailyTask(
      plant: BiText('Tomato', 'طماطم'),
      type: TaskType.fertilizing,
      time: TimeOfDay(hour: 10, minute: 0),
      status: TaskStatus.overdue,
    ),
    DailyTask(
      plant: BiText('Basil', 'ريحان'),
      type: TaskType.watering,
      time: TimeOfDay(hour: 17, minute: 0),
      status: TaskStatus.upcoming,
    ),
  ];
}
