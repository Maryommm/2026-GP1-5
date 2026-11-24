/// What the Edit Plant screen saves: only what the user changed, applied
/// over the plant as it is saved now, never the copy the screen opened
/// with. So a task done on another phone (or another screen) while the
/// form was open isn't undone by saving it.
library;

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/foundation.dart' show mapEquals;

import 'daily_task.dart' show TaskType;
import 'farm_plant.dart';

/// Marks a field to delete in [PlantEdit.updateOver] (Firestore's
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

  /// [PlantEdit.updateOver]'s value for a field to delete.
  static const delete = DeleteField._();

  /// The plant as the screen showed it when it was opened.
  final FarmPlant opened;

  /// The name in the form.
  final String name;

  /// The schedules in the form (repeat and time only), null when switched
  /// off.
  final CareSchedule? irrigation;
  final CareSchedule? fertilization;

  CareSchedule? _draft(TaskType type) => switch (type) {
    TaskType.watering => irrigation,
    TaskType.fertilizing => fertilization,
  };

  /// The fields to update on the plant whose saved fields are [latest], as
  /// Firestore field paths (e.g. `irrigation.time`), with [delete] for a
  /// field to remove. Empty when there is nothing to change.
  ///
  /// Only what the user changed compared to [opened] is written, over
  /// [latest]:
  /// - The name only if it was changed in the form.
  /// - A schedule only if it was switched on or off, or its repeat or time
  ///   changed; the other schedule is left alone.
  /// - A changed schedule is worked out from the saved one (see
  ///   [CareSchedule.savedOver], on [today]), so its done days are the
  ///   latest ones; only its fields that change are written. A repeat
  ///   changed elsewhere is kept when only the time was changed here, and
  ///   the other way round.
  ///
  /// [now] becomes `updatedAt` when anything changes. Throws a
  /// [FormatException] if [latest] isn't a valid plant.
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

  /// [data] with [update] (from [updateOver]) applied, as Firestore applies
  /// it: dotted paths set nested fields, [delete] removes one.
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
      // Switched off here: switch it off, whatever it is now.
      if (before == null || current == null) return const {};
      return {field: null};
    }
    final repeatChanged = before == null || draft.repeat != before.repeat;
    final timeChanged = before == null || draft.time != before.time;
    if (!repeatChanged && !timeChanged) return const {};
    if (current == null) {
      // Off now (or switched on here): a new schedule, from today.
      return {
        field: CareSchedule(draft.repeat, draft.time).savedOver(
          null,
          today,
          lastSaved: saved.updatedAt,
          plantedAt: saved.plantedAt,
        ).toMap(),
      };
    }
    final wanted = CareSchedule(
      repeatChanged ? draft.repeat : current.repeat,
      timeChanged ? draft.time : current.time,
    ).savedOver(
      current,
      today,
      lastSaved: saved.updatedAt,
      plantedAt: saved.plantedAt,
    );
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
