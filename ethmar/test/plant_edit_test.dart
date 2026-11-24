// Editing a plant while its tasks are done elsewhere: the Edit Plant screen
// writes only what the user changed, over the plant as it is saved now.
//
// Firestore isn't used: a saved plant is a map, and updates are applied to
// it the way Firestore applies them (dotted field paths, deletes). Task
// ticks use the app's own update (PlantService.doneDaysUpdate). The
// transaction is simulated: a write that lands between the read and the
// commit makes it run again on the new values, as Firestore does.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ethmar/l10n/app_strings.dart';
import 'package:ethmar/models/care_task.dart';
import 'package:ethmar/models/crop_catalog.dart';
import 'package:ethmar/models/daily_task.dart';
import 'package:ethmar/models/farm_plant.dart';
import 'package:ethmar/models/plant_edit.dart';
import 'package:ethmar/services/care_notifications.dart';
import 'package:ethmar/services/plant_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const at8 = TimeOfDay(hour: 8, minute: 0);
const at18 = TimeOfDay(hour: 18, minute: 0);

DateTime nov(int day, [int month = 11]) => DateTime(2026, month, day);
CareDone done(DateTime on, [DateTime? due]) =>
    CareDone(date: on, due: due ?? on);

/// One plant document, as saved.
class SavedPlant {
  SavedPlant(this.data);

  Map<String, dynamic>? data;

  /// Bumped on every write, so a transaction can tell it changed.
  int version = 0;

  FarmPlant get plant => FarmPlant.fromMap('p', data!);

  /// Applies a Firestore update: dotted paths set nested fields; a delete
  /// (DeleteField or FieldValue.delete()) removes the field.
  void update(Map<String, Object?> fields) {
    final next = _copy(data!);
    for (final MapEntry(:key, :value) in fields.entries) {
      final path = key.split('.');
      var map = next;
      for (final part in path.take(path.length - 1)) {
        map = map[part] as Map<String, dynamic>;
      }
      if (value is DeleteField || value is FieldValue) {
        map.remove(path.last);
      } else {
        map[path.last] = value;
      }
    }
    data = next;
    version++;
  }

  /// Device B ticks (or un-ticks) the task of [type] due on [due], done on
  /// [on], with the app's own update.
  void tick(TaskType type, DateTime due, {DateTime? on, bool done = true}) {
    final change = PlantService.doneDaysUpdate(
      data,
      type,
      (s) => done
          ? s.markedDone(CareDone(date: on ?? due, due: due))
          : s.markedUndone(due),
    );
    if (change != null) update(change);
  }

  /// Device A saves [edit] on [today], as PlantService.editPlant does: read,
  /// work out the update, commit. [meanwhile] runs between the read and
  /// the commit of the first attempt (another device writing); the commit
  /// then fails and the transaction runs again, as Firestore does.
  /// Returns how many attempts it took.
  int save(PlantEdit edit, DateTime today, {void Function()? meanwhile}) {
    for (var attempt = 1; attempt <= 5; attempt++) {
      final read = version;
      final snapshot = data;
      if (snapshot == null) throw StateError('Plant no longer exists.');
      final fields = edit.updateOver(_copy(snapshot), today, today);
      if (attempt == 1) meanwhile?.call();
      if (version != read) continue; // Changed since the read: run again.
      if (fields.isNotEmpty) update(fields);
      return attempt;
    }
    throw StateError('Too much contention.');
  }
}

Map<String, dynamic> _copy(Map<String, dynamic> map) => {
  for (final MapEntry(:key, :value) in map.entries)
    key: value is Map ? _copy(Map<String, dynamic>.from(value)) : value,
};

/// Watering every 14 days at 08:00 (last done Nov 8), fertilizing every
/// 7 days at 08:00, both from Nov 1.
SavedPlant savedPlant() => SavedPlant(FarmPlant(
  id: 'p',
  crop: cropCatalog.first,
  name: 'Mint',
  irrigation: CareSchedule(Repeat.every2Weeks, at8,
      since: nov(1), lastDone: done(nov(8))),
  fertilization: CareSchedule(Repeat.everyWeek, at8, since: nov(1)),
  plantedAt: nov(1),
  createdAt: nov(1),
  updatedAt: nov(1),
).toMap());

/// Device A's form, opened on [opened], with its changes.
PlantEdit form(
  FarmPlant opened, {
  String? name,
  CareSchedule? water,
  CareSchedule? fertilize,
  bool waterOff = false,
}) => PlantEdit(
  opened: opened,
  name: name ?? opened.name,
  irrigation: waterOff
      ? null
      : water ?? _asForm(opened.irrigation),
  fertilization: fertilize ?? _asForm(opened.fertilization),
);

/// What the form holds for a saved schedule: its repeat and time only.
CareSchedule? _asForm(CareSchedule? s) =>
    s == null ? null : CareSchedule(s.repeat, s.time);

CareState water(FarmPlant p, DateTime now) =>
    careState(p, TaskType.watering, now)!;

void main() {
  final today = nov(22);
  final morning = DateTime(2026, 11, 22, 9);

  test('1. renamed while watering was done elsewhere: both kept', () {
    final doc = savedPlant();
    final opened = doc.plant; // Device A opens Edit Plant.
    doc.tick(TaskType.watering, nov(22)); // Device B waters.
    final fields = form(opened, name: 'My mint')
        .updateOver(doc.data!, today, today);
    expect(fields.keys.toSet(), {'name', 'updatedAt'});
    doc.save(form(opened, name: 'My mint'), today);
    expect(doc.plant.name, 'My mint');
    expect(doc.plant.irrigation!.lastDone, done(nov(22)));
    expect(doc.plant.irrigation!.previousDone, done(nov(8)));
    expect(water(doc.plant, morning).next, nov(6, 12));
  });

  test('2. new watering time after it was done elsewhere: Dec 6 at 18:00',
      () {
    final doc = savedPlant();
    final opened = doc.plant;
    doc.tick(TaskType.watering, nov(22));
    final edit = form(opened,
        water: const CareSchedule(Repeat.every2Weeks, at18));
    expect(edit.updateOver(doc.data!, today, today).keys.toSet(),
        {'irrigation.time', 'updatedAt'});
    doc.save(edit, today);
    final s = doc.plant.irrigation!;
    expect(s.lastDone, done(nov(22)));
    expect(s.time, at18);
    final state = water(doc.plant, morning);
    expect(state.at(state.next), DateTime(2026, 12, 6, 18));
    // The reminders follow the saved plant.
    final plan = planReminders([doc.plant], morning, S(AppStrings.en));
    expect(
        plan.singleWhere((r) =>
            r.id == reminderId('p', TaskType.watering, 0)).at,
        DateTime(2026, 12, 6, 18));
  });

  test('3. new watering repeat after it was done elsewhere: counts from '
      'that day', () {
    final doc = savedPlant();
    final opened = doc.plant;
    doc.tick(TaskType.watering, nov(22));
    final edit = form(opened,
        water: const CareSchedule(Repeat.everyWeek, at8));
    expect(edit.updateOver(doc.data!, today, today).keys.toSet(),
        {'irrigation.everyDays', 'irrigation.since', 'updatedAt'});
    doc.save(edit, today);
    expect(doc.plant.irrigation!.lastDone, done(nov(22)));
    expect(doc.plant.irrigation!.repeat, Repeat.everyWeek);
    // Nov 22 + 7, not Nov 8 + 7 (which would be due today).
    expect(water(doc.plant, morning).next, nov(29));
    expect(water(doc.plant, morning).dueToday, isFalse);
  });

  test('4. watering edited while fertilizing was done elsewhere', () {
    final doc = savedPlant();
    final opened = doc.plant;
    doc.tick(TaskType.fertilizing, nov(22)); // Due Nov 22 (1 + 3 × 7).
    final edit = form(opened,
        water: const CareSchedule(Repeat.every3Days, at18));
    final fields = edit.updateOver(doc.data!, today, today);
    expect(fields.keys.where((k) => k.startsWith('fertilization')), isEmpty);
    doc.save(edit, today);
    expect(doc.plant.fertilization!.lastDone, done(nov(22)));
    expect(doc.plant.irrigation!.repeat, Repeat.every3Days);
    expect(doc.plant.irrigation!.lastDone, done(nov(8)));
    // And the other way round: fertilizing edited while watering is done.
    final doc2 = savedPlant();
    final opened2 = doc2.plant;
    doc2.tick(TaskType.watering, nov(22));
    doc2.save(form(opened2,
        fertilize: const CareSchedule(Repeat.every2Weeks, at18)), today);
    expect(doc2.plant.irrigation!.lastDone, done(nov(22)));
    expect(doc2.plant.irrigation!.time, at8);
    expect(doc2.plant.fertilization!.repeat, Repeat.every2Weeks);
  });

  test('5. two phones edit different things: both changes stay', () {
    final doc = savedPlant();
    final onA = doc.plant, onB = doc.plant; // Both open Edit Plant.
    doc.save(form(onB, water: const CareSchedule(Repeat.every2Weeks, at18)),
        today);
    doc.save(form(onA, name: 'Garden mint'), today);
    expect(doc.plant.name, 'Garden mint');
    expect(doc.plant.irrigation!.time, at18);

    // A new repeat here, a new time there, on the same schedule.
    final doc2 = savedPlant();
    final a = doc2.plant, b = doc2.plant;
    doc2.save(form(b, water: const CareSchedule(Repeat.every2Weeks, at18)),
        today);
    doc2.save(form(a, water: const CareSchedule(Repeat.everyWeek, at8)),
        today);
    expect(doc2.plant.irrigation!.repeat, Repeat.everyWeek);
    expect(doc2.plant.irrigation!.time, at18);

    // A renamed elsewhere, B didn't touch the name: B keeps it.
    final doc3 = savedPlant();
    final c = doc3.plant, d = doc3.plant;
    doc3.save(form(c, name: 'Renamed'), today);
    doc3.save(form(d, fertilize: const CareSchedule(Repeat.everyDay, at8)),
        today);
    expect(doc3.plant.name, 'Renamed');
  });

  test('6. nothing changed: nothing is written', () {
    final doc = savedPlant();
    final opened = doc.plant;
    doc.tick(TaskType.watering, nov(22));
    final before = doc.version;
    expect(form(opened).updateOver(doc.data!, today, today), isEmpty);
    doc.save(form(opened), today);
    expect(doc.version, before);
    // Renaming only never writes a schedule.
    final fields =
        form(opened, name: 'X').updateOver(doc.data!, today, today);
    expect(fields.keys.where((k) => k.contains('irrigation') ||
        k.contains('fertilization')), isEmpty);
  });

  test('7. an undo elsewhere isn\'t lost to an edit', () {
    final doc = savedPlant();
    final opened = doc.plant;
    doc.tick(TaskType.watering, nov(22));
    final ticked = doc.plant;
    doc.tick(TaskType.watering, nov(22), done: false); // Un-ticked.
    doc.save(form(opened, name: 'X',
        water: const CareSchedule(Repeat.every2Weeks, at18)), today);
    expect(doc.plant.irrigation!.lastDone, done(nov(8)));
    expect(water(doc.plant, morning).dueToday, isTrue);
    // Ticked again after the screen opened with the un-ticked copy.
    final doc2 = SavedPlant(_copy(ticked.toMap()));
    final stale = doc2.plant;
    doc2.tick(TaskType.watering, nov(22), done: false);
    doc2.tick(TaskType.watering, nov(22));
    doc2.save(form(stale, name: 'Y'), today);
    expect(doc2.plant.irrigation!.lastDone, done(nov(22)));
    // The start day an un-tick moves is kept by a later time edit.
    final doc3 = SavedPlant(FarmPlant(
      id: 'p',
      crop: cropCatalog.first,
      name: 'Mint',
      irrigation: CareSchedule(Repeat.everyWeek, at8, since: nov(1)),
      plantedAt: nov(1),
      createdAt: nov(1),
      updatedAt: nov(1),
    ).toMap());
    final opened3 = doc3.plant;
    doc3.tick(TaskType.watering, nov(22));
    doc3.tick(TaskType.watering, nov(22), done: false);
    expect(doc3.plant.irrigation!.since, nov(22));
    doc3.save(form(opened3, water: const CareSchedule(Repeat.everyWeek, at18)),
        today);
    expect(doc3.plant.irrigation!.since, nov(22));
    expect(water(doc3.plant, morning).dueToday, isTrue);
  });

  test('8. a tick between the read and the commit: run again, both kept',
      () {
    final doc = savedPlant();
    final opened = doc.plant;
    final attempts = doc.save(
      form(opened, name: 'X',
          water: const CareSchedule(Repeat.everyWeek, at18)),
      today,
      meanwhile: () => doc.tick(TaskType.watering, nov(22)),
    );
    expect(attempts, 2);
    expect(doc.plant.name, 'X');
    expect(doc.plant.irrigation!.lastDone, done(nov(22)));
    expect(water(doc.plant, morning).next, nov(29));
    expect(doc.plant.irrigation!.time, at18);
  });

  test('8b. the plant was deleted meanwhile: fails, nothing is written', () {
    final doc = savedPlant();
    final opened = doc.plant;
    doc.data = null;
    expect(() => doc.save(form(opened, name: 'X'), today), throwsStateError);
    expect(doc.data, isNull);
  });

  test('9. switching a schedule off or on only touches that schedule', () {
    final doc = savedPlant();
    final opened = doc.plant;
    doc.tick(TaskType.fertilizing, nov(22));
    doc.save(form(opened, waterOff: true), today);
    expect(doc.plant.irrigation, isNull);
    expect(doc.plant.fertilization!.lastDone, done(nov(22)));
    // Switched on again: a new schedule from today.
    final off = doc.plant;
    doc.save(form(off, water: const CareSchedule(Repeat.every3Days, at8)),
        today);
    expect(doc.plant.irrigation!.since, today);
    expect(water(doc.plant, morning).dueToday, isTrue);
    expect(doc.plant.fertilization!.lastDone, done(nov(22)));
  });

  test('10. only existing fields are written', () {
    final doc = savedPlant();
    final opened = doc.plant;
    doc.save(form(opened, name: 'X',
        water: const CareSchedule(Repeat.everyWeek, at18),
        fertilize: const CareSchedule(Repeat.every3Days, at8)), today);
    expect(doc.data!.keys.toSet(), opened.toMap().keys.toSet());
    for (final field in ['irrigation', 'fertilization']) {
      expect(
        {'everyDays', 'time', 'since', 'lastDone', 'previousDone'}
            .containsAll((doc.data![field] as Map).keys),
        isTrue,
      );
    }
  });
}
