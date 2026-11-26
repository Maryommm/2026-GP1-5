/// A plant on the user's farm, its care schedules and its journey timeline.
///
/// Plant: `users/{uid}/plants/{plantId}`
///   - cropId         String     a [cropCatalog] id, e.g. "tomato" (also
///                               picks the picture)
///   - name           String     the user's name for it (max 30 characters)
///   - category       String     [CropCategory.name], e.g. "vegetable".
///                               The crop's own category, or the one the
///                               user picked for an unknown plant
///   - land           int        which land it's on (0 = the first land)
///   - square         int        its square on that land, 0-24
///   - irrigation     map|null   {everyDays: int, time: "HH:mm",
///                               since: "yyyy-mm-dd",
///                               lastDone: {date, due},
///                               previousDone: {date, due}}; null when
///                               switched off. since is the required
///                               start day: no task is due before it, and
///                               with nothing done since, the first one is
///                               due that day (see savedOver and
///                               markedUndone). lastDone
///                               (optional) is the latest time the task
///                               was done: date is the day it was really
///                               done, due the day it was for. The next
///                               task is due everyDays after that date.
///                               previousDone is the one before, so
///                               un-ticking lastDone can bring it back
///   - fertilization  map|null   same as irrigation
///   - plantedAt      Timestamp
///   - createdAt      Timestamp
///   - updatedAt      Timestamp
///
/// Journey entry: `users/{uid}/plants/{plantId}/journey/{entryId}`
///   - date   Timestamp  set by the server when the entry is saved
///   - notes  String|null
///   - photo  map        {publicId, version, format, width, height, bytes},
///                       the same shape as `users/{uid}/media/profile`.
///                       The picture is saved on Cloudinary at
///                       `ethmar/plant-journey/{uid}/{plantId}/{entryId}`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'crop_catalog.dart';
import 'crop_recommendation.dart' show CropCategory;
import 'daily_task.dart' show TaskType;

/// How often a care reminder repeats, from most to least often.
enum Repeat {
  everyDay(1),
  every2Days(2),
  every3Days(3),
  every4Days(4),
  every5Days(5),
  every6Days(6),
  everyWeek(7),
  every2Weeks(14),
  every3Weeks(21),
  everyMonth(30);

  const Repeat(this.days);

  /// Days between reminders (a month counts as 30). Saved as `everyDays`.
  final int days;

  /// Finds the option for a saved `everyDays`. Only 1-7, 14, 21 and 30 are
  /// allowed (the same list as in firestore.rules).
  static Repeat fromDays(int days) => Repeat.values.firstWhere(
    (r) => r.days == days,
    orElse: () => throw FormatException('No repeat every $days days.'),
  );

  String label(S s) => switch (this) {
    Repeat.everyDay => s.repeatEveryDay,
    Repeat.every2Days => s.repeatEvery2Days,
    Repeat.every3Days => s.repeatEvery3Days,
    Repeat.every4Days => s.repeatEvery4Days,
    Repeat.every5Days => s.repeatEvery5Days,
    Repeat.every6Days => s.repeatEvery6Days,
    Repeat.everyWeek => s.repeatEveryWeek,
    Repeat.every2Weeks => s.repeatEvery2Weeks,
    Repeat.every3Weeks => s.repeatEvery3Weeks,
    Repeat.everyMonth => s.repeatEveryMonth,
  };
}

/// One time a care task was done: the day it was actually done ([date])
/// and the day it was for ([due]). They are the same day when done on
/// time; [date] is later when a missed task was done late.
///
/// Saved as `{date: "yyyy-mm-dd", due: "yyyy-mm-dd"}`.
class CareDone {
  CareDone({required DateTime date, required DateTime due})
    : date = CareSchedule._day(date),
      due = CareSchedule._day(due);

  final DateTime date;
  final DateTime due;

  bool get late => date.isAfter(due);

  /// True if this is newer than [other] (done on a later day, or for a
  /// later day).
  bool isAfter(CareDone? other) =>
      other == null ||
      date.isAfter(other.date) ||
      (date == other.date && due.isAfter(other.due));

  @override
  bool operator ==(Object other) =>
      other is CareDone && other.date == date && other.due == due;

  @override
  int get hashCode => Object.hash(date, due);

  @override
  String toString() => 'CareDone(${dateKey(date)} for ${dateKey(due)})';

  Map<String, String> toMap() => {'date': dateKey(date), 'due': dateKey(due)};

  /// Returns null when missing or broken, so one bad field can't hide the
  /// whole plant. The schedule then counts from [since].
  static CareDone? fromMap(Object? data) {
    if (data is! Map) return null;
    final date = data['date'], due = data['due'];
    if (date is! String || due is! String) return null;
    try {
      return CareDone(
        date: CareSchedule._parseDate(date),
        due: CareSchedule._parseDate(due),
      );
    } on FormatException {
      return null;
    }
  }

  /// "yyyy-mm-dd" for the date of [day] (same format as TaskLog.dateKey).
  static String dateKey(DateTime day) =>
      '${day.year}-${CareSchedule._twoDigits(day.month)}-'
      '${CareSchedule._twoDigits(day.day)}';
}

/// A reminder to water or fertilize: how often, and at what time.
///
/// Saved as `{everyDays: 7, time: "08:00", since: "yyyy-mm-dd"}`
/// (24-hour time), with [lastDone] and [previousDone] when known.
///
/// The due dates are calculated in care_task.dart (see careState): the
/// first task is on [since], then every [Repeat.days] days after the last
/// time it was done ([lastDone]).
class CareSchedule {
  CareSchedule(
    this.repeat,
    this.time, {
    DateTime? since,
    this.lastDone,
    this.previousDone,
  }) : since = _day(since ?? DateTime.now());
  final Repeat repeat;
  final TimeOfDay time;

  /// The schedule's start day (no time): no task is due before it, so a
  /// schedule added today has no missed tasks from yesterday. With nothing
  /// done since, its first task is due that day. Set when the schedule is
  /// added, when its repeat changes, and when an un-tick leaves no earlier
  /// done day (see [savedOver] and [markedUndone]).
  final DateTime since;

  /// The last time this task was done, on time or late. The next task is due
  /// [Repeat.days] days after it. Null until it is done for the first time.
  final CareDone? lastDone;

  /// The time it was done before [lastDone], so un-ticking [lastDone] can
  /// bring it back.
  final CareDone? previousDone;

  /// Same repeat and time; [since] and the done days aren't compared.
  bool sameAs(CareSchedule? other) =>
      other != null && other.repeat == repeat && other.time == time;

  /// This schedule as the user saves it in place of [previous] on [today]:
  /// - New (switched on): its first task is due [today], as for a plant
  ///   added today.
  /// - Same repeat (only the time changed, or nothing): kept as it was,
  ///   with its start day and done days, so its tasks stay on the same days
  ///   (a missed task stays missed) and only move to the new time.
  /// - New repeat, done before: the next task is due [Repeat.days] (the new
  ///   repeat) days after the day it was last done ([lastDone] is kept), or
  ///   [today] if that day has already passed. Nothing is due before
  ///   [today] ([since]), so an older missed task is replaced by it.
  /// - New repeat, never done: it starts again on [today], as a new one.
  CareSchedule savedOver(CareSchedule? previous, DateTime today) {
    final day = _day(today);
    if (previous == null) return CareSchedule(repeat, time, since: day);
    if (repeat == previous.repeat) {
      return CareSchedule(
        repeat,
        time,
        since: previous.since,
        lastDone: previous.lastDone,
        previousDone: previous.previousDone,
      );
    }
    return CareSchedule(
      repeat,
      time,
      since: day,
      lastDone: previous.lastDone,
      previousDone: previous.lastDone == null ? null : previous.previousDone,
    );
  }

  /// The same schedule with other done days.
  CareSchedule withDone({CareDone? last, CareDone? previous}) => CareSchedule(
    repeat,
    time,
    since: since,
    lastDone: last,
    previousDone: previous,
  );

  /// Called after the task due on [done]'s day is ticked. It becomes
  /// [lastDone], so the next task counts from that day, and the old
  /// [lastDone] moves to [previousDone] (used for un-ticking). Ticking the
  /// same task again does nothing. A tick older than [lastDone] (for example
  /// from another phone) doesn't move the schedule back.
  CareSchedule markedDone(CareDone done) {
    final last = lastDone;
    if (last != null && (last.due == done.due || last.isAfter(done))) {
      return this;
    }
    return withDone(last: done, previous: last);
  }

  /// Called after the task due on [due] is un-ticked. If it was [lastDone],
  /// [previousDone] counts again, as if it was never ticked. If it was
  /// [previousDone], that one is removed.
  ///
  /// Only two done days are saved. When there is no [previousDone] to go
  /// back to, the un-ticked task's day becomes the start day ([since]), so
  /// that task has to be done again and the schedule continues from there.
  CareSchedule markedUndone(DateTime due) {
    final day = _day(due);
    if (lastDone?.due == day) {
      final back = previousDone;
      if (back != null) return withDone(last: back);
      return CareSchedule(
        repeat,
        time,
        since: since.isAfter(day) ? since : day,
      );
    }
    if (previousDone?.due == day) return withDone(last: lastDone);
    return this;
  }

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  Map<String, Object> toMap() => {
    'everyDays': repeat.days,
    'time': '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}',
    'since': CareDone.dateKey(since),
    if (lastDone case final done?) 'lastDone': done.toMap(),
    if (previousDone case final done?) 'previousDone': done.toMap(),
  };

  /// Returns null when the schedule is turned off (saved as null).
  /// Throws a [FormatException] if the saved values are not valid.
  static CareSchedule? fromMap(Object? data) {
    if (data == null) return null;
    if (data is! Map) throw FormatException('Invalid care schedule: $data');
    final everyDays = data['everyDays'];
    final time = data['time'];
    final since = data['since'];
    if (everyDays is! int || time is! String || since is! String) {
      throw FormatException('Invalid care schedule: $data');
    }
    return CareSchedule(
      Repeat.fromDays(everyDays),
      _parseTime(time),
      since: _parseDate(since),
      lastDone: CareDone.fromMap(data['lastDone']),
      previousDone: CareDone.fromMap(data['previousDone']),
    );
  }

  /// Converts "yyyy-mm-dd" to a local date.
  static DateTime _parseDate(String text) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
    if (match == null) {
      throw FormatException('Invalid date "$text", expected "yyyy-mm-dd".');
    }
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');

  /// Converts "HH:mm" (24-hour) to a [TimeOfDay].
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

/// A photo on the journey timeline, uploaded to Cloudinary. It has the
/// same fields as the profile picture (`users/{uid}/media/profile`).
class JourneyPhoto {
  const JourneyPhoto({
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

  /// Ethmar's Cloudinary account (the same one used for profile pictures).
  static const cloudName = 'k7otdsln';

  /// Where the photo is saved on Cloudinary for user [uid], plant [plantId]
  /// and entry [entryId]. Firestore's rules only allow this path.
  static String publicIdFor(String uid, String plantId, String entryId) =>
      'ethmar/plant-journey/$uid/$plantId/$entryId';

  /// The photo's web address. The version is part of the address, so a
  /// replaced photo never shows an old cached copy.
  String get url =>
      'https://res.cloudinary.com/$cloudName/image/upload/v$version/$publicId.$format';

  Map<String, Object> toMap() => {
    'publicId': publicId,
    'version': version,
    'format': format,
    'width': width,
    'height': height,
    'bytes': bytes,
  };

  /// Throws a [FormatException] if the saved values aren't valid.
  static JourneyPhoto fromMap(Object? data, {String? expectedPublicId}) {
    if (data is! Map) throw FormatException('Invalid journey photo: $data');
    final publicId = data['publicId'];
    final version = data['version'];
    final format = data['format'];
    final width = data['width'];
    final height = data['height'];
    final bytes = data['bytes'];
    const fields = {'publicId', 'version', 'format', 'width', 'height', 'bytes'};
    if (data.length != fields.length ||
        !data.keys.every(fields.contains) ||
        publicId is! String ||
        !publicId.startsWith('ethmar/plant-journey/') ||
        (expectedPublicId != null && publicId != expectedPublicId) ||
        version is! int ||
        version <= 0 ||
        format != 'webp' ||
        width is! int ||
        width <= 0 ||
        width > 4096 ||
        height is! int ||
        height <= 0 ||
        height > 4096 ||
        bytes is! int ||
        bytes <= 0 ||
        bytes > 5 * 1024 * 1024) {
      throw FormatException('Invalid journey photo: $data');
    }
    return JourneyPhoto(
      publicId: publicId,
      version: version,
      format: format,
      width: width,
      height: height,
      bytes: bytes,
    );
  }
}

/// One step on a plant's journey timeline: a photo, optional notes, and
/// the date it was added.
class JourneyEntry {
  const JourneyEntry({
    required this.date,
    required this.photo,
    this.id,
    this.notes,
  });

  /// The Firestore document id. Null until the entry is saved.
  final String? id;
  final DateTime date;
  final String? notes;

  /// The required Cloudinary metadata for this persisted entry.
  final JourneyPhoto photo;

  /// Which day of the plant's life the photo was taken (0 = planting day).
  int dayOf(DateTime plantedAt) {
    // Use UTC calendar days so daylight saving can't lose a day.
    final planted = DateTime.utc(
      plantedAt.year,
      plantedAt.month,
      plantedAt.day,
    );
    final day = DateTime.utc(date.year, date.month, date.day);
    return day.difference(planted).inDays;
  }

  /// The document's fields. The id is not included because it is the
  /// document name.
  Map<String, Object?> toMap() => {
    'date': Timestamp.fromDate(date),
    'notes': notes,
    'photo': photo.toMap(),
  };

  /// Builds an entry from document [id] and its fields.
  /// Throws a [FormatException] if the saved values aren't valid.
  factory JourneyEntry.fromMap(
    String id,
    Map<String, dynamic> data, {
    String? expectedPhotoPublicId,
  }) {
    final date = data['date'];
    final notes = data['notes'];
    if (date is! Timestamp || (notes != null && notes is! String)) {
      throw FormatException('Invalid journey entry $id: $data');
    }
    return JourneyEntry(
      id: id,
      date: date.toDate(),
      notes: notes as String?,
      photo: JourneyPhoto.fromMap(
        data['photo'],
        expectedPublicId: expectedPhotoPublicId,
      ),
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
    this.journey = const [],
    CropCategory? category,
  }) : category = crop.id == unknownCropId
           ? category ?? crop.category
           : crop.category,
       plantedAt = plantedAt ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// The Firestore document id. Null until the plant is saved.
  final String? id;

  /// Saved as `cropId`, which also decides the picture.
  final CatalogCrop crop;
  final String name;

  /// The plant's category, used for filters and labels. A catalog crop has
  /// its own category; an unknown plant uses the one the user chose.
  final CropCategory category;

  /// Where the plant is on the farm: land 0 is the first land, and square is
  /// 0-24 on that land. Use `firstFreeSpot` (farm_spot.dart) for a new plant.
  final int land;
  final int square;

  /// Null when the user hasn't set it yet (they can set it later).
  final CareSchedule? irrigation;
  final CareSchedule? fertilization;

  final DateTime plantedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Oldest first. Saved in the `journey` subcollection, not in the plant's
  /// document, so [fromMap] leaves it empty.
  final List<JourneyEntry> journey;

  /// Whole days since planting (0 on the planting day).
  int get daysSincePlanting {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final planted = DateTime(plantedAt.year, plantedAt.month, plantedAt.day);
    return today.difference(planted).inDays;
  }

  /// The schedule for [type]: [irrigation] for watering, [fertilization] for
  /// fertilizing.
  CareSchedule? scheduleOf(TaskType type) => switch (type) {
    TaskType.watering => irrigation,
    TaskType.fertilizing => fertilization,
  };

  /// The same plant with a new name and schedules (from the edit form).
  /// Each schedule is updated with [CareSchedule.savedOver]: a new time
  /// keeps the same days, a new repeat counts from the last done time.
  FarmPlant edited({
    required String name,
    required CareSchedule? irrigation,
    required CareSchedule? fertilization,
    DateTime? today,
  }) => FarmPlant(
    id: id,
    crop: crop,
    category: category,
    name: name,
    land: land,
    square: square,
    irrigation: irrigation?.savedOver(this.irrigation, today ?? DateTime.now()),
    fertilization: fertilization?.savedOver(
      this.fertilization,
      today ?? DateTime.now(),
    ),
    plantedAt: plantedAt,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
    journey: journey,
  );

  /// The same plant after it gets a document [id] and a spot on the farm.
  FarmPlant placed({
    required String id,
    required int land,
    required int square,
  }) => FarmPlant(
    id: id,
    crop: crop,
    category: category,
    name: name,
    land: land,
    square: square,
    irrigation: irrigation,
    fertilization: fertilization,
    plantedAt: plantedAt,
    createdAt: createdAt,
    updatedAt: updatedAt,
    journey: journey,
  );

  /// The same plant with [entry] added to its timeline. The plant's own
  /// document doesn't change (entries are saved in `journey`), so
  /// [updatedAt] stays the same.
  FarmPlant withJourneyEntry(JourneyEntry entry) => FarmPlant(
    id: id,
    crop: crop,
    category: category,
    name: name,
    land: land,
    square: square,
    irrigation: irrigation,
    fertilization: fertilization,
    plantedAt: plantedAt,
    createdAt: createdAt,
    updatedAt: updatedAt,
    journey: [...journey, entry],
  );

  /// The document's fields. Not included: the id (it is the document name)
  /// and [journey] (it is a separate subcollection).
  Map<String, Object?> toMap() => {
    'cropId': crop.id,
    'name': name,
    'category': category.name,
    'land': land,
    'square': square,
    'irrigation': irrigation?.toMap(),
    'fertilization': fertilization?.toMap(),
    'plantedAt': Timestamp.fromDate(plantedAt),
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  /// Creates a plant from document [id] and its fields, looking up `cropId`
  /// in [cropCatalog]. [journey] starts empty and is loaded separately.
  /// Throws a [FormatException] if the saved values are not valid.
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
    // The saved category is only used for unknown plants (see [category]). An
    // old or unreadable value counts as "other".
    final saved = data['category'];
    return FarmPlant(
      id: id,
      crop: crop,
      category: CropCategory.values.where((c) => c.name == saved).firstOrNull,
      name: name,
      land: land,
      square: square,
      irrigation: CareSchedule.fromMap(data['irrigation']),
      fertilization: CareSchedule.fromMap(data['fertilization']),
      plantedAt: plantedAt.toDate(),
      createdAt: createdAt.toDate(),
      updatedAt: updatedAt.toDate(),
    );
  }
}
