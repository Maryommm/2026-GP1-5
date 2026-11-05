import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/care_task.dart';
import '../models/daily_task.dart';
import '../models/farm_plant.dart';
import '../models/task_log.dart';
import '../services/farm_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_header.dart' show EthmarToastType, showEthmarToast;
import '../widgets/backgrounds.dart';
import '../widgets/centered_header.dart';
import '../widgets/character.dart';
import '../widgets/entrance.dart';

/// Today's care tasks: the date, a progress card, and one card per task.
///
/// The tasks come from the user's plants and their care schedules
/// ([dueTasks]); ticking one saves it in today's task log and updates the
/// streak (see [FarmStore.setTaskDone]).
class DailyTasksScreen extends StatefulWidget {
  const DailyTasksScreen({super.key});

  @override
  State<DailyTasksScreen> createState() => _DailyTasksScreenState();
}

class _DailyTasksScreenState extends State<DailyTasksScreen> {
  DateTime _today = _dateOnly(DateTime.now());
  TaskLog _log = TaskLog(date: TaskLog.dateKey(DateTime.now()));
  StreamSubscription<TaskLog>? _logChanges;
  late final AppLifecycleListener _lifecycle;
  Timer? _midnight;

  // Ticks shown right away, before Firestore confirms them: task id -> done.
  final _pending = <String, bool>{};

  static DateTime _dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

  @override
  void initState() {
    super.initState();
    _followLog();
    // Opened again on a new day (or after a while): show that day's tasks
    // and refresh which ones are overdue.
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    FarmStore.plants.addListener(_refresh);
    _scheduleMidnight();
  }

  @override
  void dispose() {
    _logChanges?.cancel();
    _lifecycle.dispose();
    _midnight?.cancel();
    FarmStore.plants.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  /// Switches to the new day's tasks at midnight if the page stays open.
  void _scheduleMidnight() {
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1, 0, 0, 5);
    _midnight = Timer(next.difference(now), () {
      _onResume();
      _scheduleMidnight();
    });
  }

  void _onResume() {
    final today = _dateOnly(DateTime.now());
    if (today != _today) {
      _today = today;
      _pending.clear();
      _followLog();
    }
    setState(() {});
  }

  void _followLog() {
    _logChanges?.cancel();
    final date = TaskLog.dateKey(_today);
    _log = TaskLog(date: date);
    _logChanges = FarmStore.watchTaskLog(date).listen((log) {
      setState(() {
        _log = log;
        // Drop the ticks Firestore now shows as saved.
        _pending.removeWhere((id, done) => log.isCompleted(id) == done);
      });
    }, onError: (Object e) => debugPrint('Could not load the task log: $e'));
  }

  /// Today's tasks in time order, with any tick that is still being saved.
  List<DailyTask> _tasks(List<FarmPlant> plants) {
    final now = DateTime.now();
    final saved = [for (final p in plants) if (p.id != null) p];
    final completed = {..._log.completed};
    _pending.forEach((id, done) => done ? completed.add(id) : completed.remove(id));
    final log = TaskLog(date: _log.date, completed: [...completed]);
    return [
      for (final task in dueTasks(saved, _today)) DailyTask.from(task, log, now),
    ];
  }

  Future<void> _toggle(DailyTask task, List<DailyTask> all) async {
    final done = task.status != TaskStatus.completed;
    setState(() => _pending[task.id] = done);
    try {
      await FarmStore.setTaskDone(
        today: _today,
        taskId: task.id,
        done: done,
        todayTaskIds: [for (final t in all) t.id],
      );
    } catch (e) {
      debugPrint('Could not save the task: $e');
      if (!mounted) return;
      setState(() => _pending.remove(task.id));
      showEthmarToast(
        context,
        S.of(context).taskSaveFailed,
        type: EthmarToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final tasks = _tasks(FarmStore.plants.value);
    final doneCount =
        tasks.where((t) => t.status == TaskStatus.completed).length;
    return Scaffold(
      body: LeafPrintBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // A main tab: no back button.
            EthmarCenteredHeader(title: s.navDailyTasks, showBack: false),
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
                    child: _ProgressCard(done: doneCount, total: tasks.length),
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
                        '${tasks.length}',
                        style: AppText.label(context, color: AppColors.earthBrown)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (tasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        s.noTasksToday,
                        textAlign: TextAlign.center,
                        style: AppText.body(context),
                      ),
                    ),
                  for (var i = 0; i < tasks.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    Entrance(
                      delay: Duration(milliseconds: 150 + 50 * i),
                      offset: 16,
                      child: _TaskCard(
                        task: tasks[i],
                        status: tasks[i].status,
                        done: tasks[i].status == TaskStatus.completed,
                        onToggle: () => _toggle(tasks[i], tasks),
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
          // Separate tick control; saved in today's task log.
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
