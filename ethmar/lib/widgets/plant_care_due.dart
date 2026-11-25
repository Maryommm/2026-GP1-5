import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/care_task.dart';
import '../models/daily_task.dart' show TaskType;
import '../models/farm_plant.dart';
import '../models/task_log.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'care_icon.dart';

/// What a plant's watering or fertilizing line says, from [state] (see
/// careState, the one place that decides when tasks are due), on the date
/// of [now]: "Next watering: Tomorrow", or, while a missed task can still
/// be done, "Watering missed: Yesterday". A missed task is never shown as
/// done or as a later one.
String careDueText(S s, CareState state, DateTime now) {
  final watering = state.type == TaskType.watering;
  final today = _dayNumber(now);
  if (state.missed case final missed?) {
    final when = s.careDaysAgo(today - _dayNumber(missed));
    return watering ? s.careMissedWatering(when) : s.careMissedFertilizing(when);
  }
  final when = s.careInDays(_dayNumber(state.next) - today);
  return watering ? s.careNextWatering(when) : s.careNextFertilizing(when);
}

/// Calendar days (UTC dates), so a daylight-saving change can't make a day
/// 23 or 25 hours long.
int _dayNumber(DateTime t) =>
    DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// Under a plant's name: its next watering, then its next fertilizing, each
/// with its icon, for the schedules that are on; "No care tasks scheduled"
/// when neither is. [logs] are the recent task logs (see RecentTaskLogs),
/// so a task ticked today counts straight away.
class PlantCareDue extends StatelessWidget {
  const PlantCareDue({
    super.key,
    required this.plant,
    required this.logs,
    required this.now,
  });

  final FarmPlant plant;
  final Map<String, TaskLog> logs;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final lines = [
      for (final type in TaskType.values)
        if (careState(plant, type, now, logs: logs) case final state?)
          _Line(
            key: Key('careDue_${type.name}'),
            type: type,
            text: careDueText(s, state, now),
            missed: state.missed != null,
          ),
    ];
    if (lines.isEmpty) {
      return Text(
        s.careNone,
        key: const Key('careDue_none'),
        style: AppText.small(context),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          lines[i],
        ],
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    super.key,
    required this.type,
    required this.text,
    required this.missed,
  });

  final TaskType type;
  final String text;
  final bool missed;

  @override
  Widget build(BuildContext context) {
    final color = missed ? AppColors.error : AppColors.textPrimary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: CareTypeIcon(
            type,
            size: 14,
            color: missed ? AppColors.error : AppColors.seaDeep,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: AppText.small(
              context,
              color: color,
            ).copyWith(fontWeight: missed ? FontWeight.w600 : FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
