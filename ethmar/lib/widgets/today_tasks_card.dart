import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/daily_task.dart';
import '../models/task_log.dart';
import '../screens/daily_tasks_screen.dart';
import '../services/farm_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'page_routes.dart';

/// Home's Today's Tasks card (current layout): a short white card with
/// today's progress as a sunny ring, the title and a dark arrow button.
/// The whole card opens Daily Tasks (which used to be a tab), where the
/// tasks themselves are listed. Home sets its size; it fills it.
class TodayTasksCard extends StatefulWidget {
  const TodayTasksCard({super.key});

  @override
  State<TodayTasksCard> createState() => _TodayTasksCardState();
}

class _TodayTasksCardState extends State<TodayTasksCard> {
  DateTime _today = _dateOnly(DateTime.now());
  TaskLog _log = TaskLog(date: TaskLog.dateKey(DateTime.now()));
  StreamSubscription<TaskLog>? _logChanges;
  late final AppLifecycleListener _lifecycle;
  Timer? _clock;

  static DateTime _dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

  @override
  void initState() {
    super.initState();
    _followLog();
    _lifecycle = AppLifecycleListener(onResume: _onClock);
    FarmStore.plants.addListener(_refresh);
    // Once a minute: tasks turn overdue, and a new day starts at midnight.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) => _onClock());
  }

  @override
  void dispose() {
    _logChanges?.cancel();
    _lifecycle.dispose();
    _clock?.cancel();
    FarmStore.plants.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onClock() {
    final today = _dateOnly(DateTime.now());
    if (today != _today) {
      _today = today;
      _followLog();
    }
    _refresh();
  }

  void _followLog() {
    _logChanges?.cancel();
    final date = TaskLog.dateKey(_today);
    _log = TaskLog(date: date);
    _logChanges = FarmStore.watchTaskLog(date).listen(
      (log) {
        if (mounted) setState(() => _log = log);
      },
      onError: (Object e) => debugPrint('Could not load the task log: $e'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final tasks = tasksForDay(
      FarmStore.plants.value,
      _today,
      _log,
      DateTime.now(),
    );
    final total = tasks.length;
    final done = tasks.where((t) => t.status == TaskStatus.completed).length;

    return Semantics(
      button: true,
      label: '${s.todaysTasks}. ${s.dailyProgressOf(done, total)}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.forest.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context)
                .push(riseRoute(const DailyTasksScreen())),
            splashColor: AppColors.forest.withValues(alpha: 0.08),
            highlightColor: AppColors.forest.withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 8, 10),
              child: Row(
                children: [
                  _ProgressRing(done: done, total: total),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.todaysTasks,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.title(context).copyWith(
                        fontSize: 15,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Says "this opens something", like a button would.
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: AppColors.forest,
                      shape: BoxShape.circle,
                    ),
                    // arrow_forward points the other way in Arabic.
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: AppColors.onForest,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Today's progress as a sunny ring around "done/total" on the white card.
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.done, required this.total});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        fit: StackFit.expand,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: total == 0 ? 0 : done / total),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => CircularProgressIndicator(
              value: value,
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              color: AppColors.sun,
              backgroundColor: AppColors.sunTint,
            ),
          ),
          Center(
            child: total == 0
                ? const Icon(Icons.eco_rounded, color: AppColors.forest)
                : Text(
                    '$done/$total',
                    // Keep "1/3" in this order in Arabic too.
                    textDirection: TextDirection.ltr,
                    style: AppText.label(
                      context,
                    ).copyWith(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
          ),
        ],
      ),
    );
  }
}
