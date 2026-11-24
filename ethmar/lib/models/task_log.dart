/// Which care tasks the user finished on one day.
///
/// Task log: `users/{uid}/taskLog/{yyyy-mm-dd}` (the phone's local date)
///   - completed  List<String>  ids of the tasks done that day, each
///                              "{plantId}_irrigation" or
///                              "{plantId}_fertilization"
///   - late       List<String>  ids of that day's tasks done after the day
///                              was over (optional). They don't count for
///                              the streak.
///   - lateOn     Map           task id → "yyyy-mm-dd", the day each late
///                              task was really done (optional; missing
///                              for tasks done late before it was kept)
library;

/// One day's finished tasks. [date] is the document name, not a field.
class TaskLog {
  const TaskLog({
    required this.date,
    this.completed = const [],
    this.late = const [],
    this.lateOn = const {},
  });

  /// "yyyy-mm-dd", see [dateKey].
  final String date;

  /// Ids of the tasks done that day, see [irrigationTaskId] and
  /// [fertilizationTaskId].
  final List<String> completed;

  /// Ids of the tasks of that day done late, on a later day (from the
  /// missed tasks on Daily Tasks).
  final List<String> late;

  /// The day ("yyyy-mm-dd") each task in [late] was really done.
  final Map<String, String> lateOn;

  /// The document name for [day], in the phone's local time: "2026-10-30".
  static String dateKey(DateTime day) {
    final local = day.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '${local.year}-$m-$d';
  }

  /// The local date of a [dateKey], or null if [key] isn't one.
  static DateTime? parseKey(String? key) {
    if (key == null) return null;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  /// The id of watering plant [plantId].
  static String irrigationTaskId(String plantId) => '${plantId}_irrigation';

  /// The id of fertilizing plant [plantId].
  static String fertilizationTaskId(String plantId) =>
      '${plantId}_fertilization';

  bool isCompleted(String taskId) => completed.contains(taskId);

  bool isDoneLate(String taskId) => late.contains(taskId);

  /// Done on that day or later.
  bool isDone(String taskId) => isCompleted(taskId) || isDoneLate(taskId);

  /// The day the late task [taskId] was really done, or null if unknown.
  DateTime? lateDoneOn(String taskId) => parseKey(lateOn[taskId]);

  Map<String, Object> toMap() => {
    'completed': completed,
    'late': late,
    if (lateOn.isNotEmpty) 'lateOn': lateOn,
  };

  /// Builds a log from document [date] and its fields.
  /// Throws a [FormatException] if the saved values aren't valid.
  factory TaskLog.fromMap(String date, Map<String, dynamic> data) {
    final completed = data['completed'];
    final late = data['late'] ?? const [];
    final lateOn = data['lateOn'] ?? const {};
    bool idList(Object? v) => v is List && v.every((id) => id is String);
    if (!idList(completed) || !idList(late) || lateOn is! Map) {
      throw FormatException('Invalid task log $date: $data');
    }
    return TaskLog(
      date: date,
      completed: List<String>.from(completed as List),
      late: List<String>.from(late as List),
      lateOn: {
        for (final e in lateOn.entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
      },
    );
  }
}
