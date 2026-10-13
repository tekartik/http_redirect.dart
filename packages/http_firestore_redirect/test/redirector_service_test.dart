import 'package:http/http.dart' as http;
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:tekartik_http_firestore_redirect/http_to_firestore.dart';
import 'package:tekartik_http_firestore_redirect/src/firestore/firestore_to_http_redirector.dart';
import 'package:tekartik_http_firestore_redirect/src/import.dart';
import 'package:test/test.dart';

/// Count the clients created and closed.
class _CountingClientFactory implements HttpClientFactory {
  var created = 0;
  var closed = 0;

  @override
  Client newClient() {
    created++;
    return _CountingClient(this, httpFactoryMemory.client.newClient());
  }
}

class _CountingClient extends http.BaseClient {
  final _CountingClientFactory factory;
  final Client inner;

  _CountingClient(this.factory, this.inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      inner.send(request);

  @override
  void close() {
    factory.closed++;
    inner.close();
  }
}

/// Complete [listening] on the nth `listening` info.
class _ListeningListener implements Listener {
  final int count;
  var _count = 0;
  final listening = Completer<void>();

  _ListeningListener(this.count);

  @override
  void info(String message, Object? data) {
    if (message == 'listening' && ++_count == count) {
      listening.complete();
    }
  }
}

void main() {
  var firestore = newFirestoreMemory();
  var serverFactory = httpFactoryMemory.server;

  group('redirector_service', () {
    late HttpServer target;
    late Uri targetUri;

    setUpAll(() async {
      // Echo the method and the body
      target = await serverFactory.bind(localhost, 0);
      target.listen((request) async {
        var body = utf8.decode(await request.getBodyBytes());
        request.response.write('${request.method} <$body>');
        await request.response.close();
      });
      targetUri = httpServerGetUri(target);
    });
    tearDownAll(() async {
      await target.close();
    });

    /// Start a redirector service on [path] (a document path), stopped on
    /// tear down.
    Future<RedirectorService> startService(
      String path, {
      String? baseUrl,
      HttpClientFactory? httpClientFactory,
      Listener? listener,
    }) async {
      var service = RedirectorService(
        Redirector('test', baseUrl),
        firestore: firestore,
        path: path,
        httpClientFactory: httpClientFactory ?? httpFactoryMemory.client,
        listener: listener,
      );
      await service.start();
      addTearDown(service.stop);
      return service;
    }

    Client newClient(String path) {
      var client = newHttpClientFactoryToFirestore(
        firestore: firestore,
        path: path,
      ).newClient();
      addTearDown(client.close);
      return client;
    }

    test('binary body', () async {
      var path = 'redirector_service/body';
      await startService(path, baseUrl: targetUri.toString());
      var client = newClient(path);
      // Sent as bytes (Blob)
      var response = await httpClientSend(
        client,
        httpMethodPost,
        Uri.parse('p'),
        body: 'hello',
      );
      expect(response.statusCode, 200);
      expect(response.body, 'POST <hello>');
      // Sent as a string
      expect(
        (await client.post(Uri.parse('p'), body: 'hello')).body,
        'POST <hello>',
      );
    });

    test('unreachable url', () async {
      var deadServer = await serverFactory.bind(localhost, 0);
      var deadUri = httpServerGetUri(deadServer);
      await deadServer.close();

      var path = 'redirector_service/unreachable';
      await startService(path, baseUrl: deadUri.toString());
      var client = newClient(path);
      await expectLater(
        httpClientSend(client, httpMethodGet, Uri.parse('p')),
        throwsA(isA<http.ClientException>()),
      );
    });

    test('one client, closed on stop', () async {
      var path = 'redirector_service/client';
      var factory = _CountingClientFactory();
      var service = await startService(
        path,
        baseUrl: targetUri.toString(),
        httpClientFactory: factory,
      );
      var client = newClient(path);
      for (var i = 0; i < 2; i++) {
        var response = await httpClientSend(
          client,
          httpMethodGet,
          Uri.parse('p'),
        );
        expect(response.body, 'GET <>');
      }
      expect(factory.created, 1);
      service.stop();
      expect(factory.closed, 1);
    });

    test('parameter doc changes then stop', () async {
      var path = 'redirector_service/param';
      var paramRef = firestore.doc(path);
      await paramRef.set({'baseUrl': targetUri.toString()});
      var listener = _ListeningListener(2);
      var service = await startService(path, listener: listener);
      var client = newClient(path);
      expect(
        (await httpClientSend(client, httpMethodGet, Uri.parse('p'))).body,
        'GET <>',
      );
      // Second parameter change, listen again
      await paramRef.set({'baseUrl': targetUri.toString(), 'v': 2});
      await listener.listening.future.timeout(const Duration(seconds: 5));
      expect(
        (await httpClientSend(client, httpMethodGet, Uri.parse('p'))).body,
        'GET <>',
      );

      service.stop();
      // No more answer
      await expectLater(
        httpClientSend(
          client,
          httpMethodGet,
          Uri.parse('p'),
        ).timeout(const Duration(milliseconds: 500)),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}
