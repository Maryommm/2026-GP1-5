import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/crop_recommendation.dart';
import 'sky_clock.dart';

/// Why the recommendations could not be loaded. [status] is the API's error
/// status (see api/index.py), or "NETWORK" when the server can't be reached.
class CropRecommendationException implements Exception {
  const CropRecommendationException(this.status, [this.message = '']);
  final String status;
  final String message;

  @override
  String toString() => 'CropRecommendationException($status, $message)';
}

/// Gets crop suggestions for the user's area from the recommendation API.
///
/// 1. Reads the phone's location. Without it we can't suggest anything, so
///    it throws a LOCATION_* error (see [_location]).
/// 2. Sends the location, the current month and the user's answers (pot or
///    ground, sunlight, watering) to POST /api/recommend, with the user's
///    Firebase ID token.
/// 3. Turns the response into a [CropRecommendationResult].
class CropRecommendationService {
  /// The API server (Vercel). To use a local server on the Android emulator:
  /// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000`.
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ethmar-lake.vercel.app',
  );

  /// For testing the "average soil pH" message:
  /// `flutter run --dart-define=FAKE_SOIL_ESTIMATED=true` shows it as if the
  /// area's soil data couldn't be loaded. Off by default.
  static const _fakeSoilEstimated = bool.fromEnvironment('FAKE_SOIL_ESTIMATED');

  /// How many crops to ask for per page. The API sorts them best first.
  static const pageSize = 40;

  /// The first page of crops for the phone's current location.
  Future<CropRecommendationResult> recommend(GrowingSetup setup) async {
    final place = await _location();
    // Save the place so the Virtual Farm sky can follow the user's sunrise and
    // sunset.
    unawaited(SkyClock.rememberPlace(place));
    final month = DateTime.now().month;

    // The city name is only for the header, so we look it up while the server
    // is working.
    final city = _cityName(place.latitude, place.longitude);

    final body = await _post(
      latitude: place.latitude,
      longitude: place.longitude,
      month: month,
      setup: setup,
      offset: 0,
    );
    return _result(body, place, month, setup, await city);
  }

  /// The next page of crops after [loaded] crops. It uses the same place and
  /// month as [first], so the list stays in the same order even if the phone
  /// moved.
  Future<List<CropRecommendation>> nextPage(
    CropRecommendationResult first,
    int loaded,
  ) async {
    final body = await _post(
      latitude: first.latitude,
      longitude: first.longitude,
      month: first.conditions.month,
      setup: first.setup,
      offset: loaded,
    );
    return _crops(body);
  }

  /// Sends one POST /api/recommend and returns the decoded response.
  Future<Map<String, dynamic>> _post({
    required double latitude,
    required double longitude,
    required int month,
    required GrowingSetup setup,
    required int offset,
  }) async {
    if (baseUrl.isEmpty) {
      throw const CropRecommendationException(
          'NOT_CONFIGURED', 'API_BASE_URL is not set');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const CropRecommendationException('UNAUTHENTICATED');
    }

    final String? token;
    try {
      token = await user.getIdToken();
    } on FirebaseAuthException catch (e) {
      // If offline, the token can't be refreshed. Any other error means the
      // sign-in is no longer valid.
      throw CropRecommendationException(
        e.code == 'network-request-failed' ? 'NETWORK' : 'UNAUTHENTICATED',
        e.code,
      );
    }

    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$baseUrl/api/recommend'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'latitude': latitude,
              'longitude': longitude,
              'month': month,
              ...setup.toJson(),
              'limit': pageSize,
              'offset': offset,
            }),
          )
          // The first request in a new area also downloads its climate data, so it
          // can take longer.
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const CropRecommendationException('NETWORK', 'timed out');
    } on http.ClientException catch (e) {
      throw CropRecommendationException('NETWORK', e.message);
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } on FormatException {
      throw CropRecommendationException(
        response.statusCode == 401 ? 'UNAUTHENTICATED' : 'INTERNAL',
        'HTTP ${response.statusCode}',
      );
    }
    if (response.statusCode != 200) {
      final error = (body['error'] as Map?)?.cast<String, dynamic>() ?? {};
      throw CropRecommendationException(
        error['status'] as String? ??
            (response.statusCode == 401 ? 'UNAUTHENTICATED' : 'INTERNAL'),
        error['message'] as String? ?? 'HTTP ${response.statusCode}',
      );
    }
    return body;
  }

  CropRecommendationResult _result(
    Map<String, dynamic> body,
    ({double latitude, double longitude}) place,
    int month,
    GrowingSetup setup,
    BiText city,
  ) {
    final climate = (body['climate'] as Map?)?.cast<String, dynamic>() ?? {};
    final crops = _crops(body);
    return CropRecommendationResult(
      conditions: GrowingConditions(
        city: city,
        month: (body['month'] as num?)?.toInt() ?? month,
        tempLow: (climate['temp_low_c'] as num? ?? 0).round(),
        tempHigh: (climate['temp_high_c'] as num? ?? 0).round(),
        rainMm: (climate['rain_mm'] as num? ?? 0).toDouble(),
      ),
      crops: crops,
      total: (body['total'] as num?)?.toInt() ?? crops.length,
      latitude: place.latitude,
      longitude: place.longitude,
      setup: setup,
      soilPhEstimated:
          _fakeSoilEstimated || body['soil_ph_estimated'] == true,
    );
  }

  static List<CropRecommendation> _crops(Map<String, dynamic> body) => [
        for (final item in (body['results'] as List? ?? const []))
          if (item is Map)
            CropRecommendation.fromJson(item.cast<String, dynamic>()),
      ];

  /// The phone's position. Throws a [CropRecommendationException] when it
  /// can't be read:
  /// - LOCATION_OFF: location is turned off on the phone.
  /// - LOCATION_DENIED: the user said no. We can ask again.
  /// - LOCATION_BLOCKED: denied permanently; only the phone's settings can
  ///   allow it now (see [openLocationSettings]).
  /// - LOCATION_UNAVAILABLE: allowed, but no position could be read.
  Future<({double latitude, double longitude})> _location() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const CropRecommendationException('LOCATION_OFF');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const CropRecommendationException('LOCATION_DENIED');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const CropRecommendationException('LOCATION_BLOCKED');
    }
    try {
      // The server rounds the position to about 11 km, so low accuracy is enough
      // and much faster.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return (latitude: position.latitude, longitude: position.longitude);
    } catch (_) {
      // Timed out: use the last position the phone knows, if there is one.
      final last = await Geolocator.getLastKnownPosition()
          .catchError((Object _) => null);
      if (last == null) {
        throw const CropRecommendationException('LOCATION_UNAVAILABLE');
      }
      return (latitude: last.latitude, longitude: last.longitude);
    }
  }

  /// Opens the phone's settings so location can be allowed again: the
  /// location switch for LOCATION_OFF, otherwise this app's permissions.
  static Future<bool> openLocationSettings(String status) =>
      status == 'LOCATION_OFF'
          ? Geolocator.openLocationSettings()
          : Geolocator.openAppSettings();

  /// The city name in English and Arabic, from the phone's geocoder.
  Future<BiText> _cityName(double latitude, double longitude) async {
    try {
      final geocoding = Geocoding();
      Future<String?> name(String language) async {
        final places = await geocoding.placemarkFromCoordinates(
          latitude,
          longitude,
          locale: Locale(language),
        );
        if (places.isEmpty) return null;
        final p = places.first;
        for (final value in [p.locality, p.subAdministrativeArea,
            p.administrativeArea]) {
          if (value != null && value.isNotEmpty) return value;
        }
        return null;
      }

      final names = await Future.wait([name('en'), name('ar')])
          .timeout(const Duration(seconds: 8));
      final en = names[0], ar = names[1];
      if (en == null && ar == null) return _yourArea;
      return BiText(en ?? ar!, ar ?? en!);
    } catch (_) {
      return _yourArea;
    }
  }

  static const _yourArea = BiText('Your area', 'منطقتك');
}
