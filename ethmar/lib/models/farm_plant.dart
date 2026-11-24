/// A plant on the user's farm, its care schedules and its growth timeline.
///
/// Plant: `users/{uid}/plants/{plantId}`
///   - cropId         String     a [cropCatalog] id, e.g. "tomato" (also
///                               picks the picture)
///   - name           String     the user's name for it (at most 30 chars)
///   - category       String     [CropCategory.name], e.g. "vegetable":
///                               the crop's own, or for an unknown plant
///                               the one the user picked
///   - land           int        which land it's on (0 = the first land)
///   - square         int        its square on that land, 0-24
///   - irrigation     map|null   {everyDays: int, time: "HH:mm",
///                               since: "yyyy-mm-dd",
///                               lastDone: {date, due},
///                               previousDone: {date, due}}; null when
///                               switched off. since (optional) is the
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
/// Growth entry: `users/{uid}/plants/{plantId}/growth/{entryId}`
///   - date   Timestamp  set by the server when the entry is saved
///   - notes  String|null
///   - photo  map        {publicId, version, format, width, height, bytes},
///                       the same shape as `users/{uid}/media/profile`.
///                       The picture is on Cloudinary at
///                       `ethmar/plant-growth/{uid}/{plantId}/{entryId}`.
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

  /// The choice for a saved `everyDays`. Only 1-7, 14, 21 and 30 exist
  /// (the same list as in firestore.rules).
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

/// One time a care task was done: the day it was really done ([date]) and
/// the day it was for ([due]). The same day when done on time; [date] is
/// later when a missed task was done late.
///
/// Saved as `{date: "yyyy-mm-dd", due: "yyyy-mm-dd"}`.
class CareDone {
  CareDone({required DateTime date, required DateTime due})
    : date = CareSchedule._day(date),
      due = CareSchedule._day(due);

  final DateTime date;
  final DateTime due;

  bool get late => date.isAfter(due);

  /// Later than [other]: done on a later day, or for a later day.
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

  /// Null when missing. A broken value also gives null, so one bad field
  /// can't hide the whole plant; the schedule then counts from [since].
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

  /// "yyyy-mm-dd" for the date of [day] (the same as TaskLog.dateKey).
  static String dateKey(DateTime day) =>
      '${day.year}-${CareSchedule._twoDigits(day.month)}-'
      '${CareSchedule._twoDigits(day.day)}';
}

/// A reminder to water or fertilize: how often, and at what time.
///
/// Saved as `{everyDays: 7, time: "08:00"}` (24-hour time), with [since],
/// [lastDone] and [previousDone] when known.
///
/// When tasks are due is worked out in care_task.dart (see careState):
/// the first one on [since], then every [Repeat.days] days after the day
/// the task was last done ([lastDone]).
class CareSchedule {
  const CareSchedule(
    this.repeat,
    this.time, {
    this.since,
    this.lastDone,
    this.previousDone,
  });
  final Repeat repeat;
  final TimeOfDay time;

  /// The schedule's start day (no time): no task is due before it, so a
  /// schedule added today has no missed tasks from yesterday. With nothing
  /// done since, its first task is due that day. Set when the schedule is
  /// added, when its repeat changes, and when an un-tick leaves no earlier
  /// done day (see [savedOver] and [markedUndone]). Null for schedules saved
  /// before this was kept; those count from the planting day, starting on
  /// the day the plant was last saved (see careState).
  final DateTime? since;

  /// The latest time this task was done, on time or late. The next task is
  /// due [Repeat.days] days after the day it was done. Null until it's
  /// first done (and for schedules saved before this was kept).
  final CareDone? lastDone;

  /// The time it was done before [lastDone], so un-ticking [lastDone] can
  /// put it back.
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
  ///
  /// A schedule saved before start days were kept has none: it repeats
  /// from [plantedAt], starting on [lastSaved], the plant's last save
  /// before this one. When its repeat stays, its first task from that day
  /// is written down now as its start day, so this save (e.g. only a new
  /// name or time) doesn't move it.
  CareSchedule savedOver(
    CareSchedule? previous,
    DateTime today, {
    required DateTime lastSaved,
    required DateTime plantedAt,
  }) {
    final day = _day(today);
    if (previous == null) return CareSchedule(repeat, time, since: day);
    if (repeat == previous.repeat) {
      return CareSchedule(
        repeat,
        time,
        since:
            previous.since ?? firstDayFrom(plantedAt, repeat.days, lastSaved),
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

  /// The first of [start], [start] + [every] days, [start] + 2 × [every]...
  /// that is on or after the date of [from]. Calendar days, so a
  /// daylight-saving change can't shift it.
  static DateTime firstDayFrom(DateTime start, int every, DateTime from) {
    final s = _day(start), f = _day(from);
    final gap = DateTime.utc(f.year, f.month, f.day)
        .difference(DateTime.utc(s.year, s.month, s.day))
        .inDays;
    if (gap <= 0) return s;
    final steps = (gap + every - 1) ~/ every;
    return DateTime(s.year, s.month, s.day + steps * every);
  }

  /// The same schedule with other done days.
  CareSchedule withDone({CareDone? last, CareDone? previous}) => CareSchedule(
    repeat,
    time,
    since: since,
    lastDone: last,
    previousDone: previous,
  );

  /// After the task due on [done]'s due day is ticked: it becomes
  /// [lastDone], so the next task counts from the day it was done, and the
  /// old [lastDone] is kept as [previousDone] for un-ticking. Ticking the
  /// same task again changes nothing. A tick older than [lastDone] (e.g.
  /// from another phone) doesn't move the schedule back.
  CareSchedule markedDone(CareDone done) {
    final last = lastDone;
    if (last != null && (last.due == done.due || last.isAfter(done))) {
      return this;
    }
    return withDone(last: done, previous: last);
  }

  /// After the task due on [due] is un-ticked: if it was [lastDone], the
  /// time before ([previousDone]) counts again, as if it had never been
  /// ticked; if it was [previousDone], that is forgotten.
  ///
  /// Only two done days are kept, so when there is no [previousDone] to go
  /// back to (never done before, or already used by an earlier un-tick),
  /// the un-ticked task's day becomes the start day ([since]): that task
  /// is the one to do again (due, or missed if its day has passed), and
  /// the schedule carries on from it. Nothing is made up as done.
  CareSchedule markedUndone(DateTime due) {
    final day = _day(due);
    if (lastDone?.due == day) {
      final back = previousDone;
      if (back != null) return withDone(last: back);
      final start = since;
      return CareSchedule(
        repeat,
        time,
        since: start != null && start.isAfter(day) ? start : day,
      );
    }
    if (previousDone?.due == day) return withDone(last: lastDone);
    return this;
  }

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  Map<String, Object> toMap() => {
    'everyDays': repeat.days,
    'time': '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}',
    if (since case final day?) 'since': CareDone.dateKey(day),
    if (lastDone case final done?) 'lastDone': done.toMap(),
    if (previousDone case final done?) 'previousDone': done.toMap(),
  };

  /// Null when the schedule is switched off (saved as null).
  /// Throws a [FormatException] if the saved values aren't valid.
  static CareSchedule? fromMap(Object? data) {
    if (data == null) return null;
    if (data is! Map) throw FormatException('Invalid care schedule: $data');
    final everyDays = data['everyDays'];
    final time = data['time'];
    final since = data['since'];
    if (everyDays is! int || time is! String || (since != null && since is! String)) {
      throw FormatException('Invalid care schedule: $data');
    }
    return CareSchedule(
      Repeat.fromDays(everyDays),
      _parseTime(time),
      since: since == null ? null : _parseDate(since as String),
      lastDone: CareDone.fromMap(data['lastDone']),
      previousDone: CareDone.fromMap(data['previousDone']),
    );
  }

  /// "yyyy-mm-dd" to a local date.
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

  /// Ethmar's Cloudinary account (the same as the profile pictures').
  static const cloudName = 'k7otdsln';

  /// Where it's saved on Cloudinary, for [uid]'s entry [entryId] of plant
  /// [plantId]. Firestore's rules allow no other.
  static String publicIdFor(String uid, String plantId, String entryId) =>
      'ethmar/plant-growth/$uid/$plantId/$entryId';

  /// The address to show it from. The version makes a replaced picture a
  /// new address, so an old copy is never shown from a cache.
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

  /// Null when the entry has no picture.
  /// Throws a [FormatException] if the saved values aren't valid.
  static GrowthPhoto? fromMap(Object? data) {
    if (data == null) return null;
    if (data is! Map) throw FormatException('Invalid growth photo: $data');
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

  /// Every saved entry has one; null only in sample data and old entries.
  final GrowthPhoto? photo;

  /// Which day of the plant's life it was taken: 0 on the planting day.
  int dayOf(DateTime plantedAt) {
    // UTC calendar days, so a daylight-saving change can't lose a day.
    final planted = DateTime.utc(
      plantedAt.year,
      plantedAt.month,
      plantedAt.day,
    );
    final day = DateTime.utc(date.year, date.month, date.day);
    return day.difference(planted).inDays;
  }

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
      photo: GrowthPhoto.fromMap(data['photo']),
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
    CropCategory? category,
  }) : category = crop.id == unknownCropId
           ? category ?? crop.category
           : crop.category,
       plantedAt = plantedAt ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// The Firestore document id. Null until the plant is saved.
  final String? id;

  /// Saved as its `cropId`, which also picks the picture.
  final CatalogCrop crop;
  final String name;

  /// What kind of plant it is, for the filters and labels. A catalog crop
  /// always has its own category; an unknown plant has the one the user
  /// chose when adding it.
  final CropCategory category;

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

  /// The schedule of [type]: [irrigation] for watering, [fertilization]
  /// for fertilizing.
  CareSchedule? scheduleOf(TaskType type) => switch (type) {
    TaskType.watering => irrigation,
    TaskType.fertilizing => fertilization,
  };

  /// The same plant with a new name and schedules (from the edit form).
  /// Each schedule keeps or moves its tasks as [CareSchedule.savedOver]
  /// says: a new time keeps the days, a new repeat counts from the last
  /// time the task was done.
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
    irrigation: irrigation?.savedOver(
      this.irrigation,
      today ?? DateTime.now(),
      lastSaved: updatedAt,
      plantedAt: plantedAt,
    ),
    fertilization: fertilization?.savedOver(
      this.fertilization,
      today ?? DateTime.now(),
      lastSaved: updatedAt,
      plantedAt: plantedAt,
    ),
    plantedAt: plantedAt,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
    growth: growth,
  );

  /// The same plant once it has a document [id] and a spot on the farm.
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
    growth: growth,
  );

  /// The same plant with [entry] added to its timeline. The plant's own
  /// document doesn't change (entries live in `growth`), so neither does
  /// [updatedAt].
  FarmPlant withGrowth(GrowthEntry entry) => FarmPlant(
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
    growth: [...growth, entry],
  );

  /// The document's fields. Not included: the id (it's the document name)
  /// and [growth] (its own subcollection).
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
    // Only an unknown plant's saved category is used (see [category]); an
    // old or unreadable one counts as "other".
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
