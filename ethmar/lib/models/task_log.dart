/// Which care tasks the user finished on one day.
///
/// Task log: `users/{uid}/taskLog/{yyyy-mm-dd}` (the phone's local date)
///   - completed  List<String>  ids of the tasks done that day, each
///                              "{plantId}_irrigation" or
///                              "{plantId}_fertilization"
library;

/// One day's finished tasks. [date] is the document name, not a field.
class TaskLog {
  const TaskLog({required this.date, this.completed = const []});

  /// "yyyy-mm-dd", see [dateKey].
  final String date;

  /// Ids of the tasks done that day, see [irrigationTaskId] and
  /// [fertilizationTaskId].
  final List<String> completed;

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

  Map<String, Object> toMap() => {'completed': completed};

  /// Builds a log from document [date] and its fields.
  /// Throws a [FormatException] if the saved values aren't valid.
  factory TaskLog.fromMap(String date, Map<String, dynamic> data) {
    final completed = data['completed'];
    if (completed is! List || completed.any((id) => id is! String)) {
      throw FormatException('Invalid task log $date: $data');
    }
    return TaskLog(date: date, completed: List<String>.from(completed));
  }
}
