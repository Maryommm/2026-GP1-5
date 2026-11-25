import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../models/farm_plant.dart';

/// Who is uploading: the user's id and a Firebase ID token for the Worker.
typedef GrowthPhotoSession = ({String uid, String idToken});

/// Why a growth photo couldn't be uploaded or deleted.
enum GrowthPhotoError {
  notSignedIn,
  emailNotVerified,
  unreadableImage,
  unsupportedImage,
  tooLarge,
  network,
  rateLimited,
  server,
}

class GrowthPhotoException implements Exception {
  const GrowthPhotoException(this.error, {this.statusCode});
  final GrowthPhotoError error;
  final int? statusCode;

  @override
  String toString() => 'GrowthPhotoException($error, HTTP $statusCode)';
}

/// Uploads and deletes growth timeline photos through the image Worker
/// (`workers/profile-images`, endpoint `/v1/plant-growth`), which keeps the
/// Cloudinary key off the phone. Each photo is saved at
/// [GrowthPhoto.publicIdFor]; the Worker takes the uid from the login token.
class GrowthPhotoService {
  GrowthPhotoService({
    http.Client? client,
    Future<GrowthPhotoSession> Function()? session,
  }) : _client = client ?? http.Client(),
       _session = session ?? _firebaseSession;

  static final Uri _endpoint = Uri.parse(
    'https://ethmar-profile-images.fanyeol-23.workers.dev/v1/plant-growth',
  );

  /// The Worker accepts up to 5 MB. Photos are shrunk when picked (see
  /// [pickWidth]), so a real one is far smaller.
  static const maxBytes = 5 * 1024 * 1024;

  /// The longest side to pick a photo at, and its JPEG quality: enough
  /// for the timeline, and quick to send on mobile data.
  static const pickWidth = 1600.0;
  static const pickQuality = 80;

  static const _timeout = Duration(seconds: 60);

  final http.Client _client;
  final Future<GrowthPhotoSession> Function() _session;

  /// Uploads [image] as the photo of growth entry [entryId] of [plantId].
  Future<GrowthPhoto> upload(
    XFile image, {
    required String plantId,
    required String entryId,
  }) async {
    final Uint8List bytes;
    try {
      bytes = await image.readAsBytes();
    } catch (_) {
      throw const GrowthPhotoException(GrowthPhotoError.unreadableImage);
    }
    if (bytes.isEmpty) {
      throw const GrowthPhotoException(GrowthPhotoError.unreadableImage);
    }
    if (bytes.length > maxBytes) {
      throw const GrowthPhotoException(GrowthPhotoError.tooLarge);
    }
    final type = _mediaType(bytes);
    if (type == null) {
      throw const GrowthPhotoException(GrowthPhotoError.unsupportedImage);
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
          filename: 'growth.${type.subtype == 'jpeg' ? 'jpg' : type.subtype}',
          contentType: type,
        ),
      );
    final response = await _send(request);

    // Accept only the photo this user asked for, as the Worker saves it.
    final saved = _json(response)?['image'];
    final expectedId = GrowthPhoto.publicIdFor(session.uid, plantId, entryId);
    if (saved is! Map<String, dynamic> ||
        saved['publicId'] != expectedId ||
        saved['format'] != 'webp') {
      throw GrowthPhotoException(
        GrowthPhotoError.server,
        statusCode: response.statusCode,
      );
    }
    try {
      final photo = GrowthPhoto.fromMap(saved)!;
      if (photo.version <= 0 ||
          photo.width <= 0 ||
          photo.height <= 0 ||
          photo.bytes <= 0 ||
          photo.bytes > maxBytes) {
        throw const FormatException('Bad photo size.');
      }
      return photo;
    } on FormatException {
      throw GrowthPhotoException(
        GrowthPhotoError.server,
        statusCode: response.statusCode,
      );
    }
  }

  /// Deletes the photo of growth entry [entryId] of [plantId]. A photo
  /// that's already gone counts as deleted.
  Future<void> deleteEntryPhoto({
    required String plantId,
    required String entryId,
  }) => _delete({'plantId': plantId, 'entryId': entryId});

  /// Deletes every growth photo of [plantId], when the plant is deleted.
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

  /// Sends [request] and turns a failure into a [GrowthPhotoException].
  Future<http.Response> _send(http.BaseRequest request) async {
    final http.Response response;
    try {
      final streamed = await _client.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed).timeout(_timeout);
    } on TimeoutException {
      throw const GrowthPhotoException(GrowthPhotoError.network);
    } on http.ClientException {
      throw const GrowthPhotoException(GrowthPhotoError.network);
    }
    final code = response.statusCode;
    if (code >= 200 && code < 300) return response;
    throw GrowthPhotoException(switch (code) {
      401 => GrowthPhotoError.notSignedIn,
      403 => GrowthPhotoError.emailNotVerified,
      413 => GrowthPhotoError.tooLarge,
      415 => GrowthPhotoError.unsupportedImage,
      429 => GrowthPhotoError.rateLimited,
      _ => GrowthPhotoError.server,
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

  /// JPEG, PNG or WebP, from the file's first bytes; null for anything else.
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

  /// The signed-in user and a fresh ID token. Refreshed every time, like
  /// the profile picture's, so a newly verified email counts at once.
  static Future<GrowthPhotoSession> _firebaseSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const GrowthPhotoException(GrowthPhotoError.notSignedIn);
    }
    if (!user.emailVerified) {
      throw const GrowthPhotoException(GrowthPhotoError.emailNotVerified);
    }
    try {
      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) {
        throw const GrowthPhotoException(GrowthPhotoError.notSignedIn);
      }
      return (uid: user.uid, idToken: token);
    } on FirebaseAuthException catch (e) {
      throw GrowthPhotoException(
        e.code == 'network-request-failed'
            ? GrowthPhotoError.network
            : GrowthPhotoError.notSignedIn,
      );
    }
  }
}
