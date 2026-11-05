import 'daily_task.dart' show TaskType;
import 'farm_plant.dart';

/// One care task on a given day: which plant, what to do, and when.
class CareTask {
  const CareTask({required this.plant, required this.type, required this.at});

  final FarmPlant plant;
  final TaskType type;

  /// The alarm time: the day of the task at the schedule's time.
  final DateTime at;
}

/// The care tasks due on the date of [day], in time order.
///
/// A schedule starts on the day the plant was planted and repeats every
/// `repeat.days` days at its time, the same way as [CareSchedule.nextAfter].
/// Schedules that are switched off (null) give no tasks, and nothing is due
/// before the planting day.
///
/// Shared by the Daily Tasks page and the care reminders, so both always
/// agree on what is due.
List<CareTask> dueTasks(List<FarmPlant> plants, DateTime day) {
  final tasks = <CareTask>[
    for (final plant in plants)
      for (final type in TaskType.values)
        if (_isDue(_scheduleOf(plant, type), plant.plantedAt, day))
          CareTask(
            plant: plant,
            type: type,
            at: _atTime(day, _scheduleOf(plant, type)!),
          ),
  ];
  tasks.sort((a, b) => a.at.compareTo(b.at));
  return tasks;
}

CareSchedule? _scheduleOf(FarmPlant plant, TaskType type) => switch (type) {
  TaskType.watering => plant.irrigation,
  TaskType.fertilizing => plant.fertilization,
};

bool _isDue(CareSchedule? schedule, DateTime plantedAt, DateTime day) {
  if (schedule == null) return false;
  final days = _daysBetween(plantedAt, day);
  return days >= 0 && days % schedule.repeat.days == 0;
}

/// Whole calendar days from [from] to [to]. Counted on UTC dates, so a
/// daylight-saving change can't make a day 23 or 25 hours long.
int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

DateTime _atTime(DateTime day, CareSchedule schedule) => DateTime(
  day.year,
  day.month,
  day.day,
  schedule.time.hour,
  schedule.time.minute,
);
