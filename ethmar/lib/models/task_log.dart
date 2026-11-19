/// Which care tasks the user finished on one day.
///
/// Task log: `users/{uid}/taskLog/{yyyy-mm-dd}` (the phone's local date)
///   - completed  List<String>  ids of the tasks done that day, each
///                              "{plantId}_irrigation" or
///                              "{plantId}_fertilization"
///   - late       List<String>  ids of that day's tasks done after the day
///                              was over (optional). They don't count for
///                              the streak.
library;

/// One day's finished tasks. [date] is the document name, not a field.
class TaskLog {
  const TaskLog({
    required this.date,
    this.completed = const [],
    this.late = const [],
  });

  /// "yyyy-mm-dd", see [dateKey].
  final String date;

  /// Ids of the tasks done that day, see [irrigationTaskId] and
  /// [fertilizationTaskId].
  final List<String> completed;

  /// Ids of the tasks of that day done late, on a later day (from the
  /// missed tasks on Daily Tasks).
  final List<String> late;

  /// The document name for [day], in the phone's local time: "2026-10-30".
  static String dateKey(DateTime day) {
    final local = day.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '${local.year}-$m-$d';
  }

  /// The id of watering plant [plantId].
  static String irrigationTaskId(String plantId) => '${plantId}_irrigation';

  /// The id of fertilizing plant [plantId].
  static String fertilizationTaskId(String plantId) =>
      '${plantId}_fertilization';

  bool isCompleted(String taskId) => completed.contains(taskId);

  bool isDoneLate(String taskId) => late.contains(taskId);

  Map<String, Object> toMap() => {'completed': completed, 'late': late};

  /// Builds a log from document [date] and its fields.
  /// Throws a [FormatException] if the saved values aren't valid.
  factory TaskLog.fromMap(String date, Map<String, dynamic> data) {
    final completed = data['completed'];
    final late = data['late'] ?? const [];
    bool idList(Object? v) => v is List && v.every((id) => id is String);
    if (!idList(completed) || !idList(late)) {
      throw FormatException('Invalid task log $date: $data');
    }
    return TaskLog(
      date: date,
      completed: List<String>.from(completed as List),
      late: List<String>.from(late as List),
    );
  }
}
