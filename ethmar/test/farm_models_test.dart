import 'dart:io';

import 'package:ethmar/data/sample_plants.dart';
import 'package:ethmar/models/crop_catalog.dart';
import 'package:ethmar/models/crop_recommendation.dart' show CropCategory;
import 'package:ethmar/models/farm_plant.dart';
import 'package:ethmar/models/farm_spot.dart';
import 'package:ethmar/models/farm_stats.dart';
import 'package:ethmar/models/task_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('crop search', () {
    CatalogCrop crop(String id) => cropCatalog.firstWhere((c) => c.id == id);

    test('matches English names in any case', () {
      expect(crop('tomato').matches('TOMA'), isTrue);
      expect(crop('sweet_potato').matches('  sweet   pot '), isTrue);
      expect(crop('tomato').matches('cucumber'), isFalse);
      expect(crop('tomato').matches(''), isTrue);
    });

    test('matches Arabic names despite marks, letter variants and "ال"', () {
      expect(crop('tomato').matches('الطماطم'), isTrue);
      expect(crop('tomato').matches('طَمَاطِم'), isTrue);
      expect(crop('sweet_potato').matches('بطاطا حلوه'), isTrue);
      expect(crop('cucumber').matches('طماطم'), isFalse);
    });
  });

  group('CareSchedule', () {
    test('saves required since and reads back the same', () {
      final schedule = CareSchedule(
        Repeat.every2Weeks,
        const TimeOfDay(hour: 7, minute: 5),
        since: DateTime(2026, 11, 26),
      );
      final map = schedule.toMap();
      expect(map, {'everyDays': 14, 'time': '07:05', 'since': '2026-11-26'});

      final back = CareSchedule.fromMap(map)!;
      expect(back.repeat, Repeat.every2Weeks);
      expect(back.time, const TimeOfDay(hour: 7, minute: 5));
      expect(back.since, DateTime(2026, 11, 26));
    });

    test(
      'assigns since on creation and rejects it when missing in storage',
      () {
        final before = DateTime.now();
        final schedule = CareSchedule(
          Repeat.everyDay,
          const TimeOfDay(hour: 7, minute: 0),
        );
        final after = DateTime.now();
        expect(schedule.since, DateTime(before.year, before.month, before.day));
        expect(schedule.since, DateTime(after.year, after.month, after.day));
        expect(
          () => CareSchedule.fromMap({'everyDays': 1, 'time': '07:00'}),
          throwsFormatException,
        );
      },
    );

    test('rejects a saved value that is not a map', () {
      expect(() => CareSchedule.fromMap('daily'), throwsFormatException);
      expect(() => JourneyPhoto.fromMap(7), throwsFormatException);
    });

    test('null means switched off', () {
      expect(CareSchedule.fromMap(null), isNull);
    });

    test('offers every day up to a week, every week up to 3, then a month', () {
      expect(
        [for (final r in Repeat.values) r.days],
        [1, 2, 3, 4, 5, 6, 7, 14, 21, 30],
      );
      for (final r in Repeat.values) {
        expect(Repeat.fromDays(r.days), r);
      }
    });

    test('the same choices are allowed by the Firestore rules', () {
      final rules = File('firestore.rules').readAsStringSync();
      final days = [for (final r in Repeat.values) r.days].join(', ');
      expect(rules, contains('schedule.everyDays in [$days]'));
    });

    test('rejects a repeat or time the app does not offer', () {
      expect(
        () => CareSchedule.fromMap({
          'everyDays': 8,
          'time': '07:00',
          'since': '2026-11-26',
        }),
        throwsFormatException,
      );
      expect(
        () => CareSchedule.fromMap({
          'everyDays': 1,
          'time': '7:00',
          'since': '2026-11-26',
        }),
        throwsFormatException,
      );
      expect(
        () => CareSchedule.fromMap({
          'everyDays': 1,
          'time': '24:00',
          'since': '2026-11-26',
        }),
        throwsFormatException,
      );
    });
  });

  group('JourneyEntry', () {
    test('round-trips with a photo', () {
      final entry = samplePlants.first.journey.last;
      expect(entry.photo, isNotNull);

      final back = JourneyEntry.fromMap(entry.id!, entry.toMap());
      expect(back.id, entry.id);
      expect(back.date, entry.date);
      expect(back.notes, entry.notes);
      expect(back.photo.toMap(), entry.photo.toMap());
    });

    test('round-trips without notes and rejects a missing photo', () {
      const photo = JourneyPhoto(
        publicId: 'ethmar/plant-journey/u1/p1/e1',
        version: 1,
        format: 'webp',
        width: 1080,
        height: 1080,
        bytes: 154000,
      );
      final entry = JourneyEntry(
        id: 'e1',
        date: DateTime(2026, 10, 1, 8),
        photo: photo,
      );
      final map = entry.toMap();
      expect(map['notes'], isNull);

      final back = JourneyEntry.fromMap(
        'e1',
        map,
        expectedPhotoPublicId: photo.publicId,
      );
      expect(back.date, entry.date);
      expect(back.notes, isNull);
      expect(back.photo.toMap(), photo.toMap());

      expect(
        () => JourneyEntry.fromMap('e1', {...map, 'photo': null}),
        throwsFormatException,
      );
      expect(
        () => JourneyEntry.fromMap(
          'e1',
          map,
          expectedPhotoPublicId: 'ethmar/plant-journey/u1/p1/other',
        ),
        throwsFormatException,
      );
    });
  });

  group('FarmPlant', () {
    final unknown = cropCatalog.firstWhere((c) => c.id == unknownCropId);

    test("an unknown plant keeps the category the user chose", () {
      final plant = FarmPlant(
        id: 'u1',
        crop: unknown,
        category: CropCategory.herb,
        name: 'Moringa',
      );
      expect(plant.category, CropCategory.herb);
      final map = plant.toMap();
      expect(map['category'], 'herb');
      final back = FarmPlant.fromMap('u1', map);
      expect(back.category, CropCategory.herb);
      // Edits and moves keep it.
      expect(
        back.edited(name: 'M', irrigation: null, fertilization: null).category,
        CropCategory.herb,
      );
      expect(
        back.placed(id: 'u1', land: 1, square: 3).category,
        CropCategory.herb,
      );
    });

    test('an unknown plant without a valid saved category is "other"', () {
      final map = FarmPlant(id: 'u2', crop: unknown, name: 'X').toMap()
        ..['category'] = 'not-a-category';
      expect(FarmPlant.fromMap('u2', map).category, CropCategory.other);
    });

    test('a catalog crop always has its own category', () {
      final tomato = cropCatalog.firstWhere((c) => c.id == 'tomato');
      final plant = FarmPlant(
        crop: tomato,
        category: CropCategory.herb,
        name: 'Tomato',
      );
      expect(plant.category, CropCategory.vegetable);
      final map = plant.toMap()..['category'] = 'herb';
      expect(FarmPlant.fromMap('t1', map).category, CropCategory.vegetable);
    });

    test('every catalog crop has a unique id and a picture file', () {
      final ids = [for (final c in cropCatalog) c.id];
      expect(ids.toSet(), hasLength(ids.length));
      for (final c in cropCatalog) {
        expect(File(c.image).existsSync(), isTrue, reason: c.image);
      }
    });

    test('every sample plant round-trips (journey is saved separately)', () {
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
        expect(back.journey, isEmpty);
      }
    });

    test('every crop and the default have a picture in the assets', () {
      // The team adds the unknown plant's picture; until then it shows the
      // default one.
      for (final crop in cropCatalog.where((c) => c.id != unknownCropId)) {
        expect(File(crop.image).existsSync(), isTrue, reason: crop.id);
      }
      expect(File(defaultPlantImage).existsSync(), isTrue);
    });

    // Compares exact names: Windows ignores capitals, but Android doesn't.
    test('every picture in the crops folder is a crop in the catalog', () {
      final files = Directory('assets/ethmar_crops')
          .listSync()
          .map((file) => file.uri.pathSegments.last)
          .map(Uri.decodeComponent);
      final ids = cropCatalog.map((c) => '${c.id}.png').toSet();
      expect(ids.length, cropCatalog.length, reason: 'a crop id is repeated');
      expect(files.toSet().difference(ids), isEmpty);
      expect(ids.difference(files.toSet()), everyElement('$unknownCropId.png'));
    });

    test('crop ids and names fit what Firestore allows', () {
      for (final crop in cropCatalog) {
        expect(crop.id, matches(RegExp(r'^[a-z_]{1,40}$')));
        expect(crop.name.en.length, lessThanOrEqualTo(30), reason: crop.id);
        expect(crop.name.ar.length, lessThanOrEqualTo(30), reason: crop.id);
      }
    });

    test('rejects an unknown cropId', () {
      final map = samplePlants.first.toMap()..['cropId'] = 'not_a_crop';
      expect(() => FarmPlant.fromMap('p1', map), throwsFormatException);
    });

    test('placed() sets the id and spot and keeps the rest', () {
      final plant = samplePlants.first;
      final placed = plant.placed(id: 'new', land: 2, square: 7);
      expect(placed.id, 'new');
      expect(placed.land, 2);
      expect(placed.square, 7);
      expect(placed.name, plant.name);
      expect(placed.createdAt, plant.createdAt);
      expect(placed.updatedAt, plant.updatedAt);
      expect(placed.journey, plant.journey);
    });

    test('edited() and withJourneyEntry() keep the id, spot and dates', () {
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

      final grown = plant.withJourneyEntry(
        JourneyEntry(
          date: DateTime(2026, 10, 20),
          photo: plant.journey.first.photo,
        ),
      );
      expect(grown.id, plant.id);
      expect(grown.updatedAt, plant.updatedAt);
      expect(grown.journey, hasLength(plant.journey.length + 1));
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

  group('farm spots', () {
    FarmPlant at(int land, int square) => FarmPlant(
      crop: cropCatalog.first,
      name: 'x',
      land: land,
      square: square,
    );

    test('inFarmOrder sorts by land, then square', () {
      final sorted = inFarmOrder([at(1, 0), at(0, 3), at(0, 1)]);
      expect(
        [for (final p in sorted) (p.land, p.square)],
        [(0, 1), (0, 3), (1, 0)],
      );
    });

    test('isOnFarm rejects spots outside the grid', () {
      expect(isOnFarm(at(0, 0)), isTrue);
      expect(isOnFarm(at(8, 24)), isTrue);
      expect(isOnFarm(at(9, 0)), isFalse);
      expect(isOnFarm(at(0, 25)), isFalse);
      expect(isOnFarm(at(-1, 0)), isFalse);
    });

    test('landsToShow always leaves a land under every plant', () {
      expect(landsToShow(1, const []), 1);
      expect(landsToShow(3, [at(0, 0)]), 3);
      expect(landsToShow(1, [at(0, 0), at(2, 4)]), 3);
    });

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
