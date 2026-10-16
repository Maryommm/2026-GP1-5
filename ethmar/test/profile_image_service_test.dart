import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ethmar/services/profile_image_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';

const _uid = 'firebase-user-123';
const _testToken = 'test-id-token';
const _publicId = 'ethmar/profile-images/$_uid/profile';

final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDw'
  'AEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

final _jpegBytes = base64Decode(
  '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAMCAgMCAgMDAwMEAwMEBQgFBQQEBQoHBwYI'
  'DAoMDAsKCwsNDhIQDQ4RDgsLEBYQERMUFRUVDA8XGBYUGBIUFRT/2wBDAQMEBAUEBQkF'
  'BQkUDQsNFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQU'
  'FBQUFBT/wAARCAABAAEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBg'
  'cICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0'
  'KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZW'
  'ZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxM'
  'XGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQ'
  'AAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQ'
  'dhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSE'
  'lKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqK'
  'mqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADA'
  'MBAAIRAxEAPwD50ooor8MP9Uz/2Q==',
);

final _webpBytes = base64Decode(
  'UklGRiIAAABXRUJQVlA4IBYAAAAwAQCdASoBAAEADsD+JaQAA3AAAAAA',
);

Map<String, Object> _uploadResponse(int version) => {
  'image': {
    'publicId': _publicId,
    'secureUrl':
        'https://res.cloudinary.com/k7otdsln/image/upload/'
        'v$version/$_publicId.webp',
    'version': version,
    'format': 'webp',
    'width': 1,
    'height': 1,
    'bytes': 42,
  },
};

XFile _pngFile() =>
    XFile.fromData(_pngBytes, mimeType: 'image/png', name: 'picked.png');

ProfileImageService _service(http.Client client, _FakeMetadataStore store) =>
    ProfileImageService(
      client: client,
      metadataStore: store,
      sessionProvider: () async =>
          const ProfileImageSession(uid: _uid, idToken: _testToken),
    );

Matcher _profileError(ProfileImageErrorCode code) =>
    isA<ProfileImageException>().having((error) => error.code, 'code', code);

void main() {
  group('ProfileImageService upload', () {
    test(
      'sends an authenticated multipart request and stores safe metadata',
      () async {
        final store = _FakeMetadataStore();
        final client = MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.toString(),
            'https://ethmar-profile-images.fanyeol-23.workers.dev/v1/profile-image',
          );
          expect(request.headers['authorization'], 'Bearer $_testToken');
          expect(
            request.headers['content-type'],
            startsWith('multipart/form-data;'),
          );

          final multipartBody = latin1.decode(request.bodyBytes);
          expect(multipartBody, contains('name="file"'));
          expect(multipartBody, contains('filename="profile.png"'));
          expect(multipartBody, contains('content-type: image/png'));
          expect(multipartBody, isNot(contains('name="uid"')));
          expect(multipartBody, isNot(contains('name="folder"')));
          expect(multipartBody, isNot(contains('name="public_id"')));

          return http.Response(jsonEncode(_uploadResponse(11)), 200);
        });
        final service = _service(client, store);
        addTearDown(service.close);

        final image = await service.upload(_pngFile());

        expect(image.publicId, _publicId);
        expect(image.version, 11);
        expect(store.savedUid, _uid);
        expect(store.savedImage, same(image));
        expect(
          image.secureUrl,
          'https://res.cloudinary.com/k7otdsln/image/upload/'
          'v11/$_publicId.webp',
        );
      },
    );

    test(
      'replacement keeps the fixed public ID and saves the new version',
      () async {
        final store = _FakeMetadataStore();
        var version = 20;
        final client = MockClient(
          (_) async =>
              http.Response(jsonEncode(_uploadResponse(version++)), 200),
        );
        final service = _service(client, store);
        addTearDown(service.close);

        final first = await service.upload(_pngFile());
        final second = await service.upload(_pngFile());

        expect(first.publicId, second.publicId);
        expect(first.version, 20);
        expect(second.version, 21);
        expect(store.savedImage?.version, 21);
        expect(store.saveCount, 2);
      },
    );

    test(
      'accepts a trusted Cloudinary URL with transformation segments',
      () async {
        final store = _FakeMetadataStore();
        final response = _uploadResponse(14);
        final image = response['image']! as Map<String, Object>;
        image['secureUrl'] =
            'https://res.cloudinary.com/k7otdsln/image/upload/'
            'c_limit,w_4096/v14/$_publicId.webp';
        final service = _service(
          MockClient((_) async => http.Response(jsonEncode(response), 200)),
          store,
        );
        addTearDown(service.close);

        final uploaded = await service.upload(_pngFile());

        expect(
          uploaded.secureUrl,
          'https://res.cloudinary.com/k7otdsln/image/upload/'
          'v14/$_publicId.webp',
        );
        expect(store.saveCount, 1);
      },
    );

    test(
      'uses JPEG bytes when an Android cache file is misleadingly named PNG',
      () async {
        final store = _FakeMetadataStore();
        final client = MockClient((request) async {
          final multipartBody = latin1.decode(request.bodyBytes);
          expect(multipartBody, contains('filename="profile.jpg"'));
          expect(multipartBody, contains('content-type: image/jpeg'));
          return http.Response(jsonEncode(_uploadResponse(12)), 200);
        });
        final service = _service(client, store);
        addTearDown(service.close);

        await service.upload(
          XFile.fromData(
            _jpegBytes,
            mimeType: 'image/png',
            name: 'scaled_screenshot.png',
          ),
        );

        expect(store.saveCount, 1);
      },
    );

    test(
      'detects WebP bytes without relying on filename or picker MIME type',
      () async {
        final store = _FakeMetadataStore();
        final client = MockClient((request) async {
          final multipartBody = latin1.decode(request.bodyBytes);
          expect(multipartBody, contains('filename="profile.webp"'));
          expect(multipartBody, contains('content-type: image/webp'));
          return http.Response(jsonEncode(_uploadResponse(13)), 200);
        });
        final service = _service(client, store);
        addTearDown(service.close);

        await service.upload(
          XFile.fromData(
            _webpBytes,
            mimeType: 'application/octet-stream',
            name: 'image_picker_cache',
          ),
        );

        expect(store.saveCount, 1);
      },
    );

    test('rejects unsupported content before making a request', () async {
      final store = _FakeMetadataStore();
      var requests = 0;
      final service = _service(
        MockClient((_) async {
          requests += 1;
          return http.Response('', 500);
        }),
        store,
      );
      addTearDown(service.close);

      await expectLater(
        service.upload(XFile.fromData(Uint8List.fromList([1, 2, 3]))),
        throwsA(_profileError(ProfileImageErrorCode.unsupportedImage)),
      );
      expect(requests, 0);
      expect(store.saveCount, 0);
    });

    test('rejects files over 5 MB before making a request', () async {
      final store = _FakeMetadataStore();
      var requests = 0;
      final service = _service(
        MockClient((_) async {
          requests += 1;
          return http.Response('', 500);
        }),
        store,
      );
      addTearDown(service.close);

      await expectLater(
        service.upload(
          XFile.fromData(Uint8List(ProfileImageService.maxImageBytes + 1)),
        ),
        throwsA(_profileError(ProfileImageErrorCode.imageTooLarge)),
      );
      expect(requests, 0);
      expect(store.saveCount, 0);
    });

    test('rejects a response for a different UID', () async {
      final store = _FakeMetadataStore();
      final response = _uploadResponse(8);
      final image = response['image']! as Map<String, Object>;
      image['publicId'] = 'ethmar/profile-images/another-user/profile';
      image['secureUrl'] =
          'https://res.cloudinary.com/k7otdsln/image/upload/'
          'v8/ethmar/profile-images/another-user/profile.webp';
      final service = _service(
        MockClient((_) async => http.Response(jsonEncode(response), 200)),
        store,
      );
      addTearDown(service.close);

      await expectLater(
        service.upload(_pngFile()),
        throwsA(_profileError(ProfileImageErrorCode.invalidResponse)),
      );
      expect(store.saveCount, 0);
    });

    test('rejects the previous lookalike Cloudinary cloud name', () async {
      final store = _FakeMetadataStore();
      final response = _uploadResponse(8);
      final image = response['image']! as Map<String, Object>;
      image['secureUrl'] =
          'https://res.cloudinary.com/k7otds1n/image/upload/'
          'v8/$_publicId.webp';
      final service = _service(
        MockClient((_) async => http.Response(jsonEncode(response), 200)),
        store,
      );
      addTearDown(service.close);

      await expectLater(
        service.upload(_pngFile()),
        throwsA(_profileError(ProfileImageErrorCode.invalidResponse)),
      );
      expect(store.saveCount, 0);
    });

    test(
      'rejects a success URL outside the expected Cloudinary asset',
      () async {
        final store = _FakeMetadataStore();
        final response = _uploadResponse(8);
        final image = response['image']! as Map<String, Object>;
        image['secureUrl'] = 'https://example.com/v8/$_publicId.webp';
        final service = _service(
          MockClient((_) async => http.Response(jsonEncode(response), 200)),
          store,
        );
        addTearDown(service.close);

        await expectLater(
          service.upload(_pngFile()),
          throwsA(
            isA<ProfileImageException>()
                .having((error) => error.statusCode, 'statusCode', 200)
                .having(
                  (error) => error.diagnosticCode,
                  'diagnosticCode',
                  'INVALID_SUCCESS_RESPONSE',
                ),
          ),
        );
        expect(store.saveCount, 0);
      },
    );

    test('preserves only the Worker HTTP status and safe error code', () async {
      final store = _FakeMetadataStore();
      final service = _service(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {
                'code': 'IMAGE_SERVICE_UNAVAILABLE',
                'message': 'Internal upstream details must stay hidden',
              },
            }),
            502,
          ),
        ),
        store,
      );
      addTearDown(service.close);

      await expectLater(
        service.upload(_pngFile()),
        throwsA(
          isA<ProfileImageException>()
              .having(
                (error) => error.code,
                'code',
                ProfileImageErrorCode.server,
              )
              .having((error) => error.statusCode, 'statusCode', 502)
              .having(
                (error) => error.diagnosticCode,
                'diagnosticCode',
                'IMAGE_SERVICE_UNAVAILABLE',
              )
              .having(
                (error) => error.safeDiagnostic,
                'safeDiagnostic',
                'HTTP 502 · IMAGE_SERVICE_UNAVAILABLE',
              ),
        ),
      );
      expect(store.saveCount, 0);
    });

    test(
      'does not expose an untrusted error code or response message',
      () async {
        final store = _FakeMetadataStore();
        final service = _service(
          MockClient(
            (_) async => http.Response(
              jsonEncode({
                'error': {
                  'code': 'token=secret-value',
                  'message': 'firebase-token-or-cloudinary-secret',
                },
              }),
              500,
            ),
          ),
          store,
        );
        addTearDown(service.close);

        await expectLater(
          service.upload(_pngFile()),
          throwsA(
            isA<ProfileImageException>()
                .having(
                  (error) => error.diagnosticCode,
                  'diagnosticCode',
                  isNull,
                )
                .having(
                  (error) => error.safeDiagnostic,
                  'safeDiagnostic',
                  'HTTP 500',
                ),
          ),
        );
        expect(store.saveCount, 0);
      },
    );

    for (final scenario in <(int, ProfileImageErrorCode, Map<String, String>)>[
      (401, ProfileImageErrorCode.unauthorized, const {}),
      (413, ProfileImageErrorCode.imageTooLarge, const {}),
      (429, ProfileImageErrorCode.rateLimited, const {'retry-after': '60'}),
      (500, ProfileImageErrorCode.server, const {}),
    ]) {
      test('maps HTTP ${scenario.$1} without writing metadata', () async {
        final store = _FakeMetadataStore();
        final service = _service(
          MockClient(
            (_) async => http.Response('{}', scenario.$1, headers: scenario.$3),
          ),
          store,
        );
        addTearDown(service.close);

        await expectLater(
          service.upload(_pngFile()),
          throwsA(_profileError(scenario.$2)),
        );
        expect(store.saveCount, 0);
      });
    }
  });

  group('ProfileImageService delete', () {
    test('maps Firebase token refresh network errors to network', () async {
      final store = _FakeMetadataStore();
      var requests = 0;
      final service = ProfileImageService(
        client: MockClient((_) async {
          requests += 1;
          return http.Response('', 500);
        }),
        metadataStore: store,
        sessionProvider: () async =>
            throw FirebaseAuthException(code: 'network-request-failed'),
      );
      addTearDown(service.close);

      await expectLater(
        service.delete(),
        throwsA(_profileError(ProfileImageErrorCode.network)),
      );
      expect(requests, 0);
      expect(store.deletedUid, isNull);
    });

    test('deletes Cloudinary first and then removes metadata', () async {
      final store = _FakeMetadataStore();
      final client = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.headers['authorization'], 'Bearer $_testToken');
        expect(request.bodyBytes, isEmpty);
        expect(store.deletedUid, isNull);
        return http.Response('{"deleted":true,"status":"deleted"}', 200);
      });
      final service = _service(client, store);
      addTearDown(service.close);

      final result = await service.delete();

      expect(result.deleted, isTrue);
      expect(result.notFound, isFalse);
      expect(store.deletedUid, _uid);
    });

    test('clears stale metadata when Cloudinary reports not found', () async {
      final store = _FakeMetadataStore();
      final service = _service(
        MockClient(
          (_) async =>
              http.Response('{"deleted":false,"status":"not_found"}', 200),
        ),
        store,
      );
      addTearDown(service.close);

      final result = await service.delete();

      expect(result.notFound, isTrue);
      expect(store.deletedUid, _uid);
    });
  });

  group('stored profile image metadata', () {
    test('derives a versioned Cloudinary URL from the fixed public ID', () {
      final image = UploadedProfileImage.fromFirestore(_uid, {
        'publicId': _publicId,
        'version': 33,
        'format': 'webp',
        'width': 200,
        'height': 180,
        'bytes': 12345,
        'updatedAt': Timestamp.fromMillisecondsSinceEpoch(1),
      });

      expect(image, isNotNull);
      expect(
        image!.secureUrl,
        'https://res.cloudinary.com/k7otdsln/image/upload/'
        'v33/$_publicId.webp',
      );
    });

    test('ignores malformed or extended metadata', () {
      expect(
        UploadedProfileImage.fromFirestore(_uid, {
          'publicId': _publicId,
          'version': 1,
          'format': 'webp',
          'width': 1,
          'height': 1,
          'bytes': 1,
          'updatedAt': Timestamp.fromMillisecondsSinceEpoch(1),
          'secureUrl': 'https://example.com/untrusted.webp',
        }),
        isNull,
      );
    });
  });
}

class _FakeMetadataStore implements ProfileImageMetadataStore {
  String? savedUid;
  UploadedProfileImage? savedImage;
  String? deletedUid;
  int saveCount = 0;

  @override
  Future<void> save(String uid, UploadedProfileImage image) async {
    savedUid = uid;
    savedImage = image;
    saveCount += 1;
  }

  @override
  Future<void> delete(String uid) async {
    deletedUid = uid;
  }

  @override
  Stream<UploadedProfileImage?> watch(String uid) => const Stream.empty();
}
