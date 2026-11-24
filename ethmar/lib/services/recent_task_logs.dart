import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/daily_task.dart' show missedTaskDays;
import '../models/task_log.dart';
import 'farm_store.dart';

/// The task logs of today and the [missedTaskDays] days before, kept live
/// from Firestore: what careState needs to tell whether today's task and
/// the missed ones are done. Listeners hear about every change.
///
/// A day's log is only in [logs] once it has arrived, so a log that hasn't
/// loaded yet never looks like "nothing done".
class RecentTaskLogs extends ChangeNotifier {
  RecentTaskLogs({DateTime Function()? now}) : _now = now ?? DateTime.now {
    today = _dateOnly(_now());
    _follow();
  }

  final DateTime Function() _now;

  /// The date the logs are for.
  late DateTime today;

  /// The logs that have arrived, by date key (see [TaskLog.dateKey]).
  final Map<String, TaskLog> logs = {};

  final _changes = <StreamSubscription<TaskLog>>[];
  bool _disposed = false;

  static DateTime _dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Moves to the new day's logs if the date has changed since. Call when
  /// the app comes back to the front, and now and then while it's open.
  void checkDay() {
    final now = _dateOnly(_now());
    if (now == today) return;
    today = now;
    _follow();
    notifyListeners();
  }

  void _follow() {
    for (final sub in _changes) {
      sub.cancel();
    }
    _changes.clear();
    logs.clear();
    for (var back = 0; back <= missedTaskDays; back++) {
      final date = TaskLog.dateKey(
        DateTime(today.year, today.month, today.day - back),
      );
      try {
        _changes.add(FarmStore.watchTaskLog(date).listen(
          (log) {
            if (_disposed) return;
            logs[date] = log;
            notifyListeners();
          },
          onError: (Object e) => debugPrint('Could not load a task log: $e'),
        ));
      } catch (e) {
        // No Firebase (e.g. in tests): the plants' saved days still work.
        debugPrint('Could not follow the task log of $date: $e');
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final sub in _changes) {
      sub.cancel();
    }
    super.dispose();
  }
}
