import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_strings.dart';
import '../l10n/locale_controller.dart';
import '../models/care_task.dart';
import '../models/daily_task.dart' show TaskType;
import '../models/farm_plant.dart';
import '../models/task_log.dart';
import 'farm_store.dart';
import 'recent_task_logs.dart';

/// One notification to schedule: its time, id and text.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
  });

  final int id;
  final DateTime at;
  final String title;
  final String body;

  /// Saved with the notification, so the next sync can tell whether a
  /// scheduled notification is already up to date.
  String get payload => at.toIso8601String();
}

/// How many days ahead the reminders are scheduled. Android can only repeat
/// a notification daily or weekly, but our schedules can repeat every 2-6,
/// 14, 21 or 30 days. So each reminder is scheduled one by one and topped
/// up on every sync. If the app isn't opened, reminders keep coming for
/// this many days.
const reminderHorizonDays = 30;

/// Tasks that repeat rarely still get at least this many reminders, even
/// after [reminderHorizonDays] (otherwise a monthly task would get only one).
const minRemindersPerTask = 4;

/// How far ahead to look: enough for [minRemindersPerTask] monthly reminders.
const reminderLookAheadDays = 120;

/// The most reminders one task can have (one a day), which is also the
/// number of ids each task needs.
const maxRemindersPerTask = 100;

/// Android allows an app about 500 alarms, so we stay well below that.
const maxReminders = 400;

/// A notification id that is always the same for a plant, a task type and
/// a slot (0 = the next reminder, 1 = the one after, ...), even after the
/// app restarts.
///
/// Scheduling with an id that already exists replaces it, so syncing again
/// never creates duplicates. We use the FNV-1a hash because
/// String.hashCode can change between runs.
int reminderId(String plantId, TaskType type, int slot) {
  assert(slot >= 0 && slot < maxRemindersPerTask);
  var hash = 0x811c9dc5;
  for (final unit in '$plantId/${type.name}'.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  // At most 499,999,999, so it is a positive 32-bit int as Android needs.
  return (hash % 5000000) * maxRemindersPerTask + slot;
}

/// The notifications to schedule for [plants] after [now]. For each
/// plant's watering and fertilizing, it plans every reminder in the next
/// [reminderHorizonDays] days (and at least [minRemindersPerTask] of each),
/// with at most [maxReminders] in total, soonest first. [s] gives the text
/// in the app's language.
///
/// Tasks are planned as if none of them gets done. When a task is done the
/// plant changes, and the reminders are planned again.
///
/// [logs] and [done] tell which tasks are already ticked, so a task done
/// today gets no reminder today.
List<PlannedReminder> planReminders(
  List<FarmPlant> plants,
  DateTime now,
  S s, {
  TaskLog? done,
  Map<String, TaskLog> logs = const {},
}) {
  final known = {...logs, if (done != null) done.date: done};
  final planned = <PlannedReminder>[];
  final today = DateTime(now.year, now.month, now.day);
  final lastDay = DateTime(
    today.year,
    today.month,
    today.day + reminderLookAheadDays,
  );
  final horizon = DateTime(now.year, now.month, now.day + reminderHorizonDays,
      now.hour, now.minute);
  final todayLog = known[TaskLog.dateKey(today)];
  for (final state in careStates(plants, now, logs: known)) {
    var slot = 0;
    for (final day in state.taskDays(today, lastDay)) {
      final at = state.at(day);
      if (!at.isAfter(now)) continue;
      if (day == today && (todayLog?.isCompleted(state.taskId) ?? false)) {
        continue;
      }
      final wanted = slot < minRemindersPerTask || !at.isAfter(horizon);
      if (!wanted || slot >= maxRemindersPerTask) break;
      // A different message each day, but the same one on every sync.
      final variant = _dayNumber(at) % S.reminderVariants;
      final watering = state.type == TaskType.watering;
      planned.add(PlannedReminder(
        id: reminderId(state.plant.id!, state.type, slot),
        at: at,
        title: s.reminderTitle(watering: watering, variant: variant),
        body: s.reminderBody(
          watering: watering,
          variant: variant,
          plant: state.plant.name,
        ),
      ));
      slot++;
    }
  }
  planned.sort((a, b) => a.at.compareTo(b.at));
  return planned.length > maxReminders
      ? planned.sublist(0, maxReminders)
      : planned;
}

/// Number of days since 1 January 1970 for [t], used to pick the day's
/// message.
int _dayNumber(DateTime t) =>
    DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// Care reminders: a notification at the time of every watering and
/// fertilizing task. Android shows it even when the app is closed or the
/// phone is offline.
///
/// - [init] runs once at startup. After that the reminders follow
///   [FarmStore.plants]: editing a plant reschedules its reminders,
///   deleting it cancels them, and signing out cancels all of them.
/// - Ticking a task cancels its reminder for today and plans the next ones.
///   Un-ticking brings the old ones back.
/// - [askPermissions] asks for the notification permissions. The main
///   shell calls it after the user signs in.
/// - Tapping a notification sets [openDailyTasks], and the main shell opens
///   the Daily Tasks tab.
class CareNotifications {
  CareNotifications._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// True when a notification was tapped and the Daily Tasks tab should open.
  /// The main shell sets it back to false after opening the tab.
  static final openDailyTasks = ValueNotifier<bool>(false);

  static const _channelId = 'care_reminders';
  static const _askedExactKey = 'reminders_asked_exact_alarms';

  static bool _started = false;
  static bool _syncing = false;
  static bool _syncAgain = false;

  // Kept for as long as the app runs.
  // ignore: unused_field
  static AppLifecycleListener? _lifecycle;

  /// The task logs of today and the missed days. Kept up to date so ticking a
  /// task plans its reminders again right away.
  static RecentTaskLogs? _logs;

  /// Listens to the recent task logs. Called again when the app resumes, so
  /// a new day switches to that day's logs.
  static void _watchToday() {
    final logs = _logs;
    if (logs != null) {
      logs.checkDay();
      return;
    }
    _logs = RecentTaskLogs()..addListener(sync);
  }

  /// Starts the reminders. Call once after Firebase and [FarmStore.start].
  static Future<void> init() async {
    if (_started || defaultTargetPlatform != TargetPlatform.android) return;
    _started = true;
    try {
      tz_data.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (_) => openDailyTasks.value = true,
      );
      // The app was closed and tapping the notification opened it.
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        openDailyTasks.value = true;
      }
    } catch (e) {
      debugPrint('Care reminders could not start: $e');
      return;
    }
    FarmStore.plants.addListener(sync);
    appLocale.addListener(sync);
    // When the user comes back to the app, top up the reminders and check if a
    // permission changed.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _watchToday();
        sync();
      },
    );
    _watchToday();
    unawaited(sync());
  }

  /// Asks for the notification permission (Android 13+ shows a dialog).
  /// The exact-alarm permission is asked later by [sync], once the user has
  /// a reminder (see [_askExactAlarmsOnce]).
  static Future<void> askPermissions() async {
    final android = _android;
    if (!_started || android == null) return;
    try {
      await android.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Could not ask for the notification permission: $e');
    }
    await sync();
  }

  /// Exact alarms (Android 12+) make a reminder ring on time instead of up to
  /// an hour late. Android 14+ turns them off by default and the user can
  /// only allow them in settings, so we open that settings page once.
  /// Returns whether exact alarms are allowed now.
  static Future<bool> _askExactAlarmsOnce() async {
    final android = _android;
    if (android == null) return true;
    if (await android.canScheduleExactNotifications() ?? true) return true;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_askedExactKey) ?? false) return false;
    await prefs.setBool(_askedExactKey, true);
    await android.requestExactAlarmsPermission();
    return await android.canScheduleExactNotifications() ?? false;
  }

  /// Makes the scheduled notifications match the plants: cancels the ones
  /// that aren't needed and schedules the missing or changed ones. If sync is
  /// called while it's already running, it runs once more after.
  static Future<void> sync() async {
    if (!_started) return;
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _syncAgain = false;
        await _syncOnce();
      } while (_syncAgain);
    } catch (e) {
      debugPrint('Could not schedule the care reminders: $e');
    } finally {
      _syncing = false;
    }
  }

  static Future<void> _syncOnce() async {
    final s = S(appLocale.value.languageCode == 'ar'
        ? AppStrings.ar
        : AppStrings.en);
    final plan = planReminders(
      FarmStore.plants.value,
      DateTime.now(),
      s,
      logs: _logs?.logs ?? const {},
    );
    final wanted = {for (final r in plan) r.id: r};

    // Without the exact-alarm permission the reminder may come late, but it
    // still comes.
    final exact = plan.isEmpty || await _askExactAlarmsOnce();
    // The payload also saves whether it was exact, so reminders scheduled
    // before the permission was given are rescheduled as exact.
    String payloadOf(PlannedReminder r) => '${r.payload}|${exact ? 'exact' : 'inexact'}';

    final pending = await _plugin.pendingNotificationRequests();
    final upToDate = <int>{};
    for (final p in pending) {
      final r = wanted[p.id];
      if (r == null) {
        await _plugin.cancel(id: p.id);
      } else if (p.payload == payloadOf(r) && p.title == r.title && p.body == r.body) {
        upToDate.add(p.id);
      }
    }
    if (plan.isEmpty) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        s.reminderChannel,
        channelDescription: s.reminderChannelInfo,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
    );
    for (final r in plan) {
      if (upToDate.contains(r.id)) continue;
      await _plugin.zonedSchedule(
        id: r.id,
        // The time zone was already applied when the local time was built.
        scheduledDate: tz.TZDateTime.from(r.at, tz.UTC),
        notificationDetails: details,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        title: r.title,
        body: r.body,
        payload: payloadOf(r),
      );
    }
  }
}
