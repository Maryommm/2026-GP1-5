import 'dart:math' as math;

/// A place on Earth, in degrees (north and east are positive).
typedef SkyPlace = ({double latitude, double longitude});

/// Whether the sky is in day or night.
enum SkyPhase { day, night }

/// The sky at some moment: its [phase], and when that phase ends.
class SkyState {
  const SkyState(this.phase, this.nextChange);
  final SkyPhase phase;

  /// When the phase changes next (local time): the next sunrise or sunset,
  /// or midnight when the sun neither rises nor sets that day.
  final DateTime nextChange;

  @override
  String toString() => 'SkyState($phase until $nextChange)';
}

/// Sunrise and sunset on one day at one place, as local times.
/// Near the poles the sun may stay up ([alwaysUp]) or down ([alwaysDown])
/// all day; then [sunrise] and [sunset] are null.
class SunTimes {
  const SunTimes._(this.sunrise, this.sunset, {required this.alwaysUp})
    : alwaysDown = !alwaysUp && sunrise == null;

  final DateTime? sunrise;
  final DateTime? sunset;
  final bool alwaysUp;
  final bool alwaysDown;

  /// Sunrise and sunset on the local calendar [date] at [place], worked
  /// out on the phone (the NOAA "sunrise equation"; within a minute or two
  /// of published times). The day is the phone's own, in its time zone.
  static SunTimes on(DateTime date, SkyPlace place) {
    final lat = place.latitude;
    final lng = place.longitude;
    // Local noon of that day, as a Julian date.
    final noon = DateTime(date.year, date.month, date.day, 12).toUtc();
    final jd = noon.millisecondsSinceEpoch / _msPerDay + _unixEpochJd;
    // The solar noon nearest that local noon.
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
    // −0.833°: the sun's edge, with the air bending its light.
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

/// The hours used when the place isn't known: day from 06:00 to 18:00 on
/// the phone's clock.
const fallbackSunriseHour = 6;
const fallbackSunsetHour = 18;

/// The sky at [now] (local time).
///
/// With a [place]: day from its sunrise until its sunset, night otherwise.
/// Without one (or if the sun's times can't be worked out): day from
/// 06:00 to 18:00.
SkyState skyAt(DateTime now, {SkyPlace? place}) {
  if (place != null && place.latitude.isFinite && place.longitude.isFinite) {
    final state = _skyAtPlace(now, place);
    if (state != null) return state;
  }
  return _fallbackSky(now);
}

SkyState? _skyAtPlace(DateTime now, SkyPlace place) {
  final today = SunTimes.on(now, place);
  final midnight = DateTime(now.year, now.month, now.day + 1);
  if (today.alwaysUp) return SkyState(SkyPhase.day, midnight);
  if (today.alwaysDown) return SkyState(SkyPhase.night, midnight);
  final rise = today.sunrise, set = today.sunset;
  if (rise == null || set == null) return null;

  if (now.isBefore(rise)) return SkyState(SkyPhase.night, rise);
  if (now.isBefore(set)) return SkyState(SkyPhase.day, set);
  // After sunset: night until tomorrow's sunrise.
  final tomorrow = SunTimes.on(midnight, place);
  final nextRise = tomorrow.sunrise;
  return SkyState(
    SkyPhase.night,
    nextRise != null && nextRise.isAfter(now) ? nextRise : midnight,
  );
}

SkyState _fallbackSky(DateTime now) {
  final rise = DateTime(now.year, now.month, now.day, fallbackSunriseHour);
  final set = DateTime(now.year, now.month, now.day, fallbackSunsetHour);
  if (now.isBefore(rise)) return SkyState(SkyPhase.night, rise);
  if (now.isBefore(set)) return SkyState(SkyPhase.day, set);
  return SkyState(
    SkyPhase.night,
    DateTime(now.year, now.month, now.day + 1, fallbackSunriseHour),
  );
}
