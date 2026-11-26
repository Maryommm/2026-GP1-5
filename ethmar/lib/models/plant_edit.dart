/// What the Edit Plant screen saves. Only the fields the user changed are
/// written, on top of the plant as it is saved now (not the old copy the
/// screen opened with). So a task done on another phone while the form was
/// open is not lost when saving.
library;

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/foundation.dart' show mapEquals;

import 'daily_task.dart' show TaskType;
import 'farm_plant.dart';

/// Marks a field to delete in [PlantEdit.updateOver] (becomes Firestore's
/// `FieldValue.delete()` when saved).
class DeleteField {
  const DeleteField._();

  @override
  String toString() => 'DeleteField';
}

/// The user's changes on the Edit Plant screen.
class PlantEdit {
  const PlantEdit({
    required this.opened,
    required this.name,
    required this.irrigation,
    required this.fertilization,
  });

  /// The value [PlantEdit.updateOver] uses for a field to delete.
  static const delete = DeleteField._();

  /// The plant as it was when the screen was opened.
  final FarmPlant opened;

  /// The name in the form.
  final String name;

  /// The schedules in the form (repeat and time only). Null when turned off.
  final CareSchedule? irrigation;
  final CareSchedule? fertilization;

  CareSchedule? _draft(TaskType type) => switch (type) {
    TaskType.watering => irrigation,
    TaskType.fertilizing => fertilization,
  };

  /// The fields to update on the plant, where [latest] is the plant as saved
  /// now. Keys are Firestore field paths (e.g. `irrigation.time`) and
  /// [delete] marks a field to remove. Empty when nothing changed.
  ///
  /// Only what the user changed compared to [opened] is written:
  /// - The name, only if it was changed.
  /// - A schedule, only if it was turned on or off, or its repeat or time
  ///   changed. The other schedule is left alone.
  /// - A changed schedule is built from the saved one (see
  ///   [CareSchedule.savedOver] on [today]), so it keeps the latest done
  ///   days. Only the fields that changed are written.
  ///
  /// [now] is saved as `updatedAt` when anything changes. Throws a
  /// [FormatException] if [latest] is not a valid plant.
  Map<String, Object?> updateOver(
    Map<String, dynamic> latest,
    DateTime today,
    DateTime now,
  ) {
    final saved = FarmPlant.fromMap(opened.id ?? '', latest);
    final update = <String, Object?>{};
    if (name != opened.name && name != saved.name) update['name'] = name;
    for (final type in TaskType.values) {
      update.addAll(_scheduleUpdate(type, saved, today));
    }
    if (update.isEmpty) return update;
    update['updatedAt'] = Timestamp.fromDate(now);
    return update;
  }

  /// Returns [data] with [update] (from [updateOver]) applied the same way
  /// Firestore does it: dotted paths set nested fields, [delete] removes one.
  static Map<String, dynamic> applied(
    Map<String, dynamic> data,
    Map<String, Object?> update,
  ) {
    Map<String, dynamic> copy(Map map) => {
      for (final MapEntry(:key, :value) in map.entries)
        key as String: value is Map ? copy(value) : value,
    };
    final result = copy(data);
    for (final MapEntry(:key, :value) in update.entries) {
      final path = key.split('.');
      var map = result;
      for (final part in path.take(path.length - 1)) {
        map = map[part] as Map<String, dynamic>;
      }
      if (value is DeleteField) {
        map.remove(path.last);
      } else {
        map[path.last] = value;
      }
    }
    return result;
  }

  Map<String, Object?> _scheduleUpdate(
    TaskType type,
    FarmPlant saved,
    DateTime today,
  ) {
    final field = switch (type) {
      TaskType.watering => 'irrigation',
      TaskType.fertilizing => 'fertilization',
    };
    final draft = _draft(type);
    final before = opened.scheduleOf(type);
    final current = saved.scheduleOf(type);

    if (draft == null) {
      // Turned off here, so turn it off no matter what it is now.
      if (before == null || current == null) return const {};
      return {field: null};
    }
    final repeatChanged = before == null || draft.repeat != before.repeat;
    final timeChanged = before == null || draft.time != before.time;
    if (!repeatChanged && !timeChanged) return const {};
    if (current == null) {
      // It is off now (or was turned on here), so start a new schedule today.
      return {
        field: CareSchedule(
          draft.repeat,
          draft.time,
          since: draft.since,
        ).savedOver(null, today).toMap(),
      };
    }
    final wanted = CareSchedule(
      repeatChanged ? draft.repeat : current.repeat,
      timeChanged ? draft.time : current.time,
      since: draft.since,
    ).savedOver(current, today);
    final from = current.toMap(), to = wanted.toMap();
    final update = <String, Object?>{};
    for (final key in {...from.keys, ...to.keys}) {
      final a = from[key], b = to[key];
      final same = a is Map && b is Map ? mapEquals(a, b) : a == b;
      if (!same) update['$field.$key'] = b ?? delete;
    }
    return update;
  }
}
