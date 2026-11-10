import 'package:http/http.dart' as http;
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:tekartik_http_firestore_redirect/firestore_to_http_redirect.dart';
import 'package:tekartik_http_firestore_redirect/http_to_firestore.dart';
import 'package:tekartik_http_firestore_redirect/src/import.dart';
import 'package:test/test.dart';

/// What the target received: method, content type and body bytes.
const _echoHeader = 'x-echo';

void main() {
  var firestore = newFirestoreMemory();
  var path = 'http_client/tunnel';
  late HttpServer target;
  late Uri targetUri;
  late RedirectorService service;

  setUpAll(() async {
    target = await httpFactoryMemory.server.bind(localhost, 0);
    target.listen((request) async {
      var bytes = await request.getBodyBytes();
      request.response.headers.set(
        _echoHeader,
        '${request.method}|${request.headers.value('content-type')}|$bytes',
      );
      request.response.write('ok');
      await request.response.close();
    });
    targetUri = httpServerGetUri(target);
    service = RedirectorService(
      Redirector('test', targetUri.toString()),
      firestore: firestore,
      path: path,
      httpClientFactory: httpFactoryMemory.client,
    );
    await service.start();
  });
  tearDownAll(() async {
    service.stop();
    await target.close();
  });

  http.Client newFirestoreClient() {
    var client = newHttpClientFactoryToFirestore(
      firestore: firestore,
      path: path,
    ).newClient();
    addTearDown(client.close);
    return client;
  }

  http.Client newDirectClient() {
    var client = httpFactoryMemory.client.newClient();
    addTearDown(client.close);
    return client;
  }

  /// The same call through the tunnel gives what it gives directly.
  Future<void> expectSameAsDirect(
    Future<Object?> Function(http.Client client) call,
  ) async {
    var direct = await call(newDirectClient());
    expect(await call(newFirestoreClient()), direct);
  }

  group('firestore http client', () {
    test('read, readBytes', () async {
      var client = newFirestoreClient();
      expect(await client.read(targetUri), 'ok');
      expect(await client.readBytes(targetUri), utf8.encode('ok'));
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('head', () async {
      await expectSameAsDirect(
        (client) async => (await client.head(targetUri)).statusCode,
      );
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('post a map: form fields', () async {
      await expectSameAsDirect(
        (client) async => (await client.post(
          targetUri,
          body: {'a': 'b'},
        )).headers[_echoHeader],
      );
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('post a string with an encoding', () async {
      await expectSameAsDirect(
        (client) async => (await client.post(
          targetUri,
          body: 'é',
          encoding: latin1,
        )).headers[_echoHeader],
      );
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('delete, put, patch with a body', () async {
      await expectSameAsDirect(
        (client) async =>
            (await client.delete(targetUri, body: 'x')).headers[_echoHeader],
      );
      await expectSameAsDirect(
        (client) async =>
            (await client.put(targetUri, body: 'x')).headers[_echoHeader],
      );
      await expectSameAsDirect(
        (client) async =>
            (await client.patch(targetUri, body: 'x')).headers[_echoHeader],
      );
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('streamed and multipart requests', () async {
      await expectSameAsDirect((client) async {
        var request = http.StreamedRequest(httpMethodPost, targetUri);
        request.sink
          ..add([1, 2])
          ..add([3]);
        unawaited(request.sink.close());
        var response = await client.send(request);
        return response.headers[_echoHeader];
      });
      var request = http.MultipartRequest(httpMethodPost, targetUri)
        ..fields['a'] = 'b';
      var response = await http.Response.fromStream(
        await newFirestoreClient().send(request),
      );
      // The boundary is random: check the content type and the field.
      var echo = response.headers[_echoHeader]!.split('|');
      expect(echo[0], httpMethodPost);
      expect(echo[1], startsWith('multipart/form-data; boundary='));
      expect(echo[2], isNot('[]'));
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('the response document is deleted once read', () async {
      var client = newFirestoreClient();
      for (var i = 0; i < 2; i++) {
        expect(
          (await httpClientSend(client, httpMethodGet, targetUri)).statusCode,
          200,
        );
      }
      var responses = firestore.collection(url.join(path, 'response'));
      // The delete is not awaited by the call: wait for it, bounded.
      for (var i = 0; i < 50; i++) {
        if ((await responses.get()).docs.isEmpty) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect((await responses.get()).docs, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 10)));
  });
}
