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
/// 1. Reads the phone's location (Riyadh if location is off or denied).
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

  /// How many crops to ask for. The API sorts them best first.
  static const _limit = 40;

  Future<CropRecommendationResult> recommend() async {
    if (baseUrl.isEmpty) {
      throw const CropRecommendationException(
          'NOT_CONFIGURED', 'API_BASE_URL is not set');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const CropRecommendationException('UNAUTHENTICATED');
    }
    final token = await user.getIdToken();
    final place = await _location();
    final month = DateTime.now().month;

    // The city name is only for the header, so look it up while the
    // server works.
    final city = _cityName(place.latitude, place.longitude, place.isFallback);

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
              'latitude': place.latitude,
              'longitude': place.longitude,
              'month': month,
              'limit': _limit,
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
      throw CropRecommendationException('INTERNAL', 'HTTP ${response.statusCode}');
    }
    if (response.statusCode != 200) {
      final error = (body['error'] as Map?)?.cast<String, dynamic>() ?? {};
      throw CropRecommendationException(
        error['status'] as String? ?? 'INTERNAL',
        error['message'] as String? ?? 'HTTP ${response.statusCode}',
      );
    }
    return _result(body, month, await city);
  }

  CropRecommendationResult _result(
    Map<String, dynamic> body,
    int month,
    BiText city,
  ) {
    final climate = (body['climate'] as Map?)?.cast<String, dynamic>() ?? {};
    return CropRecommendationResult(
      conditions: GrowingConditions(
        city: city,
        month: (body['month'] as num?)?.toInt() ?? month,
        tempLow: (climate['temp_low_c'] as num? ?? 0).round(),
        tempHigh: (climate['temp_high_c'] as num? ?? 0).round(),
        rainMm: (climate['rain_mm'] as num? ?? 0).toDouble(),
      ),
      crops: [
        for (final item in (body['results'] as List? ?? const []))
          if (item is Map)
            CropRecommendation.fromJson(item.cast<String, dynamic>()),
      ],
    );
  }

  /// The phone's position, or Riyadh when it isn't available.
  Future<({double latitude, double longitude, bool isFallback})>
      _location() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return _fallback;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _fallback;
      }
      // The server rounds the position to ~11 km, so low accuracy is enough
      // and much faster.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return (
        latitude: position.latitude,
        longitude: position.longitude,
        isFallback: false,
      );
    } catch (_) {
      // Timeout, or no location support on this platform.
      final last = await Geolocator.getLastKnownPosition()
          .catchError((Object _) => null);
      if (last == null) return _fallback;
      return (
        latitude: last.latitude,
        longitude: last.longitude,
        isFallback: false,
      );
    }
  }

  /// Riyadh.
  static const _fallback = (
    latitude: 24.71,
    longitude: 46.67,
    isFallback: true,
  );

  /// The city in English and Arabic, from the phone's geocoder.
  Future<BiText> _cityName(
    double latitude,
    double longitude,
    bool isFallback,
  ) async {
    if (isFallback) return const BiText('Riyadh', 'الرياض');
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
        plantNow: true,
        plantMonth: 10,
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
        plantNow: true,
        plantMonth: 10,
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
        plantNow: false,
        plantMonth: 2,
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
