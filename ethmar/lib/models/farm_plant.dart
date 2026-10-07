import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'crop_catalog.dart';

/// How often a care reminder repeats, from most to least often.
enum Repeat {
  everyDay,
  every2Days,
  every3Days,
  everyWeek,
  every2Weeks,
  everyMonth;

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
}

/// A plant on the user's farm.
class FarmPlant {
  const FarmPlant({
    required this.crop,
    required this.name,
    this.irrigation,
    this.fertilization,
  });
  final CatalogCrop crop;
  final String name;

  /// Null when the user hasn't set it (they can set it later).
  final CareSchedule? irrigation;
  final CareSchedule? fertilization;
}
