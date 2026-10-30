import 'package:ethmar/data/sample_plants.dart';
import 'package:ethmar/models/crop_catalog.dart';
import 'package:ethmar/models/farm_plant.dart';
import 'package:ethmar/models/farm_spot.dart';
import 'package:ethmar/models/farm_stats.dart';
import 'package:ethmar/models/task_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CareSchedule', () {
    test('saves as everyDays and "HH:mm", and reads back the same', () {
      const schedule = CareSchedule(
        Repeat.every2Weeks,
        TimeOfDay(hour: 7, minute: 5),
      );
      final map = schedule.toMap();
      expect(map, {'everyDays': 14, 'time': '07:05'});

      final back = CareSchedule.fromMap(map)!;
      expect(back.repeat, Repeat.every2Weeks);
      expect(back.time, const TimeOfDay(hour: 7, minute: 5));
    });

    test('null means switched off', () {
      expect(CareSchedule.fromMap(null), isNull);
    });

    test('rejects a repeat or time the app does not offer', () {
      expect(
        () => CareSchedule.fromMap({'everyDays': 5, 'time': '07:00'}),
        throwsFormatException,
      );
      expect(
        () => CareSchedule.fromMap({'everyDays': 1, 'time': '7:00'}),
        throwsFormatException,
      );
      expect(
        () => CareSchedule.fromMap({'everyDays': 1, 'time': '24:00'}),
        throwsFormatException,
      );
    });
  });

  group('GrowthEntry', () {
    test('round-trips with a photo', () {
      final entry = samplePlants.first.growth.last;
      expect(entry.photo, isNotNull);

      final back = GrowthEntry.fromMap(entry.id!, entry.toMap());
      expect(back.id, entry.id);
      expect(back.date, entry.date);
      expect(back.notes, entry.notes);
      expect(back.photo!.toMap(), entry.photo!.toMap());
    });

    test('round-trips without notes or a photo', () {
      final entry = GrowthEntry(id: 'e1', date: DateTime(2026, 10, 1, 8));
      final map = entry.toMap();
      expect(map['notes'], isNull);
      expect(map['photo'], isNull);

      final back = GrowthEntry.fromMap('e1', map);
      expect(back.date, entry.date);
      expect(back.notes, isNull);
      expect(back.photo, isNull);
    });
  });

  group('FarmPlant', () {
    test('every sample plant round-trips (growth is saved separately)', () {
      for (final plant in samplePlants) {
        final map = plant.toMap();
        expect(map['cropId'], plant.crop.id);
        expect(map['category'], plant.crop.category.name);

        final back = FarmPlant.fromMap(plant.id!, map);
        expect(back.id, plant.id);
        expect(back.crop, same(plant.crop));
        expect(back.name, plant.name);
        expect(back.land, plant.land);
        expect(back.square, plant.square);
        expect(back.irrigation?.toMap(), plant.irrigation?.toMap());
        expect(back.fertilization?.toMap(), plant.fertilization?.toMap());
        expect(back.plantedAt, plant.plantedAt);
        expect(back.createdAt, plant.createdAt);
        expect(back.updatedAt, plant.updatedAt);
        expect(back.growth, isEmpty);
      }
    });

    test('rejects an unknown cropId', () {
      final map = samplePlants.first.toMap()..['cropId'] = 'not_a_crop';
      expect(() => FarmPlant.fromMap('p1', map), throwsFormatException);
    });

    test('edited() and withGrowth() keep the id, spot and dates', () {
      final plant = samplePlants.first;
      final edited = plant.edited(
        name: 'Renamed',
        irrigation: null,
        fertilization: plant.fertilization,
      );
      expect(edited.id, plant.id);
      expect(edited.land, plant.land);
      expect(edited.square, plant.square);
      expect(edited.createdAt, plant.createdAt);
      expect(edited.updatedAt.isAfter(plant.updatedAt), isTrue);
      expect(edited.irrigation, isNull);

      final grown = plant.withGrowth(GrowthEntry(date: DateTime(2026, 10, 20)));
      expect(grown.id, plant.id);
      expect(grown.updatedAt, plant.updatedAt);
      expect(grown.growth, hasLength(plant.growth.length + 1));
    });
  });

  group('TaskLog', () {
    test('round-trips and builds ids and date keys', () {
      final log = TaskLog(
        date: TaskLog.dateKey(DateTime(2026, 3, 7, 23, 59)),
        completed: [
          TaskLog.irrigationTaskId('p1'),
          TaskLog.fertilizationTaskId('p2'),
        ],
      );
      expect(log.date, '2026-03-07');
      expect(log.completed, ['p1_irrigation', 'p2_fertilization']);

      final back = TaskLog.fromMap(log.date, log.toMap());
      expect(back.date, log.date);
      expect(back.completed, log.completed);
      expect(back.isCompleted('p1_irrigation'), isTrue);
      expect(back.isCompleted('p1_fertilization'), isFalse);
    });
  });

  group('FarmStats', () {
    test('round-trips, with and without a last completed date', () {
      for (final stats in [sampleStats, const FarmStats()]) {
        final back = FarmStats.fromMap(stats.toMap());
        expect(back.currentStreak, stats.currentStreak);
        expect(back.lastCompletedDate, stats.lastCompletedDate);
        expect(back.lands, stats.lands);
      }
    });

    test('rejects lands outside 1-9', () {
      expect(
        () => FarmStats.fromMap({
          'currentStreak': 0,
          'lastCompletedDate': null,
          'lands': 10,
        }),
        throwsFormatException,
      );
    });
  });

  group('firstFreeSpot', () {
    FarmPlant at(int land, int square) => FarmPlant(
      crop: cropCatalog.first,
      name: 'x',
      land: land,
      square: square,
    );

    test('an empty farm starts at land 0, square 0', () {
      expect(firstFreeSpot(const [], 1), (land: 0, square: 0));
    });

    test('fills a gap before moving on', () {
      expect(firstFreeSpot([at(0, 0), at(0, 2)], 1), (land: 0, square: 1));
    });

    test('moves to the next land, or null when every land is full', () {
      final fullLand = [for (var s = 0; s < 25; s++) at(0, s)];
      expect(firstFreeSpot(fullLand, 1), isNull);
      expect(firstFreeSpot(fullLand, 2), (land: 1, square: 0));
    });
  });
}
