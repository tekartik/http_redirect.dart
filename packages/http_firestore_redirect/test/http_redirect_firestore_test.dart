import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:tekartik_http/http_memory.dart';
import 'package:tekartik_http_firestore_redirect/firestore_to_http_redirect.dart';
import 'package:tekartik_http_firestore_redirect/http_to_firestore.dart';
import 'package:tekartik_http_firestore_redirect/src/firestore/firestore_to_http_redirector.dart';
import 'package:tekartik_http_redirect_test/http_redirect_test.dart';
import 'package:test/test.dart';

void main() {
  var firestore = newFirestoreMemory();
  var path = 'test/http_redirect_firestore';
  group('firestore', () {
    var redirector = RedirectorService(
        Redirector('test', 'http://localhost:8501'),
        firestore: firestore,
        httpClientFactory: httpFactoryMemory.client,
        path: path);
    setUpAll(() async {
      await redirector.start();
    });
    tearDownAll(() async {
      redirector.stop();
    });
    runHttpRedirectTest(
        httpFactory: httpFactoryMemory,
        outboundHttpClientFactory:
            newHttpClientFactoryToFirestore(firestore: firestore, path: path));
  });
}
