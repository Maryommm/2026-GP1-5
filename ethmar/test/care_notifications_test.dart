import 'package:ethmar/l10n/app_strings.dart';
import 'package:ethmar/models/care_task.dart';
import 'package:ethmar/models/crop_catalog.dart';
import 'package:ethmar/models/daily_task.dart';
import 'package:ethmar/models/farm_plant.dart';
import 'package:ethmar/services/care_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final en = S(AppStrings.en);
final ar = S(AppStrings.ar);

FarmPlant plant(
  String id, {
  CareSchedule? water,
  CareSchedule? fertilize,
  DateTime? planted,
  String name = 'Mint',
}) =>
    FarmPlant(
      id: id,
      crop: cropCatalog.first,
      name: name,
      irrigation: water,
      fertilization: fertilize,
      plantedAt: planted ?? DateTime(2026, 11, 1),
    );

const at8 = TimeOfDay(hour: 8, minute: 0);
const at17 = TimeOfDay(hour: 17, minute: 30);

void main() {
  group('dueTasks', () {
    test('a schedule is due on the planting day and every N days after', () {
      final p = plant('a', water: const CareSchedule(Repeat.every3Days, at8));
      bool due(int day) => dueTasks([p], DateTime(2026, 11, day)).isNotEmpty;
      expect([for (var d = 1; d <= 10; d++) due(d)],
          [true, false, false, true, false, false, true, false, false, true]);
    });

    test('nothing is due before planting or when switched off', () {
      final p = plant('a', water: const CareSchedule(Repeat.everyDay, at8));
      expect(dueTasks([p], DateTime(2026, 10, 31)), isEmpty);
      expect(dueTasks([plant('b')], DateTime(2026, 11, 5)), isEmpty);
    });

    test('tasks come at their alarm time, in time order', () {
      final tasks = dueTasks([
        plant('a', water: const CareSchedule(Repeat.everyDay, at17)),
        plant('b', fertilize: const CareSchedule(Repeat.everyDay, at8)),
      ], DateTime(2026, 11, 5, 23));
      expect([for (final t in tasks) t.type],
          [TaskType.fertilizing, TaskType.watering]);
      expect(tasks.first.at, DateTime(2026, 11, 5, 8));
      expect(tasks.last.at, DateTime(2026, 11, 5, 17, 30));
    });

    test('a monthly schedule counts 30 days across month ends', () {
      final p = plant('a',
          water: const CareSchedule(Repeat.everyMonth, at8),
          planted: DateTime(2026, 1, 20));
      expect(dueTasks([p], DateTime(2026, 2, 19)), hasLength(1));
      expect(dueTasks([p], DateTime(2026, 2, 20)), isEmpty);
    });
  });

  group('reminderId', () {
    test('stays the same and differs by plant, task type and slot', () {
      final ids = {
        for (final id in ['plantA', 'plantB'])
          for (final type in TaskType.values)
            for (var slot = 0; slot < remindersPerTask; slot++)
              reminderId(id, type, slot),
      };
      expect(ids, hasLength(2 * 2 * remindersPerTask));
      expect(reminderId('plantA', TaskType.watering, 0),
          reminderId('plantA', TaskType.watering, 0));
      for (final id in ids) {
        expect(id, inInclusiveRange(0, 0x7fffffff));
      }
    });
  });

  group('planReminders', () {
    final now = DateTime(2026, 11, 5, 9);

    test('the next alarms of each task, only in the future, soonest first', () {
      final plan = planReminders([
        plant('a', water: const CareSchedule(Repeat.everyDay, at8)),
        plant('b', fertilize: const CareSchedule(Repeat.everyWeek, at17)),
      ], now, en);
      final water = plan.where((r) => r.title.contains('Mint') &&
          !r.title.contains('feed') && !r.title.contains('hungry') &&
          !r.title.contains('Fertiliz')).toList();
      // 08:00 today has passed, so it starts tomorrow.
      expect([for (final r in water) r.at], [
        DateTime(2026, 11, 6, 8),
        DateTime(2026, 11, 7, 8),
        DateTime(2026, 11, 8, 8),
        DateTime(2026, 11, 9, 8),
      ]);
      expect(plan, hasLength(2 * remindersPerTask));
      expect(plan.first.at, DateTime(2026, 11, 6, 8));
      for (var i = 1; i < plan.length; i++) {
        expect(plan[i].at.isBefore(plan[i - 1].at), isFalse);
      }
    });

    test('the same plants give the same ids, so nothing is duplicated', () {
      final plants = [
        plant('a', water: const CareSchedule(Repeat.every2Days, at8)),
      ];
      final first = [for (final r in planReminders(plants, now, en)) r.id];
      final again = [for (final r in planReminders(plants, now, en)) r.id];
      expect(again, first);
      expect(first.toSet(), hasLength(first.length));
    });

    test('an edited schedule keeps its ids and moves its alarms', () {
      final before = planReminders(
          [plant('a', water: const CareSchedule(Repeat.everyDay, at8))], now, en);
      final after = planReminders(
          [plant('a', water: const CareSchedule(Repeat.everyDay, at17))], now, en);
      expect([for (final r in after) r.id], [for (final r in before) r.id]);
      expect(after.first.at, DateTime(2026, 11, 5, 17, 30));
    });

    test('unsaved plants and switched-off schedules get nothing', () {
      final unsaved = FarmPlant(
        crop: cropCatalog.first,
        name: 'New',
        irrigation: const CareSchedule(Repeat.everyDay, at8),
      );
      expect(planReminders([unsaved, plant('b')], now, en), isEmpty);
    });

    test('a monthly schedule still gets its next alarms', () {
      final plan = planReminders([
        plant('a', water: const CareSchedule(Repeat.everyMonth, at8)),
      ], now, en);
      expect(plan, hasLength(remindersPerTask));
    });

    test('never more than Android allows', () {
      final plants = [
        for (var i = 0; i < 100; i++)
          plant('p$i',
              water: const CareSchedule(Repeat.everyDay, at8),
              fertilize: const CareSchedule(Repeat.everyDay, at17)),
      ];
      final plan = planReminders(plants, now, en);
      expect(plan, hasLength(maxReminders));
      expect(plan.map((r) => r.id).toSet(), hasLength(maxReminders));
    });

    test('the text is in the app language, with the plant name', () {
      final plan = planReminders([
        plant('a', name: 'نعناعي', fertilize: const CareSchedule(Repeat.everyDay, at8)),
      ], now, ar);
      for (final r in plan) {
        expect(r.title, contains('نعناعي'));
        expect(r.body, isNotEmpty);
      }
    });

    test('the message changes from day to day and stays the same on a sync', () {
      final plants = [
        plant('a', water: const CareSchedule(Repeat.everyDay, at8)),
      ];
      final plan = planReminders(plants, now, en);
      expect({for (final r in plan.take(3)) r.title}, hasLength(3));
      expect([for (final r in planReminders(plants, now, en)) r.title],
          [for (final r in plan) r.title]);
    });

    test('every message exists in both languages', () {
      for (final lang in [en, ar]) {
        for (final watering in [true, false]) {
          for (var v = 0; v < S.reminderVariants; v++) {
            final title = lang.reminderTitle(
                watering: watering, variant: v, plant: 'X');
            final body = lang.reminderBody(watering: watering, variant: v);
            expect(title, contains('X'));
            expect(title, isNot(startsWith('reminder')));
            expect(body, isNot(startsWith('reminder')));
          }
        }
      }
    });
  });
}
