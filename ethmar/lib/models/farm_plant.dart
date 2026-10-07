import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'crop_catalog.dart';

/// How often a care reminder repeats, from most to least often.
enum Repeat {
  everyDay(1),
  every2Days(2),
  every3Days(3),
  everyWeek(7),
  every2Weeks(14),
  everyMonth(30);

  const Repeat(this.days);

  /// Days between reminders (a month counts as 30).
  final int days;

  String label(S s) => switch (this) {
    Repeat.everyDay => s.repeatEveryDay,
    Repeat.every2Days => s.repeatEvery2Days,
    Repeat.every3Days => s.repeatEvery3Days,
    Repeat.everyWeek => s.repeatEveryWeek,
    Repeat.every2Weeks => s.repeatEvery2Weeks,
    Repeat.everyMonth => s.repeatEveryMonth,
  };
}

/// A reminder to water or fertilize: how often, and at what time.
class CareSchedule {
  const CareSchedule(this.repeat, this.time);
  final Repeat repeat;
  final TimeOfDay time;

  /// The next reminder after [now], counting from [start] (the day the
  /// plant was planted).
  DateTime nextAfter(DateTime start, DateTime now) {
    var next = DateTime(
      start.year,
      start.month,
      start.day,
      time.hour,
      time.minute,
    );
    while (!next.isAfter(now)) {
      next = next.add(Duration(days: repeat.days));
    }
    return next;
  }
}

/// One step on a plant's growth timeline: a picture, optional notes, and
/// when it was added.
class GrowthEntry {
  const GrowthEntry({required this.date, this.notes});
  final DateTime date;
  final String? notes;
  // TODO(photo): Keep the picture the user took or picked (a file path, or
  //   its storage URL once uploaded).
}

/// A plant on the user's farm.
class FarmPlant {
  FarmPlant({
    required this.crop,
    required this.name,
    this.irrigation,
    this.fertilization,
    DateTime? plantedAt,
    this.growth = const [],
  }) : plantedAt = plantedAt ?? DateTime.now();

  final CatalogCrop crop;
  final String name;

  /// Null when the user hasn't set it (they can set it later).
  final CareSchedule? irrigation;
  final CareSchedule? fertilization;

  final DateTime plantedAt;

  /// Oldest first.
  final List<GrowthEntry> growth;

  /// Whole days since planting (0 on the day it was planted).
  int get daysSincePlanting {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final planted = DateTime(plantedAt.year, plantedAt.month, plantedAt.day);
    return today.difference(planted).inDays;
  }

  /// The same plant with a new name and schedules (from the edit form).
  FarmPlant edited({
    required String name,
    required CareSchedule? irrigation,
    required CareSchedule? fertilization,
  }) => FarmPlant(
    crop: crop,
    name: name,
    irrigation: irrigation,
    fertilization: fertilization,
    plantedAt: plantedAt,
    growth: growth,
  );

  FarmPlant withGrowth(GrowthEntry entry) => FarmPlant(
    crop: crop,
    name: name,
    irrigation: irrigation,
    fertilization: fertilization,
    plantedAt: plantedAt,
    growth: [...growth, entry],
  );
}
