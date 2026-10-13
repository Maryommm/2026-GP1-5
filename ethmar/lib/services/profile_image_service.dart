import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

typedef ProfileImageSessionProvider = Future<ProfileImageSession> Function();

class ProfileImageSession {
  const ProfileImageSession({required this.uid, required this.idToken});

  final String uid;
  final String idToken;
}

enum ProfileImageErrorCode {
  unauthenticated,
  emailNotVerified,
  unsupportedImage,
  imageTooLarge,
  network,
  unauthorized,
  rateLimited,
  server,
  metadata,
  invalidResponse,
}

class ProfileImageException implements Exception {
  const ProfileImageException(
    this.code, {
    this.statusCode,
    this.retryAfterSeconds,
    this.diagnosticCode,
  });

  final ProfileImageErrorCode code;
  final int? statusCode;
  final int? retryAfterSeconds;
  final String? diagnosticCode;

  /// Contains only an HTTP status and a strictly filtered machine-readable
  /// code. Response messages and bodies are deliberately never exposed.
  String? get safeDiagnostic {
    final parts = <String>[
      if (statusCode != null) 'HTTP $statusCode',
      if (diagnosticCode != null) diagnosticCode!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class UploadedProfileImage {
  const UploadedProfileImage({
    required this.publicId,
    required this.secureUrl,
    required this.version,
    required this.format,
    required this.width,
    required this.height,
    required this.bytes,
  });

  final String publicId;
  final String secureUrl;
  final int version;
  final String format;
  final int width;
  final int height;
  final int bytes;

  static const _cloudName = 'k7otdsln';

  static String publicIdFor(String uid) => 'ethmar/profile-images/$uid/profile';

  static String deliveryUrlFor({
    required String publicId,
    required int version,
  }) =>
      'https://res.cloudinary.com/$_cloudName/image/upload/'
      'v$version/$publicId.webp';

  Map<String, Object> toFirestore() => {
    'publicId': publicId,
    'version': version,
    'format': format,
    'width': width,
    'height': height,
    'bytes': bytes,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static UploadedProfileImage? fromFirestore(
    String uid,
    Map<String, dynamic>? data,
  ) {
    if (data == null ||
        data.length != 7 ||
        data['publicId'] != publicIdFor(uid) ||
        data['version'] is! int ||
        (data['version'] as int) <= 0 ||
        data['format'] != 'webp' ||
        data['width'] is! int ||
        (data['width'] as int) <= 0 ||
        (data['width'] as int) > 4096 ||
        data['height'] is! int ||
        (data['height'] as int) <= 0 ||
        (data['height'] as int) > 4096 ||
        data['bytes'] is! int ||
        (data['bytes'] as int) <= 0 ||
        (data['bytes'] as int) > ProfileImageService.maxImageBytes ||
        data['updatedAt'] is! Timestamp) {
      return null;
    }

    final publicId = data['publicId'] as String;
    final version = data['version'] as int;
    return UploadedProfileImage(
      publicId: publicId,
      secureUrl: deliveryUrlFor(publicId: publicId, version: version),
      version: version,
      format: data['format'] as String,
      width: data['width'] as int,
      height: data['height'] as int,
      bytes: data['bytes'] as int,
    );
  }
}

class DeletedProfileImage {
  const DeletedProfileImage({required this.deleted, required this.notFound});

  final bool deleted;
  final bool notFound;
}

abstract interface class ProfileImageMetadataStore {
  Future<void> save(String uid, UploadedProfileImage image);

  Future<void> delete(String uid);

  Stream<UploadedProfileImage?> watch(String uid);
}

class FirestoreProfileImageMetadataStore implements ProfileImageMetadataStore {
  FirestoreProfileImageMetadataStore({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _document(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('media')
      .doc('profile');

  @override
  Future<void> save(String uid, UploadedProfileImage image) =>
      _document(uid).set(image.toFirestore());

  @override
  Future<void> delete(String uid) => _document(uid).delete();

  @override
  Stream<UploadedProfileImage?> watch(String uid) => _document(uid)
      .snapshots()
      .map(
        (snapshot) => UploadedProfileImage.fromFirestore(uid, snapshot.data()),
      );
}

final ProfileImageMetadataStore profileImageMetadataStore =
    FirestoreProfileImageMetadataStore();

class ProfileImageService {
  ProfileImageService({
    FirebaseAuth? auth,
    http.Client? client,
    ProfileImageSessionProvider? sessionProvider,
    ProfileImageMetadataStore? metadataStore,
  }) : _auth = auth,
       _client = client ?? http.Client(),
       _sessionProvider = sessionProvider,
       _metadataStore = metadataStore ?? profileImageMetadataStore;

  static final Uri _endpoint = Uri.parse(
    'https://ethmar-profile-images.fanyeol-23.workers.dev/v1/profile-image',
  );
  static const maxImageBytes = 5 * 1024 * 1024;
  static const _timeout = Duration(seconds: 60);
  static final _safeDiagnosticCode = RegExp(r'^[A-Z][A-Z0-9_]{1,63}$');

  final FirebaseAuth? _auth;
  final http.Client _client;
  final ProfileImageSessionProvider? _sessionProvider;
  final ProfileImageMetadataStore _metadataStore;

  Stream<UploadedProfileImage?> watchCurrentProfileImage() {
    final user = (_auth ?? FirebaseAuth.instance).currentUser;
    if (user == null || !user.emailVerified) {
      return Stream<UploadedProfileImage?>.value(null);
    }
    return _metadataStore.watch(user.uid);
  }

  Future<UploadedProfileImage> upload(XFile image) async {
    final length = await image.length();
    if (length <= 0) {
      throw const ProfileImageException(ProfileImageErrorCode.unsupportedImage);
    }
    if (length > maxImageBytes) {
      throw const ProfileImageException(ProfileImageErrorCode.imageTooLarge);
    }

    final imageBytes = await image.readAsBytes();
    if (imageBytes.length > maxImageBytes) {
      throw const ProfileImageException(ProfileImageErrorCode.imageTooLarge);
    }
    final mediaType = _detectMediaType(imageBytes);
    if (mediaType == null) {
      throw const ProfileImageException(ProfileImageErrorCode.unsupportedImage);
    }

    final session = await _getVerifiedSession();
    final request = http.MultipartRequest('POST', _endpoint)
      ..headers['Authorization'] = 'Bearer ${session.idToken}'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          // Android cache names and extensions are not trusted. Both the
          // filename and MIME type come from the detected file bytes.
          filename: 'profile.${_extensionFor(mediaType)}',
          contentType: mediaType,
        ),
      );
    final response = await _send(request);
    _throwForError(response);

    final body = _decodeObject(response);
    final imageJson = body['image'];
    if (imageJson is! Map<String, dynamic>) {
      _throwInvalidSuccessResponse(response);
    }

    final publicId = imageJson['publicId'];
    final secureUrl = imageJson['secureUrl'];
    final version = imageJson['version'];
    final format = imageJson['format'];
    final width = imageJson['width'];
    final height = imageJson['height'];
    final bytes = imageJson['bytes'];
    final expectedPublicId = UploadedProfileImage.publicIdFor(session.uid);
    if (publicId is! String ||
        publicId != expectedPublicId ||
        secureUrl is! String ||
        version is! int ||
        version <= 0 ||
        !_isExpectedCloudinaryUrl(
          secureUrl,
          publicId: expectedPublicId,
          version: version,
        ) ||
        format != 'webp' ||
        width is! int ||
        width <= 0 ||
        width > 4096 ||
        height is! int ||
        height <= 0 ||
        height > 4096 ||
        bytes is! int ||
        bytes <= 0 ||
        bytes > maxImageBytes) {
      _throwInvalidSuccessResponse(response);
    }

    final uploaded = UploadedProfileImage(
      publicId: publicId,
      // Use our canonical delivery URL after validating Cloudinary's URL.
      // This accepts legitimate transformation segments without storing them.
      secureUrl: UploadedProfileImage.deliveryUrlFor(
        publicId: expectedPublicId,
        version: version,
      ),
      version: version,
      format: format,
      width: width,
      height: height,
      bytes: bytes,
    );
    await _saveMetadata(session.uid, uploaded);
    return uploaded;
  }

  Future<DeletedProfileImage> delete() async {
    final session = await _getVerifiedSession();
    final request = http.Request('DELETE', _endpoint)
      ..headers['Authorization'] = 'Bearer ${session.idToken}';
    final response = await _send(request);
    _throwForError(response);

    final body = _decodeObject(response);
    final deleted = body['deleted'];
    final status = body['status'];
    if (deleted is! bool || (status != 'deleted' && status != 'not_found')) {
      _throwInvalidSuccessResponse(response);
    }
    final result = DeletedProfileImage(
      deleted: deleted,
      notFound: status == 'not_found',
    );
    await _deleteMetadata(session.uid);
    return result;
  }

  Future<ProfileImageSession> _getVerifiedSession() async {
    final customProvider = _sessionProvider;
    if (customProvider != null) {
      final session = await customProvider();
      if (session.uid.isEmpty || session.idToken.isEmpty) {
        throw const ProfileImageException(
          ProfileImageErrorCode.unauthenticated,
        );
      }
      return session;
    }

    final user = (_auth ?? FirebaseAuth.instance).currentUser;
    if (user == null) {
      throw const ProfileImageException(ProfileImageErrorCode.unauthenticated);
    }
    if (!user.emailVerified) {
      throw const ProfileImageException(ProfileImageErrorCode.emailNotVerified);
    }

    try {
      // Keep the token in this request scope only; never log or persist it.
      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) {
        throw const ProfileImageException(
          ProfileImageErrorCode.unauthenticated,
        );
      }
      return ProfileImageSession(uid: user.uid, idToken: token);
    } on ProfileImageException {
      rethrow;
    } on FirebaseAuthException {
      throw const ProfileImageException(ProfileImageErrorCode.unauthenticated);
    }
  }

  Future<void> _saveMetadata(String uid, UploadedProfileImage image) async {
    try {
      await _metadataStore.save(uid, image);
    } on FirebaseException catch (error) {
      if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
        throw const ProfileImageException(ProfileImageErrorCode.network);
      }
      throw const ProfileImageException(ProfileImageErrorCode.metadata);
    } catch (_) {
      throw const ProfileImageException(ProfileImageErrorCode.metadata);
    }
  }

  Future<void> _deleteMetadata(String uid) async {
    try {
      await _metadataStore.delete(uid);
    } on FirebaseException catch (error) {
      if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
        throw const ProfileImageException(ProfileImageErrorCode.network);
      }
      throw const ProfileImageException(ProfileImageErrorCode.metadata);
    } catch (_) {
      throw const ProfileImageException(ProfileImageErrorCode.metadata);
    }
  }

  Future<http.Response> _send(http.BaseRequest request) async {
    try {
      final streamed = await _client.send(request).timeout(_timeout);
      return await http.Response.fromStream(streamed).timeout(_timeout);
    } on TimeoutException {
      throw const ProfileImageException(ProfileImageErrorCode.network);
    } on http.ClientException {
      throw const ProfileImageException(ProfileImageErrorCode.network);
    }
  }

  void _throwForError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final diagnosticCode = _workerErrorCode(response);
    switch (response.statusCode) {
      case 401:
        throw ProfileImageException(
          ProfileImageErrorCode.unauthorized,
          statusCode: 401,
          diagnosticCode: diagnosticCode,
        );
      case 403:
        throw ProfileImageException(
          ProfileImageErrorCode.emailNotVerified,
          statusCode: 403,
          diagnosticCode: diagnosticCode,
        );
      case 413:
        throw ProfileImageException(
          ProfileImageErrorCode.imageTooLarge,
          statusCode: 413,
          diagnosticCode: diagnosticCode,
        );
      case 415:
        throw ProfileImageException(
          ProfileImageErrorCode.unsupportedImage,
          statusCode: 415,
          diagnosticCode: diagnosticCode,
        );
      case 429:
        throw ProfileImageException(
          ProfileImageErrorCode.rateLimited,
          statusCode: 429,
          diagnosticCode: diagnosticCode,
          retryAfterSeconds: int.tryParse(
            response.headers['retry-after'] ?? '',
          ),
        );
      default:
        throw ProfileImageException(
          ProfileImageErrorCode.server,
          statusCode: response.statusCode,
          diagnosticCode: diagnosticCode,
        );
    }
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final decoded = _tryDecodeObject(response);
    if (decoded != null) return decoded;
    _throwInvalidSuccessResponse(response);
  }

  Map<String, dynamic>? _tryDecodeObject(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Never expose an upstream response body through diagnostics.
    }
    return null;
  }

  String? _workerErrorCode(http.Response response) {
    final body = _tryDecodeObject(response);
    final error = body?['error'];
    final code = error is Map<String, dynamic> ? error['code'] : null;
    if (code is String && _safeDiagnosticCode.hasMatch(code)) return code;
    return null;
  }

  Never _throwInvalidSuccessResponse(http.Response response) {
    throw ProfileImageException(
      ProfileImageErrorCode.invalidResponse,
      statusCode: response.statusCode,
      diagnosticCode: 'INVALID_SUCCESS_RESPONSE',
    );
  }

  bool _isExpectedCloudinaryUrl(
    String value, {
    required String publicId,
    required int version,
  }) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'res.cloudinary.com' ||
        uri.hasQuery ||
        uri.hasFragment) {
      return false;
    }

    final segments = uri.pathSegments;
    if (segments.length < 5 ||
        segments[0] != UploadedProfileImage._cloudName ||
        segments[1] != 'image' ||
        segments[2] != 'upload') {
      return false;
    }

    final versionIndex = segments.indexOf('v$version', 3);
    if (versionIndex < 3 || versionIndex == segments.length - 1) return false;
    return segments.sublist(versionIndex + 1).join('/') == '$publicId.webp';
  }

  MediaType? _detectMediaType(Uint8List bytes) {
    const pngSignature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
    if (bytes.length >= pngSignature.length) {
      var isPng = true;
      for (var i = 0; i < pngSignature.length; i += 1) {
        if (bytes[i] != pngSignature[i]) {
          isPng = false;
          break;
        }
      }
      if (isPng) return MediaType('image', 'png');
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff &&
        bytes[bytes.length - 2] == 0xff &&
        bytes[bytes.length - 1] == 0xd9) {
      return MediaType('image', 'jpeg');
    }
    if (bytes.length >= 20 &&
        _matchesAscii(bytes, 0, 'RIFF') &&
        _matchesAscii(bytes, 8, 'WEBP') &&
        _uint32le(bytes, 4) + 8 == bytes.length &&
        (_matchesAscii(bytes, 12, 'VP8 ') ||
            _matchesAscii(bytes, 12, 'VP8L') ||
            _matchesAscii(bytes, 12, 'VP8X'))) {
      return MediaType('image', 'webp');
    }
    return null;
  }

  String _extensionFor(MediaType mediaType) => switch (mediaType.subtype) {
    'jpeg' => 'jpg',
    'png' => 'png',
    'webp' => 'webp',
    _ => throw const ProfileImageException(
      ProfileImageErrorCode.unsupportedImage,
    ),
  };

  bool _matchesAscii(Uint8List bytes, int offset, String value) {
    if (offset + value.length > bytes.length) return false;
    for (var index = 0; index < value.length; index += 1) {
      if (bytes[offset + index] != value.codeUnitAt(index)) return false;
    }
    return true;
  }

  int _uint32le(Uint8List bytes, int offset) =>
      bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);

  void close() => _client.close();
}
