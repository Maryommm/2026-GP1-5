import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/care_task.dart';
import '../models/daily_task.dart';
import '../models/farm_stats.dart';
import '../models/streak.dart' show streakBrokenByMissedTasks;
import '../models/task_log.dart';
import '../services/farm_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_header.dart' show EthmarToastType, showEthmarToast;
import '../widgets/backgrounds.dart';
import '../widgets/centered_header.dart';
import '../widgets/character.dart';
import '../widgets/entrance.dart';
import '../widgets/ethmar_logo.dart' show parseSvgPath;

/// Today's care tasks: the date, a progress card, and one card per task,
/// then the missed tasks of the last [missedTaskDays] days.
///
/// The tasks come from the user's plants and their care schedules
/// ([dueTasks]); ticking one saves it in today's task log and updates the
/// streak (see [FarmStore.setTaskDone]). A task is only missed once its day
/// is over; ticking a missed task saves it as done late, in its own day's
/// log, without touching the streak (see [FarmStore.setLateTaskDone]).
///
/// In the current layout it opens from Home's "Today's Tasks" card, with a
/// back button; in the classic layout it is a tab ([asTab]), without one.
class DailyTasksScreen extends StatefulWidget {
  const DailyTasksScreen({super.key, this.asTab = false});
  final bool asTab;

  @override
  State<DailyTasksScreen> createState() => _DailyTasksScreenState();
}

class _DailyTasksScreenState extends State<DailyTasksScreen> {
  DateTime _today = _dateOnly(DateTime.now());

  /// The task logs of today and the [missedTaskDays] days before, by date.
  final _logs = <String, TaskLog>{};
  final _logChanges = <StreamSubscription<TaskLog>>[];
  late final AppLifecycleListener _lifecycle;
  Timer? _midnight;

  // Ticks shown right away, before Firestore confirms them:
  // DailyTask.key -> done.
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
    for (final sub in _logChanges) {
      sub.cancel();
    }
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

  /// Follows the logs of today and of the days whose missed tasks show.
  void _followLog() {
    for (final sub in _logChanges) {
      sub.cancel();
    }
    _logChanges.clear();
    _logs.clear();
    final today = TaskLog.dateKey(_today);
    for (var back = 0; back <= missedTaskDays; back++) {
      final date = TaskLog.dateKey(
        DateTime(_today.year, _today.month, _today.day - back),
      );
      _logs[date] = TaskLog(date: date);
      _logChanges.add(FarmStore.watchTaskLog(date).listen((log) {
        setState(() {
          _logs[date] = log;
          // Drop the ticks Firestore now shows as saved.
          _pending.removeWhere((key, done) {
            if (!key.startsWith('$date/')) return false;
            final id = key.substring(date.length + 1);
            final saved =
                date == today ? log.isCompleted(id) : log.isDoneLate(id);
            return saved == done;
          });
        });
      }, onError: (Object e) => debugPrint('Could not load a task log: $e')));
    }
  }

  /// The logs with any tick that is still being saved: on time for today,
  /// late for the days before.
  Map<String, TaskLog> _logsWithPending() {
    final today = TaskLog.dateKey(_today);
    final logs = <String, TaskLog>{};
    _logs.forEach((date, log) {
      final completed = {...log.completed};
      final late = {...log.late};
      final ticks = date == today ? completed : late;
      _pending.forEach((key, done) {
        if (!key.startsWith('$date/')) return;
        final id = key.substring(date.length + 1);
        done ? ticks.add(id) : ticks.remove(id);
      });
      logs[date] = TaskLog(date: date, completed: [...completed], late: [...late]);
    });
    return logs;
  }

  Future<void> _toggle(DailyTask task, List<DailyTask> today) async {
    final done = !task.done;
    setState(() => _pending[task.key] = done);
    try {
      if (task.isPast) {
        await FarmStore.setLateTaskDone(
          day: task.day,
          taskId: task.id,
          done: done,
        );
      } else {
        await FarmStore.setTaskDone(
          today: _today,
          taskId: task.id,
          done: done,
          todayTaskIds: [for (final t in today) t.id],
        );
      }
    } catch (e) {
      debugPrint('Could not save the task: $e');
      if (!mounted) return;
      setState(() => _pending.remove(task.key));
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
    final plants = FarmStore.plants.value;
    final logs = _logsWithPending();
    final tasks = tasksForDay(
      plants,
      _today,
      logs[TaskLog.dateKey(_today)]!,
      DateTime.now(),
    );
    final missed = missedTasks(plants, _today, logs);
    final doneCount = tasks.where((t) => t.done).length;
    // Shown order only: tasks still to do first, done ones last, each group
    // keeping its order.
    List<DailyTask> doneLast(List<DailyTask> list) => [
      ...list.where((t) => !t.done),
      ...list.where((t) => t.done),
    ];
    final shown = doneLast(tasks);
    final shownMissed = doneLast(missed);
    return Scaffold(
      body: LeafPrintBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // As a main tab there is nothing to go back to.
            EthmarCenteredHeader(
              title: s.navDailyTasks,
              showBack: !widget.asTab,
            ),
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
                        // Thamoor planting a seedling, kept small and still
                        // so the tasks show sooner. With no tasks, the empty
                        // state shows Thamoor instead.
                        if (tasks.isNotEmpty) ...[
                          const ExcludeSemantics(
                            child: EthmarCharacter(
                              name: 'ethmar_thamoor_planting',
                              height: 96,
                              bob: false,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
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
                  if (tasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Entrance(
                        delay: Duration(milliseconds: 100),
                        child: _EmptyTasks(),
                      ),
                    )
                  else ...[
                    const SizedBox(height: 12),
                    Entrance(
                      delay: const Duration(milliseconds: 100),
                      child:
                          _ProgressCard(done: doneCount, total: tasks.length),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      s.todaysTasks,
                      style: AppText.title(context).copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 10),
                    for (var i = 0; i < shown.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _entry(shown[i], i, tasks),
                    ],
                  ],
                  // Below today's tasks: the last days' missed ones, until
                  // they are too old.
                  if (shownMissed.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      s.missedTasks,
                      style: AppText.title(context).copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 4),
                    Text(s.missedTasksHint, style: AppText.small(context)),
                    const SizedBox(height: 10),
                    for (var i = 0; i < shownMissed.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _entry(shownMissed[i], shown.length + i, tasks),
                    ],
                  ],
                  // Only today's tasks are listed; earlier days that weren't
                  // finished are summed up here instead.
                  ValueListenableBuilder<FarmStats>(
                    valueListenable: FarmStore.stats,
                    builder: (context, stats, _) => streakBrokenByMissedTasks(
                            stats, FarmStore.plants.value, _today)
                        ? Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: Entrance(
                              delay: Duration(
                                  milliseconds: 150 + 50 * shown.length),
                              child: const _StreakMissedNote(),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One task card, sliding in after the ones above it.
  Widget _entry(DailyTask task, int index, List<DailyTask> today) => Entrance(
    // Keyed by task, so a card that moves to the bottom when ticked keeps
    // its state and doesn't animate in again.
    key: ValueKey(task.key),
    delay: Duration(milliseconds: 150 + 50 * index),
    offset: 16,
    child: _TaskCard(task: task, onToggle: () => _toggle(task, today)),
  );
}

/// Soft green card: "Daily Progress", "1 / 3", a bar and a short line.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.done, required this.total});
  final int done;
  final int total;

  // White card with a sage green bar. Text uses the app's colours.
  static const _background = AppColors.surface;
  static const _fill = Color(0xFF648A65);
  static const _track = Color(0xFFCBD8C3);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final value = total == 0 ? 0.0 : done / total;
    return Semantics(
      label: '${s.dailyProgress}: ${s.dailyProgressOf(done, total)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        // Stands out from the task cards below: a sage outline and a deeper
        // shadow than theirs.
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _track, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _fill.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.dailyProgress,
                    style: AppText.title(context)
                        .copyWith(fontSize: 17, color: AppColors.textPrimary),
                  ),
                ),
                Text(
                  '$done / $total',
                  // Keep "1 / 3" in this order in Arabic too.
                  textDirection: TextDirection.ltr,
                  style: AppText.label(context, color: AppColors.textPrimary)
                      .copyWith(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 10,
                color: _fill,
                backgroundColor: _track,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              s.dailyProgressOf(done, total),
              // AppText.small: the app's secondary description style.
              style: AppText.small(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// One task: type icon, "Mint · Watering" with its time below (and the day,
/// for a missed one), the status pill across from the name, and a small
/// tick control at the end.
class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.onToggle});
  final DailyTask task;
  final VoidCallback onToggle;

  TaskStatus get status => task.status;
  bool get done => task.done;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    // Blue for watering, warm yellow for fertilizing.
    final (icon, typeLabel, iconColor, iconBackground) = switch (task.type) {
      TaskType.watering => (
          Icons.water_drop_rounded,
          s.taskWatering,
          AppColors.info,
          AppColors.infoTint,
        ),
      TaskType.fertilizing => (
          // Drawn as a fertilizer sack below; Material has no such icon.
          null,
          s.taskFertilizing,
          AppColors.sunDark,
          AppColors.sunTint,
        ),
    };
    // A thin outline in the status colour: green when done, warm yellow
    // once its time has come, soft red when missed, none while upcoming.
    final outline = switch (status) {
      TaskStatus.completed ||
      TaskStatus.doneLate => AppColors.success.withValues(alpha: 0.45),
      TaskStatus.due => AppColors.sunDark.withValues(alpha: 0.35),
      TaskStatus.missed => AppColors.error.withValues(alpha: 0.3),
      TaskStatus.upcoming => null,
    };
    // Done tasks: a very light green card and slightly softer text and icon,
    // still easy to read.
    final background = done
        ? Color.lerp(AppColors.surface, AppColors.successTint, 0.15)!
        : AppColors.surface;
    final nameColor = done ? AppColors.textSecondary : AppColors.textPrimary;
    final iconTint =
        done ? Color.lerp(iconColor, AppColors.surface, 0.3)! : iconColor;
    final iconFill =
        done ? Color.lerp(iconBackground, AppColors.surface, 0.4)! : iconBackground;
    var time = MaterialLocalizations.of(context).formatTimeOfDay(task.time);
    if (task.isPast) {
      final now = DateTime.now();
      final daysAgo = DateTime.utc(now.year, now.month, now.day)
          .difference(
            DateTime.utc(task.day.year, task.day.month, task.day.day),
          )
          .inDays;
      time = '${s.missedDaysAgo(daysAgo)} · $time';
    }
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: outline == null
            ? null
            : Border.all(color: outline, width: done ? 1.4 : 1.2),
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
            decoration: BoxDecoration(
              color: iconFill,
              shape: BoxShape.circle,
            ),
            child: icon == null
                ? _FertilizerSack(size: 22, color: iconTint)
                : Icon(icon, size: 22, color: iconTint),
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
                        style: AppText.label(context, color: nameColor)
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

/// A fertilizer sack: a tied top over a round bag with a leaf on the front.
class _FertilizerSack extends StatelessWidget {
  const _FertilizerSack({required this.size, required this.color});
  final double size;
  final Color color;

  // Drawn on a 24 × 24 grid, like Material icons.
  static final _path = parseSvgPath(
    // Tied top.
    'M9 6L8 2.8L10.5 4.1L12 2.4L13.5 4.1L16 2.8L15 6Z'
    // Tie band.
    'M8.6 6.3H15.4A0.7 0.7 0 0 1 15.4 7.7H8.6A0.7 0.7 0 0 1 8.6 6.3Z'
    // Bag.
    'M7.2 8.2C4.6 10.3 4 14 4.5 18C4.8 20.4 6.5 21.6 8.6 21.6H15.4'
    'C17.5 21.6 19.2 20.4 19.5 18C20 14 19.4 10.3 16.8 8.2Z'
    // A slanted leaf cut out of the bag, with its middle vein (a leaf, not
    // a drop, so it isn't mistaken for watering).
    'M9.2 18.4C9.2 14.6 11.4 12.4 15.2 12.1C15.2 15.9 13 18.2 9.2 18.4Z'
    'M9.7 17.7L13.6 13.5L14 13.9L10.1 18.1Z',
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _FertilizerSackPainter(_path, color)),
    );
  }
}

class _FertilizerSackPainter extends CustomPainter {
  const _FertilizerSackPainter(this.path, this.color);
  final Path path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    // evenOdd leaves the leaf hollow on the bag.
    canvas.drawPath(
      path..fillType = PathFillType.evenOdd,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_FertilizerSackPainter old) => old.color != color;
}

/// Under the tasks: the streak was reset because tasks of earlier days
/// weren't done.
class _StreakMissedNote extends StatelessWidget {
  const _StreakMissedNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('streakMissedNote'),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.sunTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sun.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The same fire as Home's streak card.
          Image.asset(
            'assets/images/ethmar_streak_icon.png',
            width: 28,
            height: 28,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              S.of(context).streakMissedMessage,
              style: AppText.body(context, color: AppColors.textPrimary)
                  .copyWith(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// No tasks today: a still Thamoor and a friendly line, centred.
class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ExcludeSemantics(
          child: EthmarCharacter(
            name: 'ethmar_sunny_day_character',
            height: 120,
            bob: false,
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            S.of(context).noTasksToday,
            textAlign: TextAlign.center,
            style: AppText.body(context)
                .copyWith(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

/// Coloured pill: Completed or Done late (green), Due now (yellow), Missed
/// (red), Upcoming (beige).
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final (label, fg, bg) = switch (status) {
      TaskStatus.completed =>
        (s.statusCompleted, AppColors.success, AppColors.successTint),
      TaskStatus.doneLate =>
        (s.statusDoneLate, AppColors.success, AppColors.successTint),
      TaskStatus.due => (s.statusDue, AppColors.sunDark, AppColors.sunTint),
      TaskStatus.missed =>
        (s.statusMissed, AppColors.error, AppColors.errorTint),
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
