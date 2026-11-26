import 'dart:math' as math;

/// A place on Earth, in degrees (north and east are positive).
typedef SkyPlace = ({double latitude, double longitude});

/// Whether it is day or night.
enum SkyPhase { day, night }

/// The sky at a moment: its [phase], and when that phase ends.
class SkyState {
  const SkyState(this.phase, this.nextChange);
  final SkyPhase phase;

  /// When the phase changes next (local time): the next sunrise or sunset,
  /// or midnight if the sun doesn't rise or set that day.
  final DateTime nextChange;

  @override
  String toString() => 'SkyState($phase until $nextChange)';
}

/// The clock time on the phone: the phone's own time zone, or a fixed
/// offset from UTC (for tests, so they don't depend on the computer).
class _Wall {
  const _Wall(this.offset);

  /// Null means the phone's time zone (with daylight saving).
  final Duration? offset;

  /// The calendar day of [t] on this clock.
  ({int year, int month, int day}) dayOf(DateTime t) {
    final offset = this.offset;
    final wall = offset == null ? t.toLocal() : t.toUtc().add(offset);
    return (year: wall.year, month: wall.month, day: wall.day);
  }

  /// The moment this clock shows [hour]:00 on that day, as a local DateTime.
  /// The day can overflow (for example 32 January is 1 February).
  DateTime at(int year, int month, int day, [int hour = 0]) {
    final offset = this.offset;
    if (offset == null) return DateTime(year, month, day, hour);
    return DateTime.utc(year, month, day, hour).subtract(offset).toLocal();
  }
}

/// Sunrise and sunset on one day at one place, in local time.
/// Near the poles the sun can stay up ([alwaysUp]) or down ([alwaysDown])
/// all day. Then [sunrise] and [sunset] are null.
class SunTimes {
  const SunTimes._(this.sunrise, this.sunset, {required this.alwaysUp})
    : alwaysDown = !alwaysUp && sunrise == null;

  final DateTime? sunrise;
  final DateTime? sunset;
  final bool alwaysUp;
  final bool alwaysDown;

  /// Sunrise and sunset on [date] at [place], calculated on the phone with
  /// the NOAA "sunrise equation" (within a minute or two of official times).
  /// [utcOffset] sets the time zone for tests; by default it's the phone's.
  ///
  /// If the phone's time zone is far from [place] (for example a traveller
  /// or an emulator), the sun's day may start or end on another calendar day.
  static SunTimes on(DateTime date, SkyPlace place, {Duration? utcOffset}) =>
      _on(date.year, date.month, date.day, place, _Wall(utcOffset));

  static SunTimes _on(int year, int month, int day, SkyPlace place, _Wall w) {
    final lat = place.latitude;
    final lng = place.longitude;
    // Noon of that day on the phone's clock, as a Julian date.
    final noon = w.at(year, month, day, 12).toUtc();
    final jd = noon.millisecondsSinceEpoch / _msPerDay + _unixEpochJd;
    // The solar noon closest to that noon.
    final n = (jd - _j2000 + lng / 360).round();
    final meanNoon = n - lng / 360;

    final m = _mod360(357.5291 + 0.98560028 * meanNoon);
    final mr = _rad(m);
    final centre =
        1.9148 * math.sin(mr) +
        0.02 * math.sin(2 * mr) +
        0.0003 * math.sin(3 * mr);
    final lambda = _rad(_mod360(m + centre + 180 + 102.9372));
    final transit =
        _j2000 + meanNoon + 0.0053 * math.sin(mr) - 0.0069 * math.sin(2 * lambda);
    final sinDecl = math.sin(lambda) * math.sin(_rad(23.4397));
    final cosDecl = math.cos(math.asin(sinDecl));
    // −0.833° is the sun's top edge, including the bending of light by the air.
    final cosHour =
        (math.sin(_rad(-0.833)) - math.sin(_rad(lat)) * sinDecl) /
        (math.cos(_rad(lat)) * cosDecl);

    if (cosHour.isNaN) return const SunTimes._(null, null, alwaysUp: false);
    if (cosHour < -1) return const SunTimes._(null, null, alwaysUp: true);
    if (cosHour > 1) return const SunTimes._(null, null, alwaysUp: false);
    final half = math.acos(cosHour) * 180 / math.pi / 360;
    return SunTimes._(
      _fromJd(transit - half),
      _fromJd(transit + half),
      alwaysUp: false,
    );
  }

  static const _msPerDay = 86400000.0;
  static const _unixEpochJd = 2440587.5;
  static const _j2000 = 2451545.0;
  static double _rad(double deg) => deg * math.pi / 180;
  static double _mod360(double deg) => deg % 360;
  static DateTime _fromJd(double jd) => DateTime.fromMillisecondsSinceEpoch(
    ((jd - _unixEpochJd) * _msPerDay).round(),
    isUtc: true,
  ).toLocal();
}

/// The hours used when the place isn't known: day is from 06:00 to 18:00.
const fallbackSunriseHour = 6;
const fallbackSunsetHour = 18;

/// The sky at [now].
///
/// With a [place]: day from sunrise to sunset, night otherwise.
/// Without one (or if the times can't be calculated): day from 06:00 to
/// 18:00 on the phone's clock.
///
/// [utcOffset] sets the time zone for tests; by default it's the phone's.
SkyState skyAt(DateTime now, {SkyPlace? place, Duration? utcOffset}) {
  final w = _Wall(utcOffset);
  if (place != null && place.latitude.isFinite && place.longitude.isFinite) {
    final state = _skyAtPlace(now, place, w);
    if (state != null) return state;
  }
  return _fallbackSky(now, w);
}

/// The phase comes from the last sunrise or sunset at or before [now], and
/// ends at the next one. Yesterday, today and tomorrow are all checked,
/// because far from the phone's time zone the sun's day can cross midnight.
/// For example, in California on a phone set to Riyadh time, the sun is up
/// from about 18:00 until about 04:00 the next day.
SkyState? _skyAtPlace(DateTime now, SkyPlace place, _Wall w) {
  final today = w.dayOf(now);
  final midnight = w.at(today.year, today.month, today.day + 1);

  // A day when the sun doesn't rise or set at all.
  final todays = SunTimes._on(today.year, today.month, today.day, place, w);
  if (todays.alwaysUp) return SkyState(SkyPhase.day, midnight);
  if (todays.alwaysDown) return SkyState(SkyPhase.night, midnight);

  // Each event starts a phase: sunrise starts day, sunset starts night.
  final events = <(DateTime, SkyPhase)>[];
  for (final shift in const [-1, 0, 1]) {
    final t = shift == 0
        ? todays
        : SunTimes._on(today.year, today.month, today.day + shift, place, w);
    final rise = t.sunrise, set = t.sunset;
    if (rise != null) events.add((rise, SkyPhase.day));
    if (set != null) events.add((set, SkyPhase.night));
  }
  if (events.isEmpty) return null;
  events.sort((a, b) => a.$1.compareTo(b.$1));

  (DateTime, SkyPhase)? last, next;
  for (final e in events) {
    // At the exact moment of sunrise it's day; at sunset it's night.
    if (e.$1.isAfter(now)) {
      next = e;
      break;
    }
    last = e;
  }
  // The current phase is the last event's phase. If there was none (the sun
  // was up or down all day yesterday), it's the opposite of the next one.
  final phase =
      last?.$2 ??
      (next!.$2 == SkyPhase.day ? SkyPhase.night : SkyPhase.day);
  // No change coming (polar days): check again at midnight.
  return SkyState(phase, next?.$1 ?? midnight);
}

SkyState _fallbackSky(DateTime now, _Wall w) {
  final d = w.dayOf(now);
  final rise = w.at(d.year, d.month, d.day, fallbackSunriseHour);
  final set = w.at(d.year, d.month, d.day, fallbackSunsetHour);
  if (now.isBefore(rise)) return SkyState(SkyPhase.night, rise);
  if (now.isBefore(set)) return SkyState(SkyPhase.day, set);
  return SkyState(
    SkyPhase.night,
    w.at(d.year, d.month, d.day + 1, fallbackSunriseHour),
  );
}
