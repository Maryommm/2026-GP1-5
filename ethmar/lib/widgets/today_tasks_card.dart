import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/daily_task.dart';
import '../screens/daily_tasks_screen.dart';
import '../services/farm_store.dart';
import '../services/recent_task_logs.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'page_routes.dart';

/// The Today's Tasks part of Home's tasks-and-streak card: the title,
/// today's progress as a sunny bar (with a green tick once all are done),
/// "1/3 completed" below it, and a chevron at the end.
/// The whole part opens Daily Tasks, where the tasks themselves are listed.
/// It has no card of its own; Home draws the card around it.
class TodayTasksCard extends StatefulWidget {
  const TodayTasksCard({super.key});

  @override
  State<TodayTasksCard> createState() => _TodayTasksCardState();
}

class _TodayTasksCardState extends State<TodayTasksCard> {
  /// Today's log and those of the missed days, as Daily Tasks uses them,
  /// so both count the same tasks.
  final _logs = RecentTaskLogs();
  late final AppLifecycleListener _lifecycle;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _logs.addListener(_refresh);
    _lifecycle = AppLifecycleListener(onResume: _onClock);
    FarmStore.plants.addListener(_refresh);
    // Once a minute: tasks turn overdue, and a new day starts at midnight.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) => _onClock());
  }

  @override
  void dispose() {
    _logs.dispose();
    _lifecycle.dispose();
    _clock?.cancel();
    FarmStore.plants.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onClock() {
    _logs.checkDay();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final tasks = tasksForDay(
      FarmStore.plants.value,
      _logs.today,
      _logs.logs,
      DateTime.now(),
    );
    final total = tasks.length;
    final done = tasks.where((t) => t.status == TaskStatus.completed).length;

    final progress = total == 0 ? 0.0 : done / total;
    final allDone = total > 0 && done == total;

    return Semantics(
      button: true,
      label:
          '${s.todaysTasks}. '
          '${total == 0 ? s.noTasksToday : s.dailyProgressOf(done, total)}',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () =>
              Navigator.of(context).push(riseRoute(const DailyTasksScreen())),
          splashColor: AppColors.forest.withValues(alpha: 0.08),
          highlightColor: AppColors.forest.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 6, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        s.todaysTasks,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title(context)
                            .copyWith(fontSize: 18, height: 1.2),
                      ),
                      const SizedBox(height: 4),
                      // As tall as the tick, with or without it, so the card
                      // does not grow when the last task is done.
                      SizedBox(
                        height: 20,
                        child: Row(
                          children: [
                            // Today's progress as a sunny bar that fills
                            // smoothly.
                            Expanded(
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(end: progress),
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, _) => ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: value,
                                    minHeight: 8,
                                    color: AppColors.sun,
                                    backgroundColor: AppColors.sunTint,
                                  ),
                                ),
                              ),
                            ),
                            // Every task done: a green tick at the bar's end.
                            if (allDone) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: AppColors.success,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        total == 0
                            ? s.homeNoTasksShort
                            : s.homeTasksDoneOf(done, total),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.small(
                          context,
                          color: AppColors.textPrimary,
                        ).copyWith(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // "Opens more", centred on the whole tasks part, at its end
                // (like a list row). chevron_right flips in Arabic.
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 26,
                  color: AppColors.textPrimary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
