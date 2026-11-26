import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../models/farm_plant.dart';

/// Who is uploading: the user's id and a Firebase ID token for the Worker.
typedef JourneyPhotoSession = ({String uid, String idToken});

/// Why a journey photo couldn't be uploaded or deleted.
enum JourneyPhotoError {
  notSignedIn,
  emailNotVerified,
  unreadableImage,
  unsupportedImage,
  tooLarge,
  network,
  rateLimited,
  server,
}

class JourneyPhotoException implements Exception {
  const JourneyPhotoException(this.error, {this.statusCode});
  final JourneyPhotoError error;
  final int? statusCode;

  @override
  String toString() => 'JourneyPhotoException($error, HTTP $statusCode)';
}

/// Uploads and deletes journey timeline photos through the image Worker
/// (`workers/profile-images`, endpoint `/v1/plant-journey`). The Worker
/// keeps the Cloudinary key off the phone. Each photo is saved at
/// [JourneyPhoto.publicIdFor], and the Worker gets the uid from the login
/// token.
class JourneyPhotoService {
  JourneyPhotoService({
    http.Client? client,
    Future<JourneyPhotoSession> Function()? session,
  }) : _client = client ?? http.Client(),
       _session = session ?? _firebaseSession;

  static final Uri _endpoint = Uri.parse(
    'https://ethmar-profile-images.fanyeol-23.workers.dev/v1/plant-journey',
  );

  /// The Worker accepts up to 5 MB. Photos are made smaller when picked (see
  /// [pickWidth]), so real ones are much smaller than this.
  static const maxBytes = 5 * 1024 * 1024;

  /// The longest side and JPEG quality for picked photos: good enough for the
  /// timeline and quick to upload on mobile data.
  static const pickWidth = 1600.0;
  static const pickQuality = 80;

  static const _timeout = Duration(seconds: 60);

  final http.Client _client;
  final Future<JourneyPhotoSession> Function() _session;

  /// Uploads [image] as the photo of journey entry [entryId] of [plantId].
  Future<JourneyPhoto> upload(
    XFile image, {
    required String plantId,
    required String entryId,
  }) async {
    final Uint8List bytes;
    try {
      bytes = await image.readAsBytes();
    } catch (_) {
      throw const JourneyPhotoException(JourneyPhotoError.unreadableImage);
    }
    if (bytes.isEmpty) {
      throw const JourneyPhotoException(JourneyPhotoError.unreadableImage);
    }
    if (bytes.length > maxBytes) {
      throw const JourneyPhotoException(JourneyPhotoError.tooLarge);
    }
    final type = _mediaType(bytes);
    if (type == null) {
      throw const JourneyPhotoException(JourneyPhotoError.unsupportedImage);
    }

    final session = await _session();
    final request = http.MultipartRequest('POST', _endpoint)
      ..headers['Authorization'] = 'Bearer ${session.idToken}'
      ..fields['plantId'] = plantId
      ..fields['entryId'] = entryId
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'journey.${type.subtype == 'jpeg' ? 'jpg' : type.subtype}',
          contentType: type,
        ),
      );
    final response = await _send(request);

    // Only accept the photo this user uploaded, at the path we expect.
    final saved = _json(response)?['image'];
    final expectedId = JourneyPhoto.publicIdFor(session.uid, plantId, entryId);
    if (saved is! Map<String, dynamic> ||
        saved['publicId'] != expectedId ||
        saved['format'] != 'webp') {
      throw JourneyPhotoException(
        JourneyPhotoError.server,
        statusCode: response.statusCode,
      );
    }
    try {
      final photo = JourneyPhoto.fromMap(saved)!;
      if (photo.version <= 0 ||
          photo.width <= 0 ||
          photo.height <= 0 ||
          photo.bytes <= 0 ||
          photo.bytes > maxBytes) {
        throw const FormatException('Bad photo size.');
      }
      return photo;
    } on FormatException {
      throw JourneyPhotoException(
        JourneyPhotoError.server,
        statusCode: response.statusCode,
      );
    }
  }

  /// Deletes the photo of journey entry [entryId] of [plantId]. A photo that
  /// is already gone counts as deleted.
  Future<void> deleteEntryPhoto({
    required String plantId,
    required String entryId,
  }) => _delete({'plantId': plantId, 'entryId': entryId});

  /// Deletes all journey photos of [plantId] (used when the plant is deleted).
  Future<void> deletePlantPhotos(String plantId) =>
      _delete({'plantId': plantId});

  Future<void> _delete(Map<String, String> query) async {
    final session = await _session();
    final request = http.Request(
      'DELETE',
      _endpoint.replace(queryParameters: query),
    )..headers['Authorization'] = 'Bearer ${session.idToken}';
    await _send(request);
  }

  /// Sends [request] and turns any failure into a [JourneyPhotoException].
  Future<http.Response> _send(http.BaseRequest request) async {
    final http.Response response;
    try {
      final streamed = await _client.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed).timeout(_timeout);
    } on TimeoutException {
      throw const JourneyPhotoException(JourneyPhotoError.network);
    } on http.ClientException {
      throw const JourneyPhotoException(JourneyPhotoError.network);
    }
    final code = response.statusCode;
    if (code >= 200 && code < 300) return response;
    throw JourneyPhotoException(switch (code) {
      401 => JourneyPhotoError.notSignedIn,
      403 => JourneyPhotoError.emailNotVerified,
      413 => JourneyPhotoError.tooLarge,
      415 => JourneyPhotoError.unsupportedImage,
      429 => JourneyPhotoError.rateLimited,
      _ => JourneyPhotoError.server,
    }, statusCode: code);
  }

  static Map<String, dynamic>? _json(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// Detects JPEG, PNG or WebP from the file's first bytes. Returns null for
  /// anything else.
  static MediaType? _mediaType(Uint8List b) {
    bool starts(List<int> sig, [int at = 0]) =>
        b.length >= at + sig.length &&
        [for (var i = 0; i < sig.length; i++) b[at + i] == sig[i]]
            .every((x) => x);
    if (starts(const [0xff, 0xd8, 0xff])) return MediaType('image', 'jpeg');
    if (starts(const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
      return MediaType('image', 'png');
    }
    if (starts(ascii.encode('RIFF')) && starts(ascii.encode('WEBP'), 8)) {
      return MediaType('image', 'webp');
    }
    return null;
  }

  /// The signed-in user and a fresh ID token. The token is refreshed every
  /// time so a newly verified email works right away.
  static Future<JourneyPhotoSession> _firebaseSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const JourneyPhotoException(JourneyPhotoError.notSignedIn);
    }
    if (!user.emailVerified) {
      throw const JourneyPhotoException(JourneyPhotoError.emailNotVerified);
    }
    try {
      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) {
        throw const JourneyPhotoException(JourneyPhotoError.notSignedIn);
      }
      return (uid: user.uid, idToken: token);
    } on FirebaseAuthException catch (e) {
      throw JourneyPhotoException(
        e.code == 'network-request-failed'
            ? JourneyPhotoError.network
            : JourneyPhotoError.notSignedIn,
      );
    }
  }
}
