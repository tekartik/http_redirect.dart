// Copyright (c) 2017, Alexandre Roux. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.
import 'package:http/http.dart';
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:tekartik_http_firestore_redirect/firestore_to_http_redirect.dart';
import 'package:tekartik_http_firestore_redirect/src/firestore/firestore_to_http_redirector.dart';
import 'package:tekartik_http_firestore_redirect/src/firestore/model/fs_models.dart';
import 'package:tekartik_http_firestore_redirect/src/firestore/paths.dart';
import 'package:tekartik_http_firestore_redirect/src/import.dart';
import 'package:test/test.dart';

import 'test_server.dart';

const testPath = 'test/redirect_service';

void main() {
  initFirestoreBuilders();
  var firestore = newFirestoreMemory();
  var httpFactory = httpFactoryMemory;
  run(httpFactory: httpFactory, firestore: firestore);
}

void run(
    {required Firestore firestore,
    required HttpFactory httpFactory,
    String path = 'test/tekartik_http'}) {
  final httpClientFactory = httpFactory.client;
  final httpServerFactory = httpFactory.server;

  group('firestore_to_http', () {
    late HttpServer server;
    late Client client;
    late RedirectorService redirectorService;
    setUpAll(() async {
      server = await serve(httpServerFactory, 0);
      client = httpClientFactory.newClient();
    });
    tearDownAll(() async {
      client.close();
      await server.close();
    });

    setUp(() async {
      //var redirector = Redirector('test', httpServerGetUri(server).toString());
      //redirectorService = RedirectorService(redirector, firestore: firestore, path: path, httpClientFactory: httpClientFactory);
    });

    test('httpServerGetUri', () async {
      var uri = httpServerGetUri(server);
      // expect(uri.toString().startsWith('http://_memory:'), isTrue);
      expect(uri.toString().startsWith('http://'), isTrue);
    });

    var path = testPath;
    var requestPath = url.join(path, 'request');

    test('no data', () async {
      var redirector = Redirector('test', httpServerGetUri(server).toString());
      redirectorService = RedirectorService(redirector,
          firestore: firestore,
          path: path,
          httpClientFactory: httpClientFactory);
      await redirectorService.start();
      var uri = httpServerGetUri(server);

      await deleteCollection(firestore, firestore.collection(requestPath));
      var id = AutoIdGenerator.autoId();
      var reqRef = requestRef(path, id);
      var respRef = responseRef(path, id);
      var fsRequest = reqRef.cv()..url.v = uri.toString();
      var requestMap = fsRequest.toMapWithServerTimestamp();
      await reqRef.setMap(firestore, requestMap);

      var completer = Completer();
      var subscription = respRef.onSnapshot(firestore).listen((response) {
        if (response.exists) {
          if (!completer.isCompleted) {
            var timestamp = response.timestamp.v!;
            var url = response.url.v!;

            var blob = response.body.v!; // as Blob;
            var headers = response.headers.v!;
            //expect(blob.data, isEmpty);
            expect(response.toMap(), {
              'statusCode': 200,
              'timestamp': timestamp,
              'url': url,
              'headers': headers,
              'body': blob,
            });

            completer.complete();
          }
        }
      });
      await completer.future;
      await subscription.cancel();

      redirectorService.stop();
    });

    test('full data', () async {
      var redirector = Redirector('test', httpServerGetUri(server).toString());
      redirectorService = RedirectorService(redirector,
          firestore: firestore,
          path: path,
          httpClientFactory: httpClientFactory);
      await redirectorService.start();
      var uri = httpServerGetUri(server);

      await deleteCollection(firestore, firestore.collection(requestPath));
      var id = AutoIdGenerator.autoId();
      var reqRef = requestRef(path, id);
      var respRef = responseRef(path, id);
      var fsRequest = reqRef.cv()
        ..url.v = uri.replace(queryParameters: {
          'body': 'test',
          'header1': 'value1',
          'statusCode': '203'
        }).toString()
        ..method.v = httpMethodPost
        ..headers.v = {'x-sample': 'value'};
      var requestMap = fsRequest.toMapWithServerTimestamp();
      await reqRef.setMap(firestore, requestMap);

      var completer = Completer();
      var subscription = respRef.onSnapshot(firestore).listen((response) {
        if (response.exists) {
          if (!completer.isCompleted) {
            var timestamp = response.timestamp.v!;
            var url = response.url.v!;

            var blob = response.body.v!; // as Blob;
            var headers = response.headers.v!;
            expect(headers['header1'], 'value1');
            expect(blob.data, [116, 101, 115, 116]);
            //expect(blob.data, isEmpty);
            expect(response.toMap(), {
              'statusCode': 203,
              'timestamp': timestamp,
              'url': url,
              'headers': headers,
              'body': blob,
            });

            completer.complete();
          }
        }
      });
      await completer.future;
      await subscription.cancel();

      redirectorService.stop();
    });
  });
}
