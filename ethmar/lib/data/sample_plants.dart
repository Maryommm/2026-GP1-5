/// SAMPLE DATA for the team: made-up plants for trying screens, seeding a
/// test account and writing tests. The app doesn't use it on its own; real
/// plants come from `users/{uid}/plants`.
///
/// What's covered:
///   - both schedules on:   Tomato, Mint, Strawberry
///   - one schedule off:    Basil (no fertilization), Date palm (no fertilization)
///   - both schedules off:  Lemon tree
///   - two lands:           land 0 (squares 0-3) and land 1 (squares 0-1),
///                          so [sampleStats] has 2 lands
///   - journey entries:      Tomato (2) and Mint (1), all with photos
library;

import 'package:flutter/material.dart';

import '../models/crop_catalog.dart';
import '../models/farm_plant.dart';
import '../models/farm_stats.dart';

CatalogCrop _crop(String id) => cropCatalog.firstWhere((c) => c.id == id);

JourneyPhoto _journeyPhoto(String plantId, String entryId) => JourneyPhoto(
  publicId: JourneyPhoto.publicIdFor('sample-uid', plantId, entryId),
  version: 1,
  format: 'webp',
  width: 1080,
  height: 1080,
  bytes: 154000,
);

/// Stats that match [samplePlants]: 2 lands and a short streak.
const sampleStats = FarmStats(
  currentStreak: 3,
  lastCompletedDate: '2026-10-29',
  lands: 2,
);

/// Six sample plants. The ids are made up and only need to be unique.
final samplePlants = <FarmPlant>[
  FarmPlant(
    id: 'sample-tomato',
    crop: _crop('tomato'),
    name: 'My tomato',
    land: 0,
    square: 0,
    irrigation: CareSchedule(
      Repeat.everyDay,
      const TimeOfDay(hour: 7, minute: 0),
      since: DateTime(2026, 9, 1),
    ),
    fertilization: CareSchedule(
      Repeat.everyWeek,
      const TimeOfDay(hour: 8, minute: 0),
      since: DateTime(2026, 9, 1),
    ),
    plantedAt: DateTime(2026, 9, 1),
    createdAt: DateTime(2026, 9, 1, 10, 15),
    updatedAt: DateTime(2026, 9, 20, 18, 30),
    journey: [
      JourneyEntry(
        id: 'sample-tomato-1',
        date: DateTime(2026, 9, 10, 9, 0),
        notes: 'First leaves!',
        photo: _journeyPhoto('sample-tomato', 'sample-tomato-1'),
      ),
      JourneyEntry(
        id: 'sample-tomato-2',
        date: DateTime(2026, 10, 5, 17, 45),
        notes: 'Flowers are opening.',
        photo: _journeyPhoto('sample-tomato', 'sample-tomato-2'),
      ),
    ],
  ),
  FarmPlant(
    id: 'sample-mint',
    crop: _crop('mint'),
    name: 'Kitchen mint',
    land: 0,
    square: 1,
    irrigation: CareSchedule(
      Repeat.every2Days,
      const TimeOfDay(hour: 18, minute: 0),
      since: DateTime(2026, 9, 15),
    ),
    fertilization: CareSchedule(
      Repeat.everyMonth,
      const TimeOfDay(hour: 9, minute: 30),
      since: DateTime(2026, 9, 15),
    ),
    plantedAt: DateTime(2026, 9, 15),
    createdAt: DateTime(2026, 9, 15, 16, 0),
    updatedAt: DateTime(2026, 9, 15, 16, 0),
    journey: [
      JourneyEntry(
        id: 'sample-mint-1',
        date: DateTime(2026, 10, 1, 8, 20),
        photo: _journeyPhoto('sample-mint', 'sample-mint-1'),
      ),
    ],
  ),
  FarmPlant(
    id: 'sample-basil',
    crop: _crop('basil'),
    name: 'Basil',
    land: 0,
    square: 2,
    irrigation: CareSchedule(
      Repeat.every3Days,
      const TimeOfDay(hour: 7, minute: 30),
      since: DateTime(2026, 10, 1),
    ),
    plantedAt: DateTime(2026, 10, 1),
    createdAt: DateTime(2026, 10, 1, 11, 0),
    updatedAt: DateTime(2026, 10, 1, 11, 0),
  ),
  FarmPlant(
    id: 'sample-lemon',
    crop: _crop('lemon_tree'),
    name: 'Lemon tree',
    land: 0,
    square: 3,
    plantedAt: DateTime(2026, 8, 20),
    createdAt: DateTime(2026, 8, 20, 12, 0),
    updatedAt: DateTime(2026, 8, 20, 12, 0),
  ),
  FarmPlant(
    id: 'sample-strawberry',
    crop: _crop('strawberry'),
    name: 'Strawberries',
    land: 1,
    square: 0,
    irrigation: CareSchedule(
      Repeat.everyDay,
      const TimeOfDay(hour: 6, minute: 45),
      since: DateTime(2026, 10, 10),
    ),
    fertilization: CareSchedule(
      Repeat.every2Weeks,
      const TimeOfDay(hour: 8, minute: 0),
      since: DateTime(2026, 10, 10),
    ),
    plantedAt: DateTime(2026, 10, 10),
    createdAt: DateTime(2026, 10, 10, 15, 10),
    updatedAt: DateTime(2026, 10, 12, 9, 0),
  ),
  FarmPlant(
    id: 'sample-date-palm',
    crop: _crop('date_palm'),
    name: 'Date palm',
    land: 1,
    square: 1,
    irrigation: CareSchedule(
      Repeat.everyWeek,
      const TimeOfDay(hour: 17, minute: 0),
      since: DateTime(2026, 7, 1),
    ),
    plantedAt: DateTime(2026, 7, 1),
    createdAt: DateTime(2026, 7, 1, 10, 0),
    updatedAt: DateTime(2026, 7, 1, 10, 0),
  ),
];
