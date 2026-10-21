import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/daily_task.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/backgrounds.dart';
import '../widgets/centered_header.dart';
import '../widgets/character.dart';
import '../widgets/entrance.dart';

/// Today's care tasks: the date, a progress card, and one card per task.
///
/// UI only for now: it shows [DailyTask.sampleTasks] unless [tasks] is
/// given. Ticking a task only changes what this screen shows; nothing is
/// saved.
class DailyTasksScreen extends StatefulWidget {
  const DailyTasksScreen({super.key, this.tasks});

  final List<DailyTask>? tasks;

  @override
  State<DailyTasksScreen> createState() => _DailyTasksScreenState();
}

class _DailyTasksScreenState extends State<DailyTasksScreen> {
  // Tasks in time order.
  late final List<DailyTask> _tasks = [
    ...(widget.tasks ?? DailyTask.sampleTasks),
  ]..sort((a, b) => _minutes(a.time).compareTo(_minutes(b.time)));

  // Which tasks are ticked, by index in [_tasks]. Starts from each task's
  // status; changes stay on this screen only.
  late final List<bool> _done = [
    for (final t in _tasks) t.status == TaskStatus.completed,
  ];

  static int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  /// A ticked task shows as completed; otherwise it keeps its own status.
  TaskStatus _statusOf(int i) =>
      _done[i] ? TaskStatus.completed : _uncheckedStatus(_tasks[i]);

  static TaskStatus _uncheckedStatus(DailyTask t) =>
      t.status == TaskStatus.completed ? TaskStatus.upcoming : t.status;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final doneCount = _done.where((d) => d).length;
    return Scaffold(
      body: LeafPrintBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EthmarCenteredHeader(title: s.navDailyTasks),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  0,
                  24,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  Entrance(
                    child: Column(
                      children: [
                        Text(
                          s.dailyTasksSubtitle,
                          textAlign: TextAlign.center,
                          style: AppText.accent(context, size: 17),
                        ),
                        const SizedBox(height: 8),
                        // Thamoor planting a seedling, kept small.
                        const ExcludeSemantics(
                          child: EthmarCharacter(
                            name: 'ethmar_thamoor_planting',
                            height: 120,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.todayDate(DateTime.now()),
                          textAlign: TextAlign.center,
                          style: AppText.body(context).copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Entrance(
                    delay: const Duration(milliseconds: 100),
                    child: _ProgressCard(done: doneCount, total: _tasks.length),
                  ),
                  const SizedBox(height: 24),
                  // Section title with the number of tasks on the other side.
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.todaysTasks,
                          style: AppText.title(context).copyWith(fontSize: 20),
                        ),
                      ),
                      Text(
                        '${_tasks.length}',
                        style: AppText.label(context, color: AppColors.earthBrown)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < _tasks.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    Entrance(
                      delay: Duration(milliseconds: 150 + 50 * i),
                      offset: 16,
                      child: _TaskCard(
                        task: _tasks[i],
                        status: _statusOf(i),
                        done: _done[i],
                        onToggle: () => setState(() => _done[i] = !_done[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft green card: "Daily Progress", "1 / 3", a bar and a short line.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.done, required this.total});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final value = total == 0 ? 0.0 : done / total;
    return Semantics(
      label: '${s.dailyProgress}: ${s.dailyProgressOf(done, total)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: AppColors.featureCard,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.dailyProgress,
                    style: AppText.title(context).copyWith(fontSize: 18),
                  ),
                ),
                Text(
                  '$done / $total',
                  // Keep "1 / 3" in this order in Arabic too.
                  textDirection: TextDirection.ltr,
                  style: AppText.label(context)
                      .copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                color: AppColors.forest,
                backgroundColor: AppColors.surface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              s.dailyProgressOf(done, total),
              style: AppText.small(context).copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// One task: type icon, "Mint · Watering" with its time below, the status
/// pill across from the name, and a small tick control at the end.
class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.status,
    required this.done,
    required this.onToggle,
  });
  final DailyTask task;
  final TaskStatus status;
  final bool done;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final (icon, typeLabel) = switch (task.type) {
      TaskType.watering => (Icons.water_drop_rounded, s.taskWatering),
      TaskType.fertilizing => (Icons.compost_rounded, s.taskFertilizing),
    };
    final time = MaterialLocalizations.of(context).formatTimeOfDay(task.time);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Task type icon.
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.featureCard,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: AppColors.forest),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name and type on one line, the status pill across from it.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${task.plant.of(context)} · $typeLabel',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.label(context)
                            .copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusPill(status: status),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: AppText.small(context).copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Separate tick control; display only, nothing is saved.
          Semantics(
            label: s.taskMarkDone,
            child: Checkbox(
              value: done,
              onChanged: (_) => onToggle(),
              shape: const CircleBorder(),
              activeColor: AppColors.forest,
              side: const BorderSide(color: AppColors.border, width: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Coloured pill: Completed (green), Overdue (red), Upcoming (beige).
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final (label, fg, bg) = switch (status) {
      TaskStatus.completed =>
        (s.statusCompleted, AppColors.success, AppColors.successTint),
      TaskStatus.overdue =>
        (s.statusOverdue, AppColors.error, AppColors.errorTint),
      TaskStatus.upcoming =>
        (s.statusUpcoming, AppColors.earthBrown, AppColors.backgroundAlt),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppText.small(context, color: fg)
            .copyWith(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
