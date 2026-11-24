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

/// One notification to schedule: when, with which id and text.
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
  /// pending notification is already up to date.
  String get payload => at.toIso8601String();
}

/// How many days ahead every task's alarms are scheduled. Android can only
/// repeat a notification every day or every week, and schedules here can
/// repeat every 2 to 6, 14, 21 or 30 days, so the alarms are scheduled one by one
/// and topped up on every sync. If the app isn't opened, reminders keep
/// coming for this many days.
const reminderHorizonDays = 30;

/// Tasks that repeat rarely still get at least this many alarms, even past
/// [reminderHorizonDays] (a monthly task would otherwise get only one).
const minRemindersPerTask = 4;

/// How far ahead to look: enough for [minRemindersPerTask] monthly alarms.
const reminderLookAheadDays = 120;

/// The most alarms one task can get (one a day over the horizon), and so
/// the number of id slots each task needs.
const maxRemindersPerTask = 100;

/// Android allows an app about 500 alarms; stay well below that.
const maxReminders = 400;

/// A notification id that stays the same for a plant, a task type and a
/// slot (0 = the next alarm, 1 = the one after...), across app restarts.
///
/// Scheduling a notification with an id that is already pending replaces
/// it, so syncing again never makes duplicates. String.hashCode isn't used:
/// Dart doesn't promise it stays the same between runs. This is FNV-1a.
int reminderId(String plantId, TaskType type, int slot) {
  assert(slot >= 0 && slot < maxRemindersPerTask);
  var hash = 0x811c9dc5;
  for (final unit in '$plantId/${type.name}'.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  // At most 499,999,999: a positive 32-bit int, as Android needs.
  return (hash % 5000000) * maxRemindersPerTask + slot;
}

/// The notifications to schedule for [plants] after [now]: for every
/// plant's watering and fertilizing, the tasks careState expects from now
/// on, every alarm in the next [reminderHorizonDays] days, and at least the
/// next [minRemindersPerTask] of each; at most [maxReminders] in all, the
/// soonest first. [s] gives the text in the app's language.
///
/// The tasks are planned as if none is done before it comes, so a missed
/// task gets no second reminder, and no reminder comes for a task that a
/// missed one takes the place of. Doing a task changes the plant, and the
/// reminders are planned again from its new next task.
///
/// [logs] (task logs by date key, see careState) and [done] (one day's log)
/// tell which tasks are already ticked: a task done today gets no reminder
/// today, and someone who watered early isn't told to water again.
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
      // A different message each day, the same one on every sync.
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

/// Days since 1 January 1970 for the date of [t], to pick the day's message.
int _dayNumber(DateTime t) =>
    DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// Care reminders: a notification at the alarm time of every watering and
/// fertilizing task, shown by Android even when the app is closed or the
/// phone is offline.
///
/// - [init] runs once at startup. From then on the reminders follow
///   [FarmStore.plants]: editing a plant schedules its alarms again,
///   deleting it cancels them, and signing out cancels all of them.
/// - They also follow the recent task logs: ticking a task (on time or
///   late) cancels its reminder for today and plans the next ones from the
///   day it was done; un-ticking it brings the old ones back.
/// - [askPermissions] asks for the notification and exact-alarm
///   permissions; the main shell calls it once the user is signed in.
/// - Tapping a notification sets [openDailyTasks]; the main shell listens
///   and opens the Daily Tasks tab.
class CareNotifications {
  CareNotifications._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// True while a tapped notification is waiting for the Daily Tasks tab.
  /// The main shell sets it back to false once it has opened the tab.
  static final openDailyTasks = ValueNotifier<bool>(false);

  static const _channelId = 'care_reminders';
  static const _askedExactKey = 'reminders_asked_exact_alarms';

  static bool _started = false;
  static bool _syncing = false;
  static bool _syncAgain = false;

  // Kept for the life of the app.
  // ignore: unused_field
  static AppLifecycleListener? _lifecycle;

  /// The task logs of today and the missed days, kept current, so ticking
  /// a task (on time or late) plans its reminders again at once.
  static RecentTaskLogs? _logs;

  /// Follows the recent task logs. Called again on resume, so a new day
  /// switches to the new day's logs.
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
      // The app was closed and the tap started it.
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
    // Top up the alarms and pick up a changed permission when the user
    // comes back to the app.
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
  /// The exact-alarm permission is asked for later, by [sync], once the
  /// user really has a reminder (see [_askExactAlarmsOnce]).
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

  /// Exact alarms (Android 12+) make a reminder ring within the minute
  /// instead of whenever Android batches it (up to an hour late). Android
  /// 14+ turns them off by default and only lets the user allow them on a
  /// settings page, so that page is opened once, while the app is on
  /// screen. Returns whether exact alarms are allowed now.
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

  /// Makes Android's pending notifications match the plants: cancels the
  /// ones no longer wanted and schedules the missing or changed ones.
  /// Calls that arrive while a sync runs are merged into one more sync.
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

    // Without the exact-alarm permission Android may deliver late, but the
    // reminder still comes.
    final exact = plan.isEmpty || await _askExactAlarmsOnce();
    // The payload also records exact or not, so reminders scheduled before
    // the permission was given are scheduled again as exact ones.
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
        // The alarm is set for this exact moment; the phone's time zone
        // was already applied when the local time was built.
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
