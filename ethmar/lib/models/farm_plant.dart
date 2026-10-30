/// A plant on the user's farm, its care schedules and its growth timeline.
///
/// Plant: `users/{uid}/plants/{plantId}`
///   - cropId         String     a [cropCatalog] id, e.g. "tomato" (also
///                               picks the picture)
///   - name           String     the user's name for it (at most 30 chars)
///   - category       String     [CropCategory.name], e.g. "vegetable"
///   - land           int        which land it's on (0 = the first land)
///   - square         int        its square on that land, 0-24
///   - irrigation     map|null   {everyDays: int, time: "HH:mm"};
///                               null when switched off
///   - fertilization  map|null   same as irrigation
///   - plantedAt      Timestamp
///   - createdAt      Timestamp
///   - updatedAt      Timestamp
///
/// Growth entry: `users/{uid}/plants/{plantId}/growth/{entryId}`
///   - date   Timestamp
///   - notes  String|null
///   - photo  map|null   {publicId, version, format, width, height, bytes},
///                       the same shape as `users/{uid}/media/profile`
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'crop_catalog.dart';
import 'crop_recommendation.dart' show CropCategory;

/// How often a care reminder repeats, from most to least often.
enum Repeat {
  everyDay(1),
  every2Days(2),
  every3Days(3),
  everyWeek(7),
  every2Weeks(14),
  everyMonth(30);

  const Repeat(this.days);

  /// Days between reminders (a month counts as 30). Saved as `everyDays`.
  final int days;

  /// The choice for a saved `everyDays`. Only 1, 2, 3, 7, 14 and 30 exist.
  static Repeat fromDays(int days) => Repeat.values.firstWhere(
    (r) => r.days == days,
    orElse: () => throw FormatException('No repeat every $days days.'),
  );

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
///
/// Saved as `{everyDays: 7, time: "08:00"}` (24-hour time).
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

  Map<String, Object> toMap() => {
    'everyDays': repeat.days,
    'time': '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}',
  };

  /// Null when the schedule is switched off (saved as null).
  /// Throws a [FormatException] if the saved values aren't valid.
  static CareSchedule? fromMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    final everyDays = data['everyDays'];
    final time = data['time'];
    if (everyDays is! int || time is! String) {
      throw FormatException('Invalid care schedule: $data');
    }
    return CareSchedule(Repeat.fromDays(everyDays), _parseTime(time));
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');

  /// "HH:mm" (24-hour) to a [TimeOfDay].
  static TimeOfDay _parseTime(String text) {
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(text);
    final hour = int.tryParse(match?.group(1) ?? '');
    final minute = int.tryParse(match?.group(2) ?? '');
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      throw FormatException('Invalid time "$text", expected "HH:mm".');
    }
    return TimeOfDay(hour: hour, minute: minute);
  }
}

/// A picture on the growth timeline, uploaded to Cloudinary. Same fields
/// as the profile picture's metadata (`users/{uid}/media/profile`).
class GrowthPhoto {
  const GrowthPhoto({
    required this.publicId,
    required this.version,
    required this.format,
    required this.width,
    required this.height,
    required this.bytes,
  });

  final String publicId;
  final int version;
  final String format;
  final int width;
  final int height;
  final int bytes;

  Map<String, Object> toMap() => {
    'publicId': publicId,
    'version': version,
    'format': format,
    'width': width,
    'height': height,
    'bytes': bytes,
  };

  /// Null when the entry has no picture.
  /// Throws a [FormatException] if the saved values aren't valid.
  static GrowthPhoto? fromMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    final publicId = data['publicId'];
    final version = data['version'];
    final format = data['format'];
    final width = data['width'];
    final height = data['height'];
    final bytes = data['bytes'];
    if (publicId is! String ||
        version is! int ||
        format is! String ||
        width is! int ||
        height is! int ||
        bytes is! int) {
      throw FormatException('Invalid growth photo: $data');
    }
    return GrowthPhoto(
      publicId: publicId,
      version: version,
      format: format,
      width: width,
      height: height,
      bytes: bytes,
    );
  }
}

/// One step on a plant's growth timeline: a picture, optional notes, and
/// when it was added.
class GrowthEntry {
  const GrowthEntry({required this.date, this.id, this.notes, this.photo});

  /// The Firestore document id. Null until the entry is saved.
  final String? id;
  final DateTime date;
  final String? notes;

  /// Null until the picture is uploaded (or if there is none).
  final GrowthPhoto? photo;

  /// The document's fields. The id isn't one of them: it's the document name.
  Map<String, Object?> toMap() => {
    'date': Timestamp.fromDate(date),
    'notes': notes,
    'photo': photo?.toMap(),
  };

  /// Builds an entry from document [id] and its fields.
  /// Throws a [FormatException] if the saved values aren't valid.
  factory GrowthEntry.fromMap(String id, Map<String, dynamic> data) {
    final date = data['date'];
    final notes = data['notes'];
    if (date is! Timestamp || (notes != null && notes is! String)) {
      throw FormatException('Invalid growth entry $id: $data');
    }
    return GrowthEntry(
      id: id,
      date: date.toDate(),
      notes: notes as String?,
      photo: GrowthPhoto.fromMap(data['photo'] as Map<String, dynamic>?),
    );
  }
}

/// A plant on the user's farm.
class FarmPlant {
  FarmPlant({
    required this.crop,
    required this.name,
    this.id,
    this.land = 0,
    this.square = 0,
    this.irrigation,
    this.fertilization,
    DateTime? plantedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.growth = const [],
  }) : plantedAt = plantedAt ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// The Firestore document id. Null until the plant is saved.
  final String? id;

  /// Saved as its `cropId`; the category comes from it too.
  final CatalogCrop crop;
  final String name;

  /// Where it sits on the farm: land 0 is the first land, and square is
  /// 0-24 on that land. Use `firstFreeSpot` (farm_spot.dart) to pick them
  /// for a new plant.
  final int land;
  final int square;

  /// Null when the user hasn't set it (they can set it later).
  final CareSchedule? irrigation;
  final CareSchedule? fertilization;

  final DateTime plantedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Oldest first. Saved in the `growth` subcollection, not in the plant's
  /// document, so [fromMap] leaves it empty.
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
    id: id,
    crop: crop,
    name: name,
    land: land,
    square: square,
    irrigation: irrigation,
    fertilization: fertilization,
    plantedAt: plantedAt,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
    growth: growth,
  );

  /// The same plant with [entry] added to its timeline. The plant's own
  /// document doesn't change (entries live in `growth`), so neither does
  /// [updatedAt].
  FarmPlant withGrowth(GrowthEntry entry) => FarmPlant(
    id: id,
    crop: crop,
    name: name,
    land: land,
    square: square,
    irrigation: irrigation,
    fertilization: fertilization,
    plantedAt: plantedAt,
    createdAt: createdAt,
    updatedAt: updatedAt,
    growth: [...growth, entry],
  );

  /// The document's fields. Not included: the id (it's the document name)
  /// and [growth] (its own subcollection).
  Map<String, Object?> toMap() => {
    'cropId': crop.id,
    'name': name,
    'category': crop.category.name,
    'land': land,
    'square': square,
    'irrigation': irrigation?.toMap(),
    'fertilization': fertilization?.toMap(),
    'plantedAt': Timestamp.fromDate(plantedAt),
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  /// Builds a plant from document [id] and its fields, looking up `cropId`
  /// in [cropCatalog]. [growth] starts empty; load it separately.
  /// Throws a [FormatException] if the saved values aren't valid.
  factory FarmPlant.fromMap(String id, Map<String, dynamic> data) {
    final cropId = data['cropId'];
    final name = data['name'];
    final land = data['land'];
    final square = data['square'];
    final plantedAt = data['plantedAt'];
    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];
    if (cropId is! String ||
        name is! String ||
        land is! int ||
        square is! int ||
        plantedAt is! Timestamp ||
        createdAt is! Timestamp ||
        updatedAt is! Timestamp) {
      throw FormatException('Invalid plant $id: $data');
    }
    final crop = cropCatalog.where((c) => c.id == cropId).firstOrNull;
    if (crop == null) {
      throw FormatException('Plant $id has unknown cropId "$cropId".');
    }
    return FarmPlant(
      id: id,
      crop: crop,
      name: name,
      land: land,
      square: square,
      irrigation: CareSchedule.fromMap(
        data['irrigation'] as Map<String, dynamic>?,
      ),
      fertilization: CareSchedule.fromMap(
        data['fertilization'] as Map<String, dynamic>?,
      ),
      plantedAt: plantedAt.toDate(),
      createdAt: createdAt.toDate(),
      updatedAt: updatedAt.toDate(),
    );
  }
}
