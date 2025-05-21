// Copyright (c) 2017, Alexandre Roux. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:tekartik_http_firestore_redirect/http_to_firestore.dart';
import 'package:tekartik_http_firestore_redirect/src/firestore/model/fs_models.dart';
import 'package:tekartik_http_firestore_redirect/src/firestore/paths.dart';
import 'package:tekartik_http_firestore_redirect/src/import.dart';
import 'package:test/test.dart';

import 'test_server.dart';

const testPath = 'test/redirect';

void main() {
  initFirestoreBuilders();
  var firestore = newFirestoreMemory();
  var httpFactory = httpFactoryMemory;
  run(httpFactory: httpFactory, firestore: firestore);
}

void run({
  required Firestore firestore,
  required HttpFactory httpFactory,
  String path = 'test/tekartik_http',
}) {
  final httpClientFactory = httpFactory.client;
  final httpServerFactory = httpFactory.server;

  group('http_to_firestore', () {
    late HttpServer server;
    late Client client;
    setUpAll(() async {
      server = await serve(httpServerFactory, 0);
      client = httpClientFactory.newClient();
    });
    tearDownAll(() async {
      client.close();
      await server.close();
    });
    test('httpServerGetUri', () async {
      var uri = httpServerGetUri(server);
      // expect(uri.toString().startsWith('http://_memory:'), isTrue);
      expect(uri.toString().startsWith('http://'), isTrue);
    });

    var path = testPath;
    var requestPath = url.join(path, 'request');

    test('no data', () async {
      var uri = httpServerGetUri(server);

      await deleteCollection(firestore, firestore.collection(requestPath));
      final fbHttpClientFactory = newHttpClientFactoryToFirestore(
        path: testPath,
        firestore: firestore,
      );
      //var response = await client.get('http://localhost:8181/?statusCode=200');
      // devPrint(uri);
      //var response = await client.get('${uri}/?statusCode=200');
      var client = fbHttpClientFactory.newClient();

      var completer = Completer<void>();
      var subscription = firestore.collection(requestPath).onSnapshot().listen((
        snapshot,
      ) {
        if (snapshot.docs.isNotEmpty) {
          if (!completer.isCompleted) {
            var rawRequest = snapshot.docs.first;
            var timestamp = rawRequest.data['timestamp'];
            var url = rawRequest.data['url'];
            var id = rawRequest.ref.id;

            var blob = rawRequest.data['body'] as Blob;
            expect(blob.data, isEmpty);
            expect(rawRequest.data, {
              'timestamp': timestamp,
              'url': url,
              'method': 'GET',
              'headers': <String, Object?>{},
              'body': blob,
            });

            /// Basic answer
            var ref = responseRef(path, id);
            var reponse = ref.cv()..statusCode.v = 200;
            var responseMap = reponse.toMapWithServerTimestamp();
            ref.setMap(firestore, responseMap);
            completer.complete();
          }
        }
      });
      // ignore: unused_local_variable
      var futureResponse = httpClientSend(client, httpMethodGet, uri);

      var response = await futureResponse;
      expect(response.bodyBytes, isEmpty);
      expect(response.statusCode, 200);
      expect(response.isSuccessful, isTrue);
      await subscription.cancel();
      await completer.future;
    });

    test('full data', () async {
      var uri = httpServerGetUri(server);

      await deleteCollection(firestore, firestore.collection(requestPath));
      final fbHttpClientFactory = newHttpClientFactoryToFirestore(
        path: testPath,
        firestore: firestore,
      );
      //var response = await client.get('http://localhost:8181/?statusCode=200');
      // devPrint(uri);
      //var response = await client.get('${uri}/?statusCode=200');
      var client = fbHttpClientFactory.newClient();

      var completer = Completer<void>();
      var subscription = firestore.collection(requestPath).onSnapshot().listen((
        snapshot,
      ) {
        if (snapshot.docs.isNotEmpty) {
          if (!completer.isCompleted) {
            var rawRequest = snapshot.docs.first;
            var timestamp = rawRequest.data['timestamp'];
            var url = rawRequest.data['url'];
            var id = rawRequest.ref.id;
            var headers = rawRequest.data['headers'] as Map;
            expect(headers['x-sample'], 'value');
            expect(rawRequest.data, {
              'timestamp': timestamp,
              'url': url,
              'method': 'GET',
              // 'headers': {'x-sample': 'value', 'content-type': 'text/plain; charset=utf-8'},
              'headers': headers,
              'body': Blob.fromList([116, 101, 115, 116]),
            });

            /// Basic answer
            var ref = responseRef(path, id);

            var reponse =
                ref.cv()
                  ..statusCode.v = 200
                  ..body.v = Blob.fromList([1, 2, 3])
                  ..headers.v = {'x-sample': 'from firestore'};
            var responseMap = reponse.toMapWithServerTimestamp();
            ref.setMap(firestore, responseMap);
            completer.complete();
          }
        }
      });
      // ignore: unused_local_variable
      var futureResponse = httpClientSend(
        client,
        httpMethodGet,
        uri,
        headers: {'x-sample': 'value'},
        body: 'test',
      );

      var response = await futureResponse;
      expect(response.bodyBytes, [1, 2, 3]);
      var headers = response.headers;
      expect(headers['x-sample'], 'from firestore');
      expect(response.headers, headers);
      expect(response.statusCode, 200);
      expect(response.isSuccessful, isTrue);
      await subscription.cancel();
      await completer.future;
    });
  });
}
