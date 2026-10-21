import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/crop_recommendation.dart';

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
/// 1. Reads the phone's location. Without it there is nothing to suggest,
///    so it stops with a LOCATION_* error (see [_location]).
/// 2. Sends it with the current month to POST /api/recommend, signed in
///    with the user's Firebase ID token.
/// 3. Turns the answer into a [CropRecommendationResult].
class CropRecommendationService {
  /// The API server (Vercel). For the local server on the Android emulator:
  /// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000`.
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ethmar-lake.vercel.app',
  );

  /// How many crops to ask for per page. The API sorts them best first.
  static const pageSize = 40;

  /// The first page of crops for the phone's current location.
  Future<CropRecommendationResult> recommend() async {
    final place = await _location();
    final month = DateTime.now().month;

    // The city name is only for the header, so look it up while the
    // server works.
    final city = _cityName(place.latitude, place.longitude);

    final body = await _post(
      latitude: place.latitude,
      longitude: place.longitude,
      month: month,
      offset: 0,
    );
    return _result(body, place, month, await city);
  }

  /// The next page after [loaded] crops, for the same place and month as
  /// [first], so the list stays one ranking even if the phone moved.
  Future<List<CropRecommendation>> nextPage(
    CropRecommendationResult first,
    int loaded,
  ) async {
    final body = await _post(
      latitude: first.latitude,
      longitude: first.longitude,
      month: first.conditions.month,
      offset: loaded,
    );
    return _crops(body);
  }

  /// Sends one POST /api/recommend and returns the decoded 200 answer.
  Future<Map<String, dynamic>> _post({
    required double latitude,
    required double longitude,
    required int month,
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
      // Offline, the token can't be refreshed. Any other failure means the
      // sign-in itself is no longer valid.
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
              'limit': pageSize,
              'offset': offset,
            }),
          )
          // The first request in an area also fetches its climate data.
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
  /// - LOCATION_DENIED: the user said no. Asking again shows the prompt again.
  /// - LOCATION_BLOCKED: denied for good; only the phone's settings can
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
      // The server rounds the position to ~11 km, so low accuracy is enough
      // and much faster.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return (latitude: position.latitude, longitude: position.longitude);
    } catch (_) {
      // Timed out: use the last position the phone knows, if any.
      final last = await Geolocator.getLastKnownPosition()
          .catchError((Object _) => null);
      if (last == null) {
        throw const CropRecommendationException('LOCATION_UNAVAILABLE');
      }
      return (latitude: last.latitude, longitude: last.longitude);
    }
  }

  /// Opens the phone's settings where location can be allowed again: the
  /// location switch for LOCATION_OFF, this app's permissions otherwise.
  static Future<bool> openLocationSettings(String status) =>
      status == 'LOCATION_OFF'
          ? Geolocator.openLocationSettings()
          : Geolocator.openAppSettings();

  /// The city in English and Arabic, from the phone's geocoder.
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

  /// Made-up data for design previews (lib/_preview_crop.dart).
  static const sample = CropRecommendationResult(
    conditions: GrowingConditions(
      city: BiText('Riyadh', 'الرياض'),
      month: 10,
      tempLow: 21,
      tempHigh: 35,
      rainMm: 0.5,
    ),
    crops: [
      CropRecommendation(
        name: BiText('Tomato', 'طماطم'),
        category: CropCategory.vegetable,
        band: MatchBand.excellent,
        score: 0.91,
        bestMonths: [9, 10, 11, 2],
        minTemp: 20,
        maxTemp: 27,
        waterNeed: ['medium'],
        harvestDays: (min: 70, max: 150),
        edibleParts: ['fruit'],
        reason: ModelNote(code: 'temp_ok'),
        tip: ModelNote(code: 'too_dry'),
      ),
      CropRecommendation(
        name: BiText('Mint', 'نعناع'),
        category: CropCategory.herb,
        band: MatchBand.good,
        score: 0.74,
        bestMonths: [10, 11, 12, 1, 2],
        minTemp: 15,
        maxTemp: 25,
        waterNeed: ['medium', 'high'],
        harvestDays: (min: 40, max: 270),
        edibleParts: ['leaves'],
        reason: ModelNote(code: 'ph_ok'),
        tip: ModelNote(code: 'needs_shade', months: [6, 7, 8]),
      ),
      CropRecommendation(
        name: BiText('Date palm', 'نخلة'),
        category: CropCategory.fruit,
        band: MatchBand.excellent,
        score: 0.86,
        bestMonths: [2, 3],
        minTemp: 26,
        maxTemp: 45,
        waterNeed: ['low', 'medium'],
        heightM: 20,
        edibleParts: ['fruit'],
        reason: ModelNote(code: 'temp_ok'),
      ),
    ],
  );
}
