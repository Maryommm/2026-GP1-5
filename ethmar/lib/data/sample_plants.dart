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
///   - growth entries:      Tomato (2, one with a photo) and Mint (1)
library;

import 'package:flutter/material.dart';

import '../models/crop_catalog.dart';
import '../models/farm_plant.dart';
import '../models/farm_stats.dart';

CatalogCrop _crop(String id) => cropCatalog.firstWhere((c) => c.id == id);

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
    irrigation: const CareSchedule(Repeat.everyDay, TimeOfDay(hour: 7, minute: 0)),
    fertilization: const CareSchedule(
      Repeat.everyWeek,
      TimeOfDay(hour: 8, minute: 0),
    ),
    plantedAt: DateTime(2026, 9, 1),
    createdAt: DateTime(2026, 9, 1, 10, 15),
    updatedAt: DateTime(2026, 9, 20, 18, 30),
    growth: [
      GrowthEntry(
        id: 'sample-tomato-1',
        date: DateTime(2026, 9, 10, 9, 0),
        notes: 'First leaves!',
      ),
      GrowthEntry(
        id: 'sample-tomato-2',
        date: DateTime(2026, 10, 5, 17, 45),
        notes: 'Flowers are opening.',
        // A made-up Cloudinary picture; the real folder isn't decided yet.
        photo: const GrowthPhoto(
          publicId: 'ethmar/growth-images/sample-uid/sample-tomato-2',
          version: 1,
          format: 'webp',
          width: 1080,
          height: 1080,
          bytes: 154000,
        ),
      ),
    ],
  ),
  FarmPlant(
    id: 'sample-mint',
    crop: _crop('mint'),
    name: 'Kitchen mint',
    land: 0,
    square: 1,
    irrigation: const CareSchedule(
      Repeat.every2Days,
      TimeOfDay(hour: 18, minute: 0),
    ),
    fertilization: const CareSchedule(
      Repeat.everyMonth,
      TimeOfDay(hour: 9, minute: 30),
    ),
    plantedAt: DateTime(2026, 9, 15),
    createdAt: DateTime(2026, 9, 15, 16, 0),
    updatedAt: DateTime(2026, 9, 15, 16, 0),
    growth: [
      GrowthEntry(id: 'sample-mint-1', date: DateTime(2026, 10, 1, 8, 20)),
    ],
  ),
  FarmPlant(
    id: 'sample-basil',
    crop: _crop('basil'),
    name: 'Basil',
    land: 0,
    square: 2,
    irrigation: const CareSchedule(
      Repeat.every3Days,
      TimeOfDay(hour: 7, minute: 30),
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
    irrigation: const CareSchedule(
      Repeat.everyDay,
      TimeOfDay(hour: 6, minute: 45),
    ),
    fertilization: const CareSchedule(
      Repeat.every2Weeks,
      TimeOfDay(hour: 8, minute: 0),
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
    irrigation: const CareSchedule(
      Repeat.everyWeek,
      TimeOfDay(hour: 17, minute: 0),
    ),
    plantedAt: DateTime(2026, 7, 1),
    createdAt: DateTime(2026, 7, 1, 10, 0),
    updatedAt: DateTime(2026, 7, 1, 10, 0),
  ),
];
