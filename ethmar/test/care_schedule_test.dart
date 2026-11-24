// Watering and fertilizing schedules: completion-based recurrence, the
// three missed days, one task at a time per plant and type, undo, schedule
// changes, reminders and the streak. All dates are fixed; "now" is passed
// in, never read from the clock (except in the Plant Details widget test,
// which builds its plant around today).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ethmar/l10n/app_strings.dart';
import 'package:ethmar/models/care_task.dart';
import 'package:ethmar/models/crop_catalog.dart';
import 'package:ethmar/models/daily_task.dart';
import 'package:ethmar/models/farm_plant.dart';
import 'package:ethmar/models/farm_stats.dart';
import 'package:ethmar/models/streak.dart';
import 'package:ethmar/models/task_log.dart';
import 'package:ethmar/screens/plant_details_screen.dart';
import 'package:ethmar/services/care_notifications.dart';
import 'package:ethmar/services/farm_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const at8 = TimeOfDay(hour: 8, minute: 0);
const at17 = TimeOfDay(hour: 17, minute: 30);
final en = S(AppStrings.en);

/// A date in November 2026 (or another [month]).
DateTime nov(int day, [int month = 11]) => DateTime(2026, month, day);

/// [day] at 09:00, after an 08:00 task's time.
DateTime morning(DateTime day) => DateTime(day.year, day.month, day.day, 9);

CareDone done(DateTime on, [DateTime? due]) =>
    CareDone(date: on, due: due ?? on);

/// A plant planted and added on Nov 1 (or [planted]).
FarmPlant plant({
  CareSchedule? water,
  CareSchedule? fertilize,
  DateTime? planted,
  String id = 'p',
}) => FarmPlant(
  id: id,
  crop: cropCatalog.first,
  name: 'Mint',
  irrigation: water,
  fertilization: fertilize,
  plantedAt: planted ?? nov(1),
  createdAt: planted ?? nov(1),
  updatedAt: planted ?? nov(1),
);

/// Watering every [repeat], first due on [since].
FarmPlant watered(
  Repeat repeat, {
  DateTime? since,
  CareDone? last,
  CareDone? previous,
  TimeOfDay time = at8,
}) => plant(
  water: CareSchedule(
    repeat,
    time,
    since: since ?? nov(20),
    lastDone: last,
    previousDone: previous,
  ),
);

CareState water(
  FarmPlant p,
  DateTime now, [
  Map<String, TaskLog> logs = const {},
]) => careState(p, TaskType.watering, now, logs: logs)!;

List<DailyTask> todays(
  List<FarmPlant> plants,
  DateTime now, [
  Map<String, TaskLog> logs = const {},
]) => tasksForDay(plants, now, logs, now);

List<DailyTask> missedOn(
  List<FarmPlant> plants,
  DateTime now, [
  Map<String, TaskLog> logs = const {},
]) => missedTasks(plants, now, logs);

Map<String, TaskLog> logOf(TaskLog log) => {log.date: log};

/// Every active (not done) task of [p]'s watering on [now]: today's and the
/// missed one. Never more than one.
int activeWatering(FarmPlant p, DateTime now) =>
    todays([p], now).where((t) => !t.done).length +
    missedOn([p], now).where((t) => !t.done).length;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // Scenarios 1-4: a task due on Nov 20 that is never done.
  group('a missed task and the three missed days', () {
    test('1. every day: one missed task, no other watering until it goes',
        () {
      final p = watered(Repeat.everyDay);
      expect(water(p, morning(nov(20))).dueToday, isTrue);
      for (final day in [21, 22, 23]) {
        final state = water(p, morning(nov(day)));
        expect(state.missed, nov(20), reason: 'Nov $day');
        expect(state.dueToday, isFalse, reason: 'Nov $day');
        expect(state.suppressedToday, isTrue, reason: 'Nov $day');
        expect(todays([p], morning(nov(day))), isEmpty, reason: 'Nov $day');
        expect([for (final t in missedOn([p], morning(nov(day)))) t.day],
            [nov(20)], reason: 'Nov $day');
      }
      // Nov 24: the missed task is gone; one watering is due today.
      final state = water(p, morning(nov(24)));
      expect(state.missed, isNull);
      expect(state.dueToday, isTrue);
      expect(todays([p], morning(nov(24))), hasLength(1));
      expect(missedOn([p], morning(nov(24))), isEmpty);
    });

    test('2. every 2 days: Nov 22 gives way, Nov 24 is due', () {
      final p = watered(Repeat.every2Days);
      final on22 = water(p, morning(nov(22)));
      expect(on22.missed, nov(20));
      expect(on22.suppressedToday, isTrue);
      expect(todays([p], morning(nov(22))), isEmpty);
      final on24 = water(p, morning(nov(24)));
      expect(on24.missed, isNull);
      expect(on24.dueToday, isTrue);
      // Not done on the 24th either: missed in turn, and the 26th gives
      // way to it. Done on the 24th instead: the 26th is next.
      expect(water(p, morning(nov(26))).missed, nov(24));
      final doneOn24 = watered(Repeat.every2Days, last: done(nov(24)));
      expect(water(doneOn24, morning(nov(25))).next, nov(26));
    });

    test('3. every 3 days: Nov 23 is the missed task\'s last day', () {
      final p = watered(Repeat.every3Days);
      final on23 = water(p, morning(nov(23)));
      expect(on23.missed, nov(20));
      expect(on23.suppressedToday, isTrue);
      expect(todays([p], morning(nov(23))), isEmpty);
      expect(missedOn([p], morning(nov(23))), hasLength(1));
      // Nov 24: nothing to do; the usual rhythm goes on to the 26th.
      final on24 = water(p, morning(nov(24)));
      expect(on24.missed, isNull);
      expect(on24.dueToday, isFalse);
      expect(on24.next, nov(26));
      expect(todays([p], morning(nov(26))), hasLength(1));
    });

    test('4. every 4 days: nothing gives way', () {
      final p = watered(Repeat.every4Days);
      final on23 = water(p, morning(nov(23)));
      expect(on23.missed, nov(20));
      expect(on23.suppressedToday, isFalse);
      final on24 = water(p, morning(nov(24)));
      expect(on24.missed, isNull);
      expect(on24.dueToday, isTrue);
      expect(todays([p], morning(nov(24))), hasLength(1));
    });
  });

  group('completion moves the schedule', () {
    test('5. every 14 days, done on time: the next is 14 days later', () {
      final p = watered(Repeat.every2Weeks, since: nov(6));
      expect(water(p, morning(nov(20))).dueToday, isTrue);
      final after = watered(Repeat.every2Weeks,
          since: nov(6), last: done(nov(20)));
      final state = water(after, morning(nov(21)));
      expect(state.missed, isNull);
      expect(state.next, nov(4, 12));
    });

    test('6. every 14 days, done 3 days late (Nov 23): next on Dec 7', () {
      final p = watered(Repeat.every2Weeks, since: nov(6));
      expect(water(p, morning(nov(23))).missed, nov(20));
      final schedule = p.irrigation!.markedDone(done(nov(23), nov(20)));
      expect(schedule.lastDone, done(nov(23), nov(20)));
      final after = plant(water: schedule);
      final state = water(after, morning(nov(23)));
      expect(state.missed, isNull);
      expect(state.next, nov(7, 12));
      expect(state.at(state.next), DateTime(2026, 12, 7, 8));
    });

    test('7. done early on its day: done today, next counts from today', () {
      final p = watered(Repeat.everyWeek, time: at17);
      final early = DateTime(2026, 11, 20, 8);
      final logs = logOf(TaskLog(
          date: TaskLog.dateKey(nov(20)), completed: ['p_irrigation']));
      final state = water(p, early, logs);
      expect(state.doneToday, isTrue);
      expect(state.next, nov(27));
      final today = todays([p], early, logs);
      expect(today.single.status, TaskStatus.completed);
    });

    test('8. done during the missed days: no task left from the old rhythm',
        () {
      // Every 2 days: due Nov 20, missed on the 21st, done late on the 22nd.
      final p = watered(Repeat.every2Days, last: done(nov(22), nov(20)));
      final logs = logOf(TaskLog(
          date: TaskLog.dateKey(nov(20)),
          late: ['p_irrigation'],
          lateOn: {'p_irrigation': '2026-11-22'}));
      final now = morning(nov(22));
      final state = water(p, now, logs);
      expect(state.missed, isNull);
      expect(state.dueToday, isFalse);
      expect(state.next, nov(24));
      // The 22nd's own watering doesn't come back as a second task.
      expect(todays([p], now, logs), isEmpty);
      final missed = missedOn([p], now, logs);
      expect(missed.single.status, TaskStatus.doneLate);
      expect(missed.single.day, nov(20));
    });

    test('9. not done in time: it expires, still not done', () {
      final p = watered(Repeat.every2Weeks, since: nov(20));
      final state = water(p, morning(nov(24)));
      expect(state.missed, isNull);
      expect(state.anchor, isNull);
      expect(missedOn([p], morning(nov(24))), isEmpty);
      // It was a day with a task, and it wasn't done.
      expect(dueTasks([p], nov(20)), hasLength(1));
    });

    test('10. after it expires the usual rhythm carries on, nothing made up',
        () {
      // Every 2 days: Nov 24 is on the rhythm, so it's due.
      expect(water(watered(Repeat.every2Days), morning(nov(24))).dueToday,
          isTrue);
      // Every 5 days: the 25th is next; no task on the 24th.
      final every5 = water(watered(Repeat.every5Days), morning(nov(24)));
      expect(every5.dueToday, isFalse);
      expect(every5.next, nov(25));
      expect(todays([watered(Repeat.every5Days)], morning(nov(24))), isEmpty);
    });
  });

  group('one task at a time', () {
    test('11. never two active tasks of one type, for every repeat', () {
      for (final repeat in Repeat.values) {
        final p = watered(repeat);
        for (var d = 0; d < 60; d++) {
          final now = morning(DateTime(2026, 11, 20 + d));
          expect(activeWatering(p, now), lessThanOrEqualTo(1),
              reason: '$repeat on ${TaskLog.dateKey(now)}');
        }
      }
    });

    test('12. watering missed while fertilizing is due', () {
      final p = plant(
        water: CareSchedule(Repeat.everyDay, at8, since: nov(20)),
        fertilize: CareSchedule(Repeat.everyWeek, at17, since: nov(22)),
      );
      final now = morning(nov(22));
      expect([for (final t in todays([p], now)) t.type],
          [TaskType.fertilizing]);
      expect([for (final t in missedOn([p], now)) t.type],
          [TaskType.watering]);
    });

    test('24. skipped tasks never pile up', () {
      final p = watered(Repeat.everyDay, since: nov(1));
      for (var d = 2; d <= 30; d++) {
        final now = morning(nov(d));
        expect(missedOn([p], now).length, lessThanOrEqualTo(1));
        expect(todays([p], now).length, lessThanOrEqualTo(1));
      }
    });
  });

  group('undo', () {
    test('13. un-ticking an on-time task brings the old schedule back', () {
      final before = CareSchedule(Repeat.everyDay, at8,
          since: nov(1), lastDone: done(nov(19)));
      final ticked = before.markedDone(done(nov(20)));
      expect(ticked.lastDone, done(nov(20)));
      expect(ticked.previousDone, done(nov(19)));
      // Ticking again changes nothing.
      expect(ticked.markedDone(done(nov(20))).previousDone, done(nov(19)));
      final unticked = ticked.markedUndone(nov(20));
      expect(unticked.lastDone, done(nov(19)));
      expect(unticked.previousDone, isNull);
      expect(water(plant(water: unticked), morning(nov(20))).dueToday, isTrue);
    });

    test('13b. while the plant isn\'t updated yet, an un-ticked log wins', () {
      final p = watered(Repeat.everyDay, last: done(nov(20)));
      final now = morning(nov(20));
      expect(water(p, now).doneToday, isTrue);
      // Today's log no longer has it: the saved tick is set aside.
      final unticked = logOf(TaskLog(date: TaskLog.dateKey(nov(20))));
      expect(water(p, now, unticked).doneToday, isFalse);
      expect(water(p, now, unticked).dueToday, isTrue);
    });

    test('14. un-ticking a late task makes it missed again', () {
      final before = CareSchedule(Repeat.every2Days, at8, since: nov(20));
      final ticked = before.markedDone(done(nov(22), nov(20)));
      expect(water(plant(water: ticked), morning(nov(22))).next, nov(24));
      final unticked = ticked.markedUndone(nov(20));
      expect(unticked.lastDone, isNull);
      expect(water(plant(water: unticked), morning(nov(22))).missed, nov(20));
    });
  });

  group('changing a schedule', () {
    test('15. a new repeat counts from the last time it was done', () {
      final p = watered(Repeat.every2Weeks,
          since: nov(1), last: done(nov(15)));
      final changed = p.edited(
        name: 'Mint',
        irrigation: const CareSchedule(Repeat.every3Days, at8),
        fertilization: null,
        today: morning(nov(24)),
      );
      // Nov 15 + 3 = Nov 18 has passed: due on the day of the change.
      expect(changed.irrigation!.since, nov(24));
      expect(changed.irrigation!.lastDone, done(nov(15)));
      expect(water(changed, morning(nov(24))).dueToday, isTrue);
      // Done that day: every 3 days from then.
      final doneOn24 = plant(
          water: changed.irrigation!.markedDone(done(nov(24))));
      expect(water(doneOn24, morning(nov(25))).next, nov(27));

      // A new time only: the same days, at the new time.
      final newTime = p.edited(
        name: 'Mint',
        irrigation: const CareSchedule(Repeat.every2Weeks, at17),
        fertilization: null,
        today: morning(nov(24)),
      );
      expect(newTime.irrigation!.since, nov(1));
      expect(newTime.irrigation!.lastDone, done(nov(15)));
      expect(water(newTime, morning(nov(24))).next, nov(29));
      expect(water(newTime, morning(nov(24))).at(nov(29)),
          DateTime(2026, 11, 29, 17, 30));

      // Unchanged: kept, done days and all.
      final renamed = p.edited(
        name: 'My mint',
        irrigation: const CareSchedule(Repeat.every2Weeks, at8),
        fertilization: null,
        today: morning(nov(24)),
      );
      expect(renamed.irrigation!.lastDone, done(nov(15)));
      expect(water(renamed, morning(nov(24))).next, nov(29));
    });

    test('15b. done today, then changed: today stays done', () {
      final p = watered(Repeat.everyDay, last: done(nov(24)));
      final changed = p.edited(
        name: 'Mint',
        irrigation: const CareSchedule(Repeat.every2Days, at8),
        fertilization: null,
        today: morning(nov(24)),
      );
      final logs = logOf(TaskLog(
          date: TaskLog.dateKey(nov(24)), completed: ['p_irrigation']));
      final now = morning(nov(24));
      expect(todays([changed], now, logs).single.status,
          TaskStatus.completed);
      expect(water(changed, now, logs).next, nov(26));
    });

    test('15c. old missed tasks are not brought back by a change', () {
      final p = watered(Repeat.everyDay, since: nov(20));
      expect(missedOn([p], morning(nov(22))), hasLength(1));
      final changed = p.edited(
        name: 'Mint',
        irrigation: const CareSchedule(Repeat.every2Days, at8),
        fertilization: null,
        today: morning(nov(22)),
      );
      expect(missedOn([changed], morning(nov(22))), isEmpty);
      expect(todays([changed], morning(nov(22))), hasLength(1));
    });

    test('16. a plant without a schedule has no tasks or reminders', () {
      final p = plant();
      expect(careState(p, TaskType.watering, morning(nov(20))), isNull);
      expect(todays([p], morning(nov(20))), isEmpty);
      expect(missedOn([p], morning(nov(20))), isEmpty);
      expect(planReminders([p], morning(nov(20)), en), isEmpty);
    });
  });

  group('editing a schedule (E) and undo (U)', () {
    const at18 = TimeOfDay(hour: 18, minute: 0);

    FarmPlant edit(FarmPlant p, DateTime day,
            {CareSchedule? water, CareSchedule? fertilize}) =>
        p.edited(
          name: p.name,
          irrigation: water ?? p.irrigation,
          fertilization: fertilize ?? p.fertilization,
          today: morning(day),
        );

    List<DailyTask> wateringToday(FarmPlant p, DateTime now,
            [Map<String, TaskLog> logs = const {}]) =>
        todays([p], now, logs)
            .where((t) => t.type == TaskType.watering)
            .toList();

    /// Every Daily Tasks screen, Home and Plant Details agree on [p] for
    /// [days] days from [from] (as test 19).
    void expectScreensAgree(FarmPlant p, DateTime from, int days) {
      for (var d = 0; d < days; d++) {
        final now = morning(DateTime(from.year, from.month, from.day + d));
        final state = water(p, now);
        final missed = missedOn([p], now)
            .where((t) => !t.done && t.type == TaskType.watering);
        final today = wateringToday(p, now).where((t) => !t.done);
        expect(missed.length + today.length, lessThanOrEqualTo(1),
            reason: '$now');
        if (missed.isNotEmpty) {
          expect(state.nextDue, missed.single.day, reason: '$now');
        } else if (today.isNotEmpty) {
          expect(state.nextDue, today.single.day, reason: '$now');
        } else {
          expect(state.nextDue.isAfter(state.today), isTrue, reason: '$now');
        }
      }
    }

    // Every 14 days, last done Nov 22: next due Dec 6 at 08:00.
    final every14 = plant(
      water: CareSchedule(Repeat.every2Weeks, at8,
          since: nov(1), lastDone: done(nov(22)), previousDone: done(nov(8))),
      fertilize: CareSchedule(Repeat.everyWeek, at8, since: nov(1)),
    );

    test('E1. a new time keeps the day: Dec 6 at 18:00', () {
      expect(water(every14, morning(nov(23))).next, nov(6, 12));
      final p = edit(every14, nov(23),
          water: const CareSchedule(Repeat.every2Weeks, at18));
      final s = p.irrigation!;
      expect(s.lastDone, done(nov(22)));
      expect(s.previousDone, done(nov(8)));
      expect(s.since, nov(1));
      final state = water(p, morning(nov(23)));
      expect(state.next, nov(6, 12));
      expect(state.at(state.next), DateTime(2026, 12, 6, 18));
      // No extra task on the day of the change.
      expect(wateringToday(p, morning(nov(23))), isEmpty);
      expect(missedOn([p], morning(nov(23)))
          .where((t) => t.type == TaskType.watering), isEmpty);
      // Fertilizing is untouched.
      expect(p.fertilization!.toMap(), every14.fertilization!.toMap());
    });

    test('E2. a new repeat counts from the last done day: Nov 29', () {
      final p = edit(every14, nov(23),
          water: const CareSchedule(Repeat.everyWeek, at8));
      final s = p.irrigation!;
      expect(s.lastDone, done(nov(22)));
      expect(s.time, at8);
      final state = water(p, morning(nov(23)));
      expect(state.next, nov(29));
      expect(state.missed, isNull);
      expect(wateringToday(p, morning(nov(23))), isEmpty);
      // Then every 7 days from the day it is really done.
      final doneOn29 = plant(water: s.markedDone(done(nov(29))));
      expect(water(doneOn29, morning(nov(30))).next, nov(6, 12));
    });

    test('E3. a new repeat and time together: Nov 29 at 18:00', () {
      final p = edit(every14, nov(23),
          water: const CareSchedule(Repeat.everyWeek, at18));
      final state = water(p, morning(nov(23)));
      expect(state.at(state.next), DateTime(2026, 11, 29, 18));
      expect(p.irrigation!.lastDone, done(nov(22)));
    });

    test('E4. edited right after it was done: today stays done', () {
      final logs = logOf(TaskLog(
          date: TaskLog.dateKey(nov(22)), completed: ['p_irrigation']));
      final now = morning(nov(22));
      for (final (schedule, next) in [
        (const CareSchedule(Repeat.every2Weeks, at18), nov(6, 12)),
        (const CareSchedule(Repeat.every3Days, at8), nov(25)),
        (const CareSchedule(Repeat.everyDay, at18), nov(23)),
      ]) {
        final p = edit(every14, nov(22), water: schedule);
        final today = wateringToday(p, now, logs);
        expect(today, hasLength(1), reason: '$schedule');
        expect(today.single.status, TaskStatus.completed);
        expect(water(p, now, logs).next, next, reason: '${schedule.repeat}');
        // The day still had its one task, for the streak.
        expect(dueTasks([p], nov(22))
            .where((t) => t.type == TaskType.watering), hasLength(1));
      }
    });

    test('E5. edited while a task is due today', () {
      // Every 7 days, last done Nov 16: due today, Nov 23.
      final p = plant(water: CareSchedule(Repeat.everyWeek, at8,
          since: nov(1), lastDone: done(nov(16))));
      final now = morning(nov(23));
      expect(wateringToday(p, now).single.status, TaskStatus.due);
      // New time: still today's one task, now later in the day.
      final later = edit(p, nov(23),
          water: const CareSchedule(Repeat.everyWeek, at18));
      expect(wateringToday(later, now).single.status, TaskStatus.upcoming);
      expect(wateringToday(later, now).single.time, at18);
      // Every 3 days: Nov 19 has passed, so still due today, only once.
      final shorter = edit(p, nov(23),
          water: const CareSchedule(Repeat.every3Days, at8));
      expect(wateringToday(shorter, now), hasLength(1));
      expect(missedOn([shorter], now), isEmpty);
      // Every 14 days: Nov 30, nothing today.
      final longer = edit(p, nov(23),
          water: const CareSchedule(Repeat.every2Weeks, at8));
      expect(wateringToday(longer, now), isEmpty);
      expect(water(longer, now).next, nov(30));
    });

    test('E6. edited during the missed days', () {
      // Every 7 days, last done Nov 13: Nov 20 is missed on Nov 22.
      final p = plant(water: CareSchedule(Repeat.everyWeek, at8,
          since: nov(1), lastDone: done(nov(13))));
      final now = morning(nov(22));
      expect(missedOn([p], now).single.day, nov(20));
      // New time: the same missed task, at the new time; next Nov 27.
      final later = edit(p, nov(22),
          water: const CareSchedule(Repeat.everyWeek, at18));
      expect(missedOn([later], now).single.day, nov(20));
      expect(missedOn([later], now).single.time, at18);
      expect(missedOn([later], now).single.status, TaskStatus.missed);
      expect(water(later, now).next, nov(27));
      // Every 3 days: Nov 16 has passed, so one task today in its place.
      final shorter = edit(p, nov(22),
          water: const CareSchedule(Repeat.every3Days, at8));
      expect(missedOn([shorter], now), isEmpty);
      expect(wateringToday(shorter, now), hasLength(1));
      // Every 14 days: Nov 27, nothing to do before.
      final longer = edit(p, nov(22),
          water: const CareSchedule(Repeat.every2Weeks, at8));
      expect(missedOn([longer], now), isEmpty);
      expect(wateringToday(longer, now), isEmpty);
      expect(water(longer, now).next, nov(27));
    });

    test('E7. never done: a new time keeps its days, a new repeat starts '
        'on the day of the change', () {
      final p = watered(Repeat.everyWeek, since: nov(20));
      final now = morning(nov(22));
      final later = edit(p, nov(22),
          water: const CareSchedule(Repeat.everyWeek, at18));
      expect(later.irrigation!.since, nov(20));
      expect(missedOn([later], now).single.day, nov(20));
      expect(water(later, now).next, nov(27));
      final shorter = edit(p, nov(22),
          water: const CareSchedule(Repeat.every3Days, at8));
      expect(shorter.irrigation!.since, nov(22));
      expect(shorter.irrigation!.lastDone, isNull);
      expect(water(shorter, now).dueToday, isTrue);
      expect(missedOn([shorter], now), isEmpty);
    });

    test('E8. a new time never moves any task day, for every repeat', () {
      for (final repeat in Repeat.values) {
        for (final last in [null, done(nov(15)), done(nov(18), nov(16))]) {
          final p = plant(water: CareSchedule(repeat, at8,
              since: nov(10), lastDone: last));
          for (var e = 15; e <= 30; e += 3) {
            final q = edit(p, nov(e), water: CareSchedule(repeat, at18));
            for (var c = e; c <= e + 40; c++) {
              final now = morning(DateTime(2026, 11, c));
              final a = water(p, now), b = water(q, now);
              final why = '$repeat $last edit $e on $c';
              expect(b.nextDue, a.nextDue, reason: why);
              expect(b.missed, a.missed, reason: why);
              expect(b.dueToday, a.dueToday, reason: why);
            }
          }
        }
      }
    });

    test('E9. after any edit, one task at a time and every screen agrees',
        () {
      final starts = [
        plant(water: CareSchedule(Repeat.everyDay, at8, since: nov(20))),
        plant(water: CareSchedule(Repeat.every2Days, at8,
            since: nov(1), lastDone: done(nov(18)))),
        plant(water: CareSchedule(Repeat.every3Days, at8,
            since: nov(1), lastDone: done(nov(21), nov(19)))),
        every14,
      ];
      for (final p in starts) {
        for (final repeat in Repeat.values) {
          for (final time in [at8, at18]) {
            final q = edit(p, nov(22), water: CareSchedule(repeat, time));
            expectScreensAgree(q, nov(22), 40);
          }
        }
      }
    });

    test('E10. watering and fertilizing stay independent', () {
      final p = edit(every14, nov(23),
          water: const CareSchedule(Repeat.everyDay, at18));
      for (var d = 23; d < 50; d++) {
        final now = morning(DateTime(2026, 11, d));
        final before = careState(every14, TaskType.fertilizing, now)!;
        final after = careState(p, TaskType.fertilizing, now)!;
        expect(after.nextDue, before.nextDue);
        expect(after.missed, before.missed);
      }
    });

    test('E11. a new time leaves the count and the streak days as they are',
        () {
      for (var d = 20; d < 60; d++) {
        final day = DateTime(2026, 11, d);
        final edited = edit(every14, nov(20),
            water: const CareSchedule(Repeat.every2Weeks, at18));
        expect(dueTasks([edited], day).length,
            dueTasks([every14], day).length, reason: '$day');
        expect(todays([edited], morning(day)).length,
            todays([every14], morning(day)).length, reason: '$day');
      }
    });

    test('E12. reminders move with an edit and keep their ids', () {
      final p = plant(water: CareSchedule(Repeat.every2Weeks, at8,
          since: nov(1), lastDone: done(nov(22))));
      final now = DateTime(2026, 11, 23, 7);
      final before = planReminders([p], now, en);
      final later = planReminders(
          [edit(p, nov(23), water: const CareSchedule(Repeat.every2Weeks, at18))],
          now, en);
      expect([for (final r in later) r.id], [for (final r in before) r.id]);
      expect([for (final r in later) r.at], [
        for (final r in before)
          DateTime(r.at.year, r.at.month, r.at.day, 18),
      ]);
      expect(later.first.at, DateTime(2026, 12, 6, 18));
      final weekly = planReminders(
          [edit(p, nov(23), water: const CareSchedule(Repeat.everyWeek, at8))],
          now, en);
      expect(weekly.first.at, DateTime(2026, 11, 29, 8));
      expect(weekly.first.id, before.first.id);
    });

    // Every 2 days: done Nov 16 and 18; Nov 20 done late on the 21st; Nov 23
    // done on time.
    final twoDay = CareSchedule(Repeat.every2Days, at8,
        since: nov(1), lastDone: done(nov(18)), previousDone: done(nov(16)));
    final lateTick = twoDay.markedDone(done(nov(21), nov(20)));
    final bothTicks = lateTick.markedDone(done(nov(23)));
    Map<String, TaskLog> logsOn23({bool late = true, bool today = true}) => {
      TaskLog.dateKey(nov(20)): TaskLog(
        date: TaskLog.dateKey(nov(20)),
        late: [if (late) 'p_irrigation'],
        lateOn: {if (late) 'p_irrigation': TaskLog.dateKey(nov(21))},
      ),
      TaskLog.dateKey(nov(23)): TaskLog(
        date: TaskLog.dateKey(nov(23)),
        completed: [if (today) 'p_irrigation'],
      ),
    };

    test('U1. undoing an on-time task: due again, reminder back today', () {
      final now = morning(nov(23));
      final p = plant(water: bothTicks);
      expect(wateringToday(p, now, logsOn23()).single.status,
          TaskStatus.completed);
      final undone = plant(water: bothTicks.markedUndone(nov(23)));
      expect(undone.irrigation!.lastDone, done(nov(21), nov(20)));
      final logs = logsOn23(today: false);
      expect(wateringToday(undone, now, logs).single.status, TaskStatus.due);
      expect(water(undone, now, logs).next, nov(23));
      final early = DateTime(2026, 11, 23, 7);
      expect(planReminders([p], early, en).first.at,
          DateTime(2026, 11, 25, 8));
      expect(planReminders([undone], early, en).first.at,
          DateTime(2026, 11, 23, 8));
    });

    test('U2. undoing the first ever task: due again that day', () {
      final s = CareSchedule(Repeat.everyWeek, at8, since: nov(1));
      // Nov 1 + 3 × 7: due Nov 22, done on time.
      final undone = s.markedDone(done(nov(22))).markedUndone(nov(22));
      expect(undone.lastDone, isNull);
      expect(water(plant(water: undone), morning(nov(22))).dueToday, isTrue);
      expect(water(plant(water: undone), morning(nov(23))).missed, nov(22));
    });

    test('U3. undoing a late task: missed again, no streak credit', () {
      final now = morning(nov(21));
      final p = plant(water: lateTick);
      expect(water(p, now).next, nov(23));
      final undone = plant(water: lateTick.markedUndone(nov(20)));
      expect(undone.irrigation!.lastDone, done(nov(18)));
      expect(water(undone, now).missed, nov(20));
      expect(missedOn([undone], now).single.status, TaskStatus.missed);
      // The day it was for is a task day either way: late never counts.
      expect(dueTasks([p], nov(20)), hasLength(1));
      expect(dueTasks([undone], nov(20)), hasLength(1));
    });

    test('U4. two undos in a row bring back the task actually missed', () {
      final now = morning(nov(23));
      expect(missedOn([plant(water: bothTicks)], now, logsOn23())
          .single.status, TaskStatus.doneLate);
      // Today's first, then the late one.
      final once = bothTicks.markedUndone(nov(23));
      final twice = once.markedUndone(nov(20));
      expect(twice.lastDone, isNull);
      expect(twice.since, nov(20));
      final p = plant(water: twice);
      final logs = logsOn23(late: false, today: false);
      expect(water(p, now, logs).missed, nov(20));
      expect(water(p, now, logs).dueToday, isFalse);
      expect(missedOn([p], now, logs).single.day, nov(20));
      expect(activeWatering(p, now), 1);
      // The other way round: today stays done, then today is due again.
      final other = bothTicks.markedUndone(nov(20));
      expect(other.lastDone, done(nov(23)));
      expect(water(plant(water: other), now).doneToday, isTrue);
      final both = other.markedUndone(nov(23));
      expect(water(plant(water: both), now).dueToday, isTrue);
      expect(activeWatering(plant(water: both), now), 1);
    });

    test('U5. undo works the same after a restart', () {
      FarmPlant reload(FarmPlant p) => FarmPlant.fromMap('p', p.toMap());
      final saved = reload(plant(water: bothTicks));
      expect(saved.irrigation!.lastDone, done(nov(23)));
      expect(saved.irrigation!.previousDone, done(nov(21), nov(20)));
      final once = reload(plant(water: saved.irrigation!.markedUndone(nov(23))));
      expect(once.irrigation!.lastDone, done(nov(21), nov(20)));
      final twice = reload(plant(water: once.irrigation!.markedUndone(nov(20))));
      expect(twice.irrigation!.since, nov(20));
      expect(water(twice, morning(nov(23))).missed, nov(20));
    });

    test('U6. a late task done before a new repeat can still be undone', () {
      // Every 7 days, Nov 13 missed... done late on Nov 21 for Nov 20.
      final s = CareSchedule(Repeat.everyWeek, at8,
          since: nov(1), lastDone: done(nov(21), nov(20)));
      final p = edit(plant(water: s), nov(22),
          water: const CareSchedule(Repeat.every3Days, at8));
      final logs = {
        TaskLog.dateKey(nov(20)): TaskLog(
          date: TaskLog.dateKey(nov(20)),
          late: ['p_irrigation'],
          lateOn: {'p_irrigation': TaskLog.dateKey(nov(21))},
        ),
      };
      expect(water(p, morning(nov(22)), logs).next, nov(24));
      expect(missedOn([p], morning(nov(22)), logs).single.status,
          TaskStatus.doneLate);
      final undone = plant(water: p.irrigation!.markedUndone(nov(20)));
      expect(undone.irrigation!.lastDone, isNull);
      // Nothing done now, and the new repeat started on Nov 22: due today.
      expect(water(undone, morning(nov(22))).dueToday, isTrue);
    });

    test('S1. edits and undo write only the existing fields', () {
      const allowed = {'everyDays', 'time', 'since', 'lastDone', 'previousDone'};
      final schedules = [
        edit(every14, nov(23),
            water: const CareSchedule(Repeat.every2Weeks, at18)).irrigation!,
        edit(every14, nov(23),
            water: const CareSchedule(Repeat.everyWeek, at8)).irrigation!,
        bothTicks.markedUndone(nov(23)),
        bothTicks.markedUndone(nov(23)).markedUndone(nov(20)),
      ];
      for (final s in schedules) {
        final map = s.toMap();
        expect(allowed.containsAll(map.keys), isTrue, reason: '$map');
        for (final key in ['lastDone', 'previousDone']) {
          if (map[key] case final Map done) {
            expect(done.keys.toSet(), {'date', 'due'});
          }
        }
        if (map['since'] case final since?) {
          expect(since, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
        }
      }
      expect(edit(every14, nov(23)).toMap().keys.toSet(),
          every14.toMap().keys.toSet());
      expect(logsOn23()[TaskLog.dateKey(nov(20))]!.toMap().keys.toSet(),
          {'completed', 'late', 'lateOn'});
    });
  });

  group('saved and read back', () {
    test('17. the done days survive a restart', () {
      final p = watered(Repeat.every2Weeks,
          last: done(nov(23), nov(20)), previous: done(nov(6)));
      final map = p.toMap();
      expect((map['irrigation']! as Map)['lastDone'],
          {'date': '2026-11-23', 'due': '2026-11-20'});
      final back = FarmPlant.fromMap('p', map);
      expect(back.irrigation!.lastDone, done(nov(23), nov(20)));
      expect(back.irrigation!.previousDone, done(nov(6)));
      expect(water(back, morning(nov(24))).next, nov(7, 12));
    });

    test('18. older records without the new fields still work', () {
      final schedule = CareSchedule.fromMap({'everyDays': 14, 'time': '08:00'})!;
      expect(schedule.lastDone, isNull);
      expect(schedule.since, isNull);
      // Planted Nov 1, never edited: due on the 1st, 15th, 29th...
      final old = plant(water: schedule);
      expect(water(old, morning(nov(16))).missed, nov(15));
      // A broken done day is ignored, not the whole plant.
      final broken = CareSchedule.fromMap({
        'everyDays': 14,
        'time': '08:00',
        'lastDone': {'date': 'yesterday'},
      })!;
      expect(broken.lastDone, isNull);
      // A late tick saved before its day was kept counts from the next day.
      final log = TaskLog.fromMap('2026-11-15', {
        'completed': <String>[],
        'late': ['p_irrigation'],
      });
      expect(log.lateDoneOn('p_irrigation'), isNull);
      final state = water(old, morning(nov(17)), logOf(log));
      expect(state.anchor, done(nov(16), nov(15)));
      expect(state.next, nov(30));
    });

    test('the task log keeps the day a late task was done', () {
      final log = TaskLog(
        date: '2026-11-20',
        late: ['p_irrigation'],
        lateOn: {'p_irrigation': '2026-11-23'},
      );
      final back = TaskLog.fromMap(log.date, log.toMap());
      expect(back.lateDoneOn('p_irrigation'), nov(23));
      expect(TaskLog(date: 'x').toMap().containsKey('lateOn'), isFalse);
    });

    test('Firestore timestamps read back the same plant', () {
      final p = watered(Repeat.everyWeek, last: done(nov(20)));
      final map = p.toMap();
      expect(map['plantedAt'], isA<Timestamp>());
      expect(FarmPlant.fromMap('p', map).irrigation!.lastDone, done(nov(20)));
    });
  });

  group('every screen agrees', () {
    test('19. Daily Tasks and the next due date are the same task', () {
      for (final repeat in Repeat.values) {
        final p = watered(repeat);
        for (var d = 0; d < 40; d++) {
          final now = morning(DateTime(2026, 11, 20 + d));
          final state = water(p, now);
          final missed = missedOn([p], now).where((t) => !t.done);
          final today = todays([p], now).where((t) => !t.done);
          if (missed.isNotEmpty) {
            expect(state.nextDue, missed.single.day, reason: '$repeat $now');
          } else if (today.isNotEmpty) {
            expect(state.nextDue, today.single.day, reason: '$repeat $now');
          } else {
            expect(state.nextDue.isAfter(state.today), isTrue,
                reason: '$repeat $now');
          }
        }
      }
    });

    testWidgets('19b. Plant Details shows the missed task Daily Tasks shows', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 8000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final p = FarmPlant(
        id: 'p',
        crop: cropCatalog.first,
        name: 'Mint',
        // Watering since yesterday, not done: missed.
        irrigation: CareSchedule(Repeat.everyDay, at8, since: yesterday),
        // Fertilizing done today: next one tomorrow.
        fertilization: CareSchedule(Repeat.everyDay, at8,
            since: yesterday, lastDone: done(today)),
        plantedAt: yesterday,
        createdAt: yesterday,
        updatedAt: yesterday,
      );
      FarmStore.taskLogForTests = (date) => Stream.value(TaskLog(
          date: date,
          completed: date == TaskLog.dateKey(today)
              ? ['p_fertilization']
              : const []));
      FarmStore.growthForTests = (_) => const Stream.empty();
      addTearDown(() {
        FarmStore.taskLogForTests = null;
        FarmStore.growthForTests = null;
        FarmStore.plants.value = const [];
      });
      FarmStore.plants.value = [p];
      await tester.pumpWidget(
        const MaterialApp(home: PlantDetailsScreen(plantId: 'p')),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect([for (final t in missedTasks([p], now, const {})) t.day],
          [yesterday]);
      expect(find.textContaining('Missed: '), findsOneWidget);
      expect(find.textContaining('Next: Tomorrow'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('reminders', () {
    test('20a. after a task is done, reminders count from that day', () {
      final p = watered(Repeat.every2Weeks, last: done(nov(23), nov(20)));
      final plan = planReminders([p], morning(nov(23)), en);
      expect(plan.first.at, DateTime(2026, 12, 7, 8));
    });

    test('20b. a missed task: no reminders for the tasks it stands in for',
        () {
      final p = watered(Repeat.everyDay);
      final plan = planReminders([p], morning(nov(21)), en);
      // Nothing on the 22nd or 23rd; the next on the 24th.
      expect(plan.first.at, DateTime(2026, 11, 24, 8));
      expect(plan.map((r) => r.at).toSet(), hasLength(plan.length));
    });

    test('20c. after it expires, the rhythm carries on', () {
      final p = watered(Repeat.every5Days);
      final plan = planReminders([p], morning(nov(24)), en);
      expect(plan.first.at, DateTime(2026, 11, 25, 8));
      expect(plan[1].at, DateTime(2026, 11, 30, 8));
    });

    test('20d. done late: reminders start from the day it was done', () {
      final p = watered(Repeat.every2Days, last: done(nov(22), nov(20)));
      final plan = planReminders([p], morning(nov(22)), en);
      expect(plan.first.at, DateTime(2026, 11, 24, 8));
    });

    test('20e. a changed schedule: reminders from the change', () {
      final p = watered(Repeat.every2Weeks, last: done(nov(15))).edited(
        name: 'Mint',
        irrigation: const CareSchedule(Repeat.everyWeek, at17),
        fertilization: null,
        today: morning(nov(24)),
      );
      final plan = planReminders([p], morning(nov(24)), en);
      expect(plan.first.at, DateTime(2026, 11, 24, 17, 30));
      expect(plan[1].at, DateTime(2026, 12, 1, 17, 30));
    });

    test('20f. a task ticked late in the logs plans from today', () {
      final p = watered(Repeat.every2Days);
      final logs = logOf(TaskLog(
          date: TaskLog.dateKey(nov(20)),
          late: ['p_irrigation'],
          lateOn: {'p_irrigation': '2026-11-22'}));
      final plan = planReminders([p], morning(nov(22)), en, logs: logs);
      expect(plan.first.at, DateTime(2026, 11, 24, 8));
    });
  });

  group('calendar edges', () {
    test('21a. a day ends at midnight', () {
      final p = watered(Repeat.everyDay);
      final lateEvening = DateTime(2026, 11, 20, 23, 59);
      expect(water(p, lateEvening).dueToday, isTrue);
      expect(todays([p], lateEvening).single.status, TaskStatus.due);
      final midnight = DateTime(2026, 11, 21);
      expect(water(p, midnight).missed, nov(20));
      expect(todays([p], midnight), isEmpty);
    });

    test('21b. across month and year ends', () {
      final p = watered(Repeat.everyDay, since: nov(31, 10));
      expect(water(p, morning(nov(3))).missed, nov(31, 10));
      expect(water(p, morning(nov(4))).dueToday, isTrue);
      final yearEnd = watered(Repeat.every2Weeks,
          since: DateTime(2026, 12, 1), last: done(DateTime(2026, 12, 25)));
      expect(water(yearEnd, morning(DateTime(2026, 12, 26))).next,
          DateTime(2027, 1, 8));
      final monthly = watered(Repeat.everyMonth,
          since: DateTime(2026, 1, 1), last: done(DateTime(2026, 1, 31)));
      // A month is 30 days.
      expect(water(monthly, morning(DateTime(2026, 2, 1))).next,
          DateTime(2026, 3, 2));
    });

    test('22. days are calendar days: the time of day never shifts', () {
      // Over the dates where many places change their clocks (Mar 29 and
      // Oct 25 2026 in Europe), the task stays at 08:00.
      for (final last in [DateTime(2026, 3, 20), DateTime(2026, 10, 20)]) {
        final p = watered(Repeat.every2Weeks, since: last, last: done(last));
        final state = water(p, morning(last));
        final at = state.at(state.next);
        expect(at.hour, 8);
        expect(at.minute, 0);
        expect(DateTime(at.year, at.month, at.day),
            DateTime(last.year, last.month, last.day + 14));
        for (final day in state.taskDays(last, DateTime(2026, 12, 31))) {
          expect(state.at(day).hour, 8);
        }
      }
    });
  });

  group('streak and counts', () {
    FarmStats stats(int streak, String? last) =>
        FarmStats(currentStreak: streak, lastCompletedDate: last, lands: 1);

    test('23a. a missed day still breaks the streak', () {
      final p = watered(Repeat.everyDay, last: done(nov(20)));
      expect(streakAfterMissedDays(stats(3, '2026-11-20'), [p], nov(22))
          .currentStreak, 0);
    });

    test('23b. doing it late doesn\'t give the day back', () {
      // Done on time on the 20th, the 21st missed and done late on the 22nd.
      final p = watered(Repeat.everyDay,
          last: done(nov(22), nov(21)), previous: done(nov(20)));
      expect(dueTasks([p], nov(21)), hasLength(1));
      expect(dueTasks([p], nov(22)), isEmpty);
      expect(streakAfterMissedDays(stats(3, '2026-11-20'), [p], nov(23))
          .currentStreak, 0);
    });

    test('23c. a missed task that expires is never counted as done', () {
      final p = watered(Repeat.everyDay, last: done(nov(19)));
      expect(water(p, morning(nov(24))).anchor, done(nov(19)));
      expect(streakAfterMissedDays(stats(3, '2026-11-19'), [p], nov(24))
          .currentStreak, 0);
    });

    test('23d. while every task is done, the streak carries on', () {
      final p = watered(Repeat.every3Days, last: done(nov(20)));
      expect(streakAfterMissedDays(stats(3, '2026-11-20'), [p], nov(23))
          .currentStreak, 3);
      // Un-ticking today goes back to the day before with a task.
      expect(previousTaskDay([p], nov(23)), nov(20));
    });

    test('23e. the day\'s count, with daily, 2- and 3-day schedules', () {
      final plants = [
        for (final (id, repeat) in [
          ('a', Repeat.everyDay),
          ('b', Repeat.every2Days),
          ('c', Repeat.every3Days),
        ])
          plant(
            id: id,
            water: CareSchedule(repeat, at8, since: nov(20)),
          ),
      ];
      int count(int day) => todays(plants, morning(nov(day))).length;
      expect([for (var d = 20; d <= 26; d++) count(d)],
          [3, 0, 0, 0, 2, 0, 1]);
      // Each counted task has its own id: no task counted twice.
      final ids = [for (final t in todays(plants, morning(nov(20)))) t.id];
      expect(ids.toSet(), hasLength(ids.length));
    });
  });

  test('CareSchedule.firstDayFrom counts calendar days', () {
    expect(CareSchedule.firstDayFrom(nov(1), 14, nov(16)), nov(29));
    expect(CareSchedule.firstDayFrom(nov(1), 14, nov(15)), nov(15));
    expect(CareSchedule.firstDayFrom(nov(10), 7, nov(1)), nov(10));
  });

  test('activeStep: the missed days are always covered', () {
    expect([for (final r in Repeat.values) activeStep(r.days)],
        [4, 4, 6, 4, 5, 6, 7, 14, 21, 30]);
  });
}
