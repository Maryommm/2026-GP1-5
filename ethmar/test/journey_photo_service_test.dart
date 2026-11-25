import 'dart:convert';

import 'package:ethmar/services/growth_photo_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';

const _uid = 'user-1';
const _publicId = 'ethmar/plant-growth/$_uid/plant-1/entry-1';

final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDw'
  'AEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

XFile _png() => XFile.fromData(_pngBytes, name: 'picked.png');

Map<String, Object> _saved({String publicId = _publicId}) => {
  'image': {
    'publicId': publicId,
    'secureUrl':
        'https://res.cloudinary.com/k7otdsln/image/upload/v7/$publicId.webp',
    'version': 7,
    'format': 'webp',
    'width': 1600,
    'height': 1200,
    'bytes': 180000,
  },
};

GrowthPhotoService _service(MockClient client) => GrowthPhotoService(
  client: client,
  session: () async => (uid: _uid, idToken: 'token'),
);

void main() {
  test(
    'uploads with the plant and entry, and returns the saved photo',
    () async {
      late http.Request sent;
      final service = _service(
        MockClient((request) async {
          sent = request;
          return http.Response(jsonEncode(_saved()), 200);
        }),
      );

      final photo = await service.upload(
        _png(),
        plantId: 'plant-1',
        entryId: 'entry-1',
      );

      expect(sent.method, 'POST');
      expect(sent.url.path, '/v1/plant-growth');
      expect(sent.headers['Authorization'], 'Bearer token');
      // The picture's bytes aren't text, so read the form byte for byte.
      final body = latin1.decode(sent.bodyBytes);
      expect(body, contains('name="plantId"\r\n\r\nplant-1'));
      expect(body, contains('name="entryId"\r\n\r\nentry-1'));
      expect(body, contains('content-type: image/png'));
      expect(photo.publicId, _publicId);
      expect(photo.version, 7);
      expect(
        photo.url,
        'https://res.cloudinary.com/k7otdsln/image/upload/v7/$_publicId.webp',
      );
    },
  );

  test('rejects a photo saved anywhere but this entry', () async {
    final service = _service(
      MockClient(
        (_) async => http.Response(
          jsonEncode(_saved(publicId: 'ethmar/plant-growth/other/p/e')),
          200,
        ),
      ),
    );

    await expectLater(
      service.upload(_png(), plantId: 'plant-1', entryId: 'entry-1'),
      throwsA(
        isA<GrowthPhotoException>().having(
          (e) => e.error,
          'error',
          GrowthPhotoError.server,
        ),
      ),
    );
  });

  test('refuses a file that is not a picture, without sending it', () async {
    var calls = 0;
    final service = _service(
      MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      service.upload(
        XFile.fromData(utf8.encode('not an image'), name: 'a.txt'),
        plantId: 'plant-1',
        entryId: 'entry-1',
      ),
      throwsA(
        isA<GrowthPhotoException>().having(
          (e) => e.error,
          'error',
          GrowthPhotoError.unsupportedImage,
        ),
      ),
    );
    expect(calls, 0);
  });

  test('turns Worker errors into reasons the screen can explain', () async {
    for (final (status, error) in [
      (401, GrowthPhotoError.notSignedIn),
      (403, GrowthPhotoError.emailNotVerified),
      (413, GrowthPhotoError.tooLarge),
      (429, GrowthPhotoError.rateLimited),
      (502, GrowthPhotoError.server),
    ]) {
      final service = _service(
        MockClient((_) async => http.Response('{"error":{}}', status)),
      );
      await expectLater(
        service.upload(_png(), plantId: 'plant-1', entryId: 'entry-1'),
        throwsA(
          isA<GrowthPhotoException>().having((e) => e.error, '$status', error),
        ),
      );
    }
  });

  test('a lost connection is a network error', () async {
    final service = _service(
      MockClient((_) async => throw http.ClientException('offline')),
    );

    await expectLater(
      service.upload(_png(), plantId: 'plant-1', entryId: 'entry-1'),
      throwsA(
        isA<GrowthPhotoException>().having(
          (e) => e.error,
          'error',
          GrowthPhotoError.network,
        ),
      ),
    );
  });

  test('deletes one entry\'s photo, or all of a plant\'s', () async {
    final sent = <Uri>[];
    final service = _service(
      MockClient((request) async {
        expect(request.method, 'DELETE');
        sent.add(request.url);
        return http.Response('{"deleted":true,"status":"deleted"}', 200);
      }),
    );

    await service.deleteEntryPhoto(plantId: 'plant-1', entryId: 'entry-1');
    await service.deletePlantPhotos('plant-1');

    expect(sent[0].queryParameters, {
      'plantId': 'plant-1',
      'entryId': 'entry-1',
    });
    expect(sent[1].queryParameters, {'plantId': 'plant-1'});
  });
}
