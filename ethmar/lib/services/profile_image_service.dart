import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

// Define a custom provider for Firebase sessions.
typedef ProfileImageSessionProvider = Future<ProfileImageSession> Function();

// Store the user ID and Firebase ID token.
class ProfileImageSession {
  const ProfileImageSession({required this.uid, required this.idToken});

  final String uid;
  final String idToken;
}

// List possible profile image errors.
enum ProfileImageErrorCode {
  unauthenticated,
  emailNotVerified,
  // The selected file could not be read from the device.
  unreadableImage,
  unsupportedImage,
  imageTooLarge,
  network,
  unauthorized,
  rateLimited,
  server,
  metadata,
  invalidResponse,
}

// Represent a profile image error with safe details.
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

  /// Shows only safe error details, without response messages or bodies.
  String? get safeDiagnostic {
    final parts = <String>[
      if (statusCode != null) 'HTTP $statusCode',
      if (diagnosticCode != null) diagnosticCode!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

// Store information about an uploaded profile image.
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

  // Identify the Cloudinary account.
  static const _cloudName = 'k7otdsln';

  // Build a unique image ID for each user.
  static String publicIdFor(String uid) => 'ethmar/profile-images/$uid/profile';

  // Build the image delivery URL.
  static String deliveryUrlFor({
    required String publicId,
    required int version,
  }) =>
      'https://res.cloudinary.com/$_cloudName/image/upload/'
      'v$version/$publicId.webp';

  // Convert image details into Firestore fields.
  Map<String, Object> toFirestore() => {
    'publicId': publicId,
    'version': version,
    'format': format,
    'width': width,
    'height': height,
    'bytes': bytes,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  // Validate saved image details before using them.
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

// Store the result of a photo deletion.
class DeletedProfileImage {
  const DeletedProfileImage({required this.deleted, required this.notFound});

  final bool deleted;
  final bool notFound;
}

// Define how image details are saved and read.
abstract interface class ProfileImageMetadataStore {
  // Save uploaded image details.
  Future<void> save(String uid, UploadedProfileImage image);

  // Delete saved image details.
  Future<void> delete(String uid);

  // Listen for changes to image details.
  Stream<UploadedProfileImage?> watch(String uid);
}

// Store profile image details in Firestore.
class FirestoreProfileImageMetadataStore implements ProfileImageMetadataStore {
  FirestoreProfileImageMetadataStore({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // Locate the user profile image document.
  DocumentReference<Map<String, dynamic>> _document(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('media')
      .doc('profile');

  @override
  // Save uploaded image details.
  Future<void> save(String uid, UploadedProfileImage image) =>
      _document(uid).set(image.toFirestore());

  @override
  // Delete saved image details.
  Future<void> delete(String uid) => _document(uid).delete();

  @override
  // Listen for changes to image details.
  Stream<UploadedProfileImage?> watch(String uid) => _document(uid)
      .snapshots()
      .map(
        (snapshot) => UploadedProfileImage.fromFirestore(uid, snapshot.data()),
      );
}

// Use Firestore as the default metadata store.
final ProfileImageMetadataStore profileImageMetadataStore =
    FirestoreProfileImageMetadataStore();

// Handle profile image uploads, deletion, and validation.
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

  // Cloudflare Worker endpoint for image requests.
  static final Uri _endpoint = Uri.parse(
    'https://ethmar-profile-images.fanyeol-23.workers.dev/v1/profile-image',
  );

  // Limit images to 5 MB.
  static const maxImageBytes = 5 * 1024 * 1024;
  static const _timeout = Duration(seconds: 60);
  static final _safeDiagnosticCode = RegExp(r'^[A-Z][A-Z0-9_]{1,63}$');

  final FirebaseAuth? _auth;
  final http.Client _client;
  final ProfileImageSessionProvider? _sessionProvider;
  final ProfileImageMetadataStore _metadataStore;

  // Watch the verified user's current profile image.
  Stream<UploadedProfileImage?> watchCurrentProfileImage() {
    final user = (_auth ?? FirebaseAuth.instance).currentUser;
    if (user == null || !user.emailVerified) {
      return Stream<UploadedProfileImage?>.value(null);
    }
    return _metadataStore.watch(user.uid);
  }

  // Validate and upload a selected profile image.
  Future<UploadedProfileImage> upload(XFile image) async {
    // Check the file size before reading it.
    final int length;
    try {
      length = await image.length();
    } catch (_) {
      throw const ProfileImageException(ProfileImageErrorCode.unreadableImage);
    }
    if (length <= 0) {
      throw const ProfileImageException(ProfileImageErrorCode.unsupportedImage);
    }
    if (length > maxImageBytes) {
      throw const ProfileImageException(ProfileImageErrorCode.imageTooLarge);
    }

    // Read the file and check its actual size.
    final Uint8List imageBytes;
    try {
      imageBytes = await image.readAsBytes();
    } catch (_) {
      throw const ProfileImageException(ProfileImageErrorCode.unreadableImage);
    }
    if (imageBytes.length > maxImageBytes) {
      throw const ProfileImageException(ProfileImageErrorCode.imageTooLarge);
    }

    // Identify the image format using its file bytes.
    final mediaType = _detectMediaType(imageBytes);
    if (mediaType == null) {
      throw const ProfileImageException(ProfileImageErrorCode.unsupportedImage);
    }

    // Get a verified Firebase session before uploading.
    final session = await _getVerifiedSession();
    final request = http.MultipartRequest('POST', _endpoint)
      ..headers['Authorization'] = 'Bearer ${session.idToken}'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          // Detect the file type from its bytes instead of trusting its name.
          filename: 'profile.${_extensionFor(mediaType)}',
          contentType: mediaType,
        ),
      );

    // Send the request and check the server response.
    final response = await _send(request);
    _throwForError(response);

    // Read the server response as JSON.
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

    // Verify the returned image belongs to this user.
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

    // Create a validated image record.
    final uploaded = UploadedProfileImage(
      publicId: publicId,
      // Build a trusted URL instead of storing Cloudinary's response.
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

    // Save image details in Firestore.
    await _saveMetadata(session.uid, uploaded);
    return uploaded;
  }

  // Delete the image through the Cloudflare Worker.
  Future<DeletedProfileImage> delete() async {
    // Get a verified Firebase session.
    final session = await _getVerifiedSession();
    final request = http.Request('DELETE', _endpoint)
      ..headers['Authorization'] = 'Bearer ${session.idToken}';

    // Send the request and check the server response.
    final response = await _send(request);
    _throwForError(response);

    // Read the server response as JSON.
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

    // Remove the image details from Firestore.
    await _deleteMetadata(session.uid);
    return result;
  }

  // Require a signed-in user with a verified email.
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
      // Never log or store the Firebase token.
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

  // Save metadata and handle Firestore errors.
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

  // Delete metadata and handle Firestore errors.
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

  // Send HTTP requests with a timeout.
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

  // Convert HTTP status codes into app errors.
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

  // Require a valid JSON object from the server.
  Map<String, dynamic> _decodeObject(http.Response response) {
    final decoded = _tryDecodeObject(response);
    if (decoded != null) return decoded;
    _throwInvalidSuccessResponse(response);
  }

  // Try to decode the server response safely.
  Map<String, dynamic>? _tryDecodeObject(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Never include the provider response in diagnostics.
    }
    return null;
  }

  // Read only safe error codes from the Worker.
  String? _workerErrorCode(http.Response response) {
    final body = _tryDecodeObject(response);
    final error = body?['error'];
    final code = error is Map<String, dynamic> ? error['code'] : null;
    if (code is String && _safeDiagnosticCode.hasMatch(code)) return code;
    return null;
  }

  // Reject invalid success responses.
  Never _throwInvalidSuccessResponse(http.Response response) {
    throw ProfileImageException(
      ProfileImageErrorCode.invalidResponse,
      statusCode: response.statusCode,
      diagnosticCode: 'INVALID_SUCCESS_RESPONSE',
    );
  }

  // Check that the image URL matches the trusted Cloudinary path.
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

  // Accept only PNG, JPEG, or WebP file signatures.
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

  // Choose the file extension from the detected format.
  String _extensionFor(MediaType mediaType) => switch (mediaType.subtype) {
    'jpeg' => 'jpg',
    'png' => 'png',
    'webp' => 'webp',
    _ => throw const ProfileImageException(
      ProfileImageErrorCode.unsupportedImage,
    ),
  };

  // Compare file bytes with an expected signature.
  bool _matchesAscii(Uint8List bytes, int offset, String value) {
    if (offset + value.length > bytes.length) return false;
    for (var index = 0; index < value.length; index += 1) {
      if (bytes[offset + index] != value.codeUnitAt(index)) return false;
    }
    return true;
  }

  // Read a little-endian integer from image bytes.
  int _uint32le(Uint8List bytes, int offset) =>
      bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);

  // Close the HTTP client when finished.
  void close() => _client.close();
}