import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sun_times.dart';

/// Says whether it's day or night where the user is, and changes on its
/// own at sunrise and sunset. Used by Virtual Farm's sky.
///
/// The place:
/// - The last place known on this phone, saved between launches. Crop
///   Recommendations saves it whenever it reads the location
///   ([rememberPlace]).
/// - Refreshed from the phone's location only if the app may already read
///   it: this never asks for permission. It uses the last position the
///   phone knows if that's recent, otherwise one quick, low-accuracy
///   reading.
/// - Without one, day is 06:00–18:00 ([skyAt]).
///
/// The phase is worked out again when the clock starts, when the app comes
/// back to the front, when the known place changes, and just after each
/// sunrise and sunset (a timer), so it changes while the screen is open.
class SkyClock extends ValueNotifier<SkyPhase> {
  SkyClock({
    DateTime Function()? now,
    Future<SkyPlace?> Function()? locate,
    this.followApp = true,
    this.utcOffset,
  }) : _now = now ?? DateTime.now,
       _locate = locate ?? _phoneLocation,
       super(SkyPhase.day) {
    _update();
    knownPlace.addListener(_update);
    if (followApp) _lifecycle = AppLifecycleListener(onResume: refresh);
    if (_savedPlaceRead) {
      // Another clock already read it: ready straight away.
      settled = true;
      unawaited(_refreshPlace());
    } else {
      unawaited(_loadSavedPlace().whenComplete(_settle));
    }
  }

  /// True once the saved place has been read (or found missing), so
  /// [value] is the real phase rather than the 06:00–18:00 guess. Until
  /// then the sky isn't drawn, so it doesn't show one phase and then
  /// switch to the other. Reading it takes a few milliseconds; a fresh
  /// location reading isn't waited for.
  bool settled = false;

  void _settle() {
    if (_disposed) return;
    if (!settled) {
      settled = true;
      notifyListeners();
    }
    unawaited(_refreshPlace());
  }

  /// The phone's time zone as a fixed offset from UTC, for tests; by
  /// default the phone's own.
  final Duration? utcOffset;

  /// The place the sky follows, shared by every clock. Null until known.
  static final ValueNotifier<SkyPlace?> knownPlace = ValueNotifier(null);

  /// For tests: makes the screens use this clock instead of a real one.
  @visibleForTesting
  static SkyClock Function()? clockForTests;

  /// A new clock: the test one if set, otherwise a real one.
  static SkyClock create() => clockForTests?.call() ?? SkyClock();

  /// Saves [place] as the user's place (on this phone), for the sky.
  static Future<void> rememberPlace(SkyPlace place) async {
    knownPlace.value = place;
    _lastLookup = DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_latKey, place.latitude);
      await prefs.setDouble(_lngKey, place.longitude);
    } catch (_) {
      // Kept for this session only.
    }
  }

  /// Forgets the place (for tests).
  @visibleForTesting
  static void resetForTests() {
    knownPlace.value = null;
    _lastLookup = null;
    _savedLoad = null;
    _savedPlaceRead = false;
  }

  final DateTime Function() _now;
  final Future<SkyPlace?> Function() _locate;

  /// Whether to update when the app comes back to the front.
  final bool followApp;

  AppLifecycleListener? _lifecycle;
  Timer? _timer;
  bool _disposed = false;

  static const _latKey = 'sky_latitude';
  static const _lngKey = 'sky_longitude';

  /// The phone's location is read at most this often.
  static const _lookupEvery = Duration(hours: 1);
  static DateTime? _lastLookup;

  /// Reading the saved place, once per app run; every clock waits for it.
  static Future<void>? _savedLoad;
  static bool _savedPlaceRead = false;

  /// When the phase changes next, for tests.
  @visibleForTesting
  DateTime? nextChange;

  /// Works the phase out again, and looks for a newer place if it's due.
  void refresh() {
    _update();
    unawaited(_refreshPlace());
  }

  void _update() {
    if (_disposed) return;
    final now = _now();
    final state = skyAt(now, place: knownPlace.value, utcOffset: utcOffset);
    value = state.phase;
    nextChange = state.nextChange;
    _timer?.cancel();
    // A second after the change, so the new phase has begun. Checked at
    // least every few hours too, in case the phone's clock is changed.
    var wait = state.nextChange.difference(now) + const Duration(seconds: 1);
    if (wait > const Duration(hours: 3)) wait = const Duration(hours: 3);
    if (wait < const Duration(seconds: 1)) wait = const Duration(seconds: 1);
    _timer = Timer(wait, _update);
  }

  /// Reads the saved place once; later calls wait for the same read. Gives
  /// up after a second, so the sky never stays hidden for long.
  static Future<void> _loadSavedPlace() =>
      _savedLoad ??= _readSavedPlace()
          .timeout(const Duration(seconds: 1), onTimeout: () {})
          .whenComplete(() => _savedPlaceRead = true);

  static Future<void> _readSavedPlace() async {
    if (knownPlace.value != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_latKey);
      final lng = prefs.getDouble(_lngKey);
      // A broken or impossible place is ignored (06:00–18:00 instead).
      if (lat != null &&
          lng != null &&
          lat.abs() <= 90 &&
          lng.abs() <= 180 &&
          knownPlace.value == null) {
        knownPlace.value = (latitude: lat, longitude: lng);
      }
    } catch (_) {
      // No saved place: the clock uses 06:00–18:00 until one is found.
    }
  }

  Future<void> _refreshPlace() async {
    final last = _lastLookup;
    if (last != null && DateTime.now().difference(last) < _lookupEvery) {
      return;
    }
    _lastLookup = DateTime.now();
    try {
      final place = await _locate();
      if (place != null && !_disposed) await rememberPlace(place);
    } catch (_) {
      // Keep the place we have (or the fallback hours).
    }
  }

  /// The phone's location, only if the app may already read it.
  static Future<SkyPlace?> _phoneLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return null;
    }
    // The phone's last position, if it's recent (no new reading needed).
    final known = await Geolocator.getLastKnownPosition();
    if (known != null &&
        DateTime.now().difference(known.timestamp) < const Duration(hours: 6)) {
      return (latitude: known.latitude, longitude: known.longitude);
    }
    // Sunrise moves by about a minute per 15 km, so low accuracy is plenty.
    try {
      final now = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return (latitude: now.latitude, longitude: now.longitude);
    } catch (_) {
      // No reading: an old position still beats none.
      if (known == null) rethrow;
      return (latitude: known.latitude, longitude: known.longitude);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _lifecycle?.dispose();
    knownPlace.removeListener(_update);
    super.dispose();
  }
}
