---
name: tekartik-http-firestore-redirect-setup
description: >-
  Use when tunnelling http calls through firestore with
  tekartik_http_firestore_redirect: newHttpClientFactoryToFirestore(path,
  firestore) on the caller side, RedirectorService and Redirector on the
  network side, the `<path>/request/<id>` and `<path>/response/<id>` document
  layout (url, method, headers, body Blob, statusCode, error, timestamp), who
  deletes which document, timeouts and errors of a call, and the limits
  (1 MiB documents, data in clear).
---

# Http over firestore (tekartik_http_firestore_redirect)

This package replaces the network between a client and a server by a firestore
collection: the caller writes a request document, a `RedirectorService` running
where the network is reachable performs the real http call and writes the
response document back. The caller sees a normal `package:http` `Client`, so
existing code (an api client built on `tekartik_http`) keeps working.

## Guidelines

* Dependency (git, not on pub.dev):
  ```yaml
  dependencies:
    tekartik_http_firestore_redirect:
      git:
        url: https://github.com/tekartik/http_redirect.dart
        path: packages/http_firestore_redirect
      version: '>=0.0.1'
  ```
  It pulls `tekartik_firebase_firestore` (the `Firestore`, `Blob` types),
  `tekartik_firebase_firestore_sembast` (memory/local firestore) and
  `tekartik_app_http`; declare the ones you import explicitly.
* Two public libraries, one per side of the tunnel:
  * caller: `package:tekartik_http_firestore_redirect/http_to_firestore.dart`
    exposes `newHttpClientFactoryToFirestore({required String path, required
    Firestore firestore})`, which returns a `tekartik_http` `HttpClientFactory`
    (one per app is enough).
  * network side: `package:tekartik_http_firestore_redirect/firestore_to_http_redirect.dart`
    exposes `RedirectorService` and `Redirector`.
  Both sides must use the same `path` (a firestore document path such as
  `redirect/my_tunnel`) and the same firestore instance/project.
* Caller: `factory.newClient()` returns an `http.BaseClient`: every method
  works (`get`, `post`, `read`, `readBytes`, `head`, `send` of an
  `http.Request`, `StreamedRequest` or `MultipartRequest`) and goes through
  `send`, so a map body is form encoded and `encoding` is honoured as with
  any client. The body is read whole (no streaming). `close()` is a no-op.
* Each call writes `<path>/request/<autoId>` with `url`, `method`, `headers`
  (map, the content type included), `body` (a `Blob`) and `timestamp`
  (server timestamp), then listens on `<path>/response/<sameId>` and completes
  when that document appears, then deletes it (best effort, not awaited: the
  firestore rules must let the caller delete its responses, or they stay).
  It gives up after 30 seconds with a `TimeoutException`, so the service must
  be running (and the firestore `onSnapshot` streams must work) for any call
  to succeed; the request document of a timed out call stays, and a service
  started later still performs it.
* Response document fields: `statusCode` (int), `body` (`Blob`), `headers`
  (map), `url`, `timestamp`, and `error` (`{message: ...}`) when the outgoing
  call threw. A response with no `statusCode` makes the caller throw an
  `http.ClientException` with `error.message` (or "no response from the
  redirector").
* Service: `RedirectorService(Redirector(name, baseUrl), firestore: ...,
  path: ..., httpClientFactory: ...)` then `await start()` and `stop()` when
  done. `name` is informational. When `baseUrl` is a url, every request url is
  joined to it (an absolute request url wins); when `baseUrl` is null, the
  service watches the document at `path` and takes its `baseUrl` string field,
  so the target can be changed at runtime without restarting.
* `start()` listens to the whole `<path>/request` collection, performs the
  call (any method, with its headers and body; a string or map body written
  by an older client is still accepted) with the given `httpClientFactory`
  (use `httpFactoryIo.client` for real network, `httpFactoryMemory.client` in
  tests), writes the response document and then **deletes the request
  document**. It keeps the last request ids in memory to avoid answering
  twice. Run exactly one service per `path`.
* The `listener:` parameter of `RedirectorService` takes the `Listener`
  interface which the public library does not export: leave it null unless you
  import `src/firestore/firestore_to_http_redirector.dart`.
* Everything (url, headers, body) is stored in clear in firestore: never let a
  client that must not see other calls read the request/response collections,
  and prefer short lived tokens in forwarded headers.
* Firestore limits a document to 1 MiB: a request or response body close to
  that size cannot go through (a response write failing that way is not
  caught by the service today).
* The cv models (`FsRequest`, `FsResponse`, `CvResponseError`),
  `initFirestoreBuilders()` and the path helpers (`requestRef`, `responseRef`,
  `requestsRef`, `responsesRef`) are `lib/src/` only; the package's own tests
  import them through `package:tekartik_http_firestore_redirect/src/...`. Call
  `initFirestoreBuilders()` before using them.
* Testing: `newFirestoreMemory()` from
  `package:tekartik_firebase_firestore_sembast/firestore_sembast.dart` plus
  `httpFactoryMemory` runs the full tunnel in process. The shared suite
  `runHttpRedirectTest(httpFactory:, outboundHttpClientFactory:)` of
  `tekartik_http_redirect_test` accepts the firestore client factory directly.

## Examples

### Service side: perform the calls for everybody

```dart
import 'package:tekartik_app_http/app_http.dart';
import 'package:tekartik_firebase_firestore/firestore.dart';
import 'package:tekartik_http_firestore_redirect/firestore_to_http_redirect.dart';

/// Run where the network is available; [path] is a firestore document path.
Future<RedirectorService> startRedirector(
  Firestore firestore,
  String path,
) async {
  var service = RedirectorService(
    Redirector('my_tunnel', 'https://example.com'),
    firestore: firestore,
    path: path,
    httpClientFactory: httpFactoryIo.client,
  );
  await service.start();
  return service;
}
```

### Caller side: a normal http client factory

```dart
import 'package:tekartik_app_http/app_http.dart';
import 'package:tekartik_firebase_firestore/firestore.dart';
import 'package:tekartik_http_firestore_redirect/http_to_firestore.dart';

/// One factory for the whole app, then use it like any [HttpClientFactory].
Future<String> readThroughFirestore(Firestore firestore, Uri uri) async {
  var factory = newHttpClientFactoryToFirestore(
    firestore: firestore,
    path: 'redirect/my_tunnel',
  );
  var client = factory.newClient();
  try {
    return await client.read(uri);
  } finally {
    client.close();
  }
}
```

### Post json through the tunnel

```dart
import 'dart:convert';

import 'package:tekartik_app_http/app_http.dart';
import 'package:tekartik_firebase_firestore/firestore.dart';
import 'package:tekartik_http_firestore_redirect/http_to_firestore.dart';

Future<Object?> postJson(
  Firestore firestore,
  Uri uri,
  Map<String, Object?> data,
) async {
  var client = newHttpClientFactoryToFirestore(
    firestore: firestore,
    path: 'redirect/my_tunnel',
  ).newClient();
  var response = await httpClientSend(
    client,
    httpMethodPost,
    uri,
    headers: {httpHeaderContentType: httpContentTypeJson},
    body: jsonEncode(data),
    throwOnFailure: true,
  );
  return jsonDecode(utf8.decode(response.bodyBytes));
}
```

### Both sides in one test, memory firestore

```dart
import 'package:tekartik_app_http/app_http.dart';
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:tekartik_http_firestore_redirect/firestore_to_http_redirect.dart';
import 'package:tekartik_http_firestore_redirect/http_to_firestore.dart';
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
      path: path,
    );
    setUpAll(() async {
      await redirector.start();
    });
    tearDownAll(() async {
      redirector.stop();
    });
    // The whole shared suite runs through firestore.
    runHttpRedirectTest(
      httpFactory: httpFactoryMemory,
      outboundHttpClientFactory: newHttpClientFactoryToFirestore(
        firestore: firestore,
        path: path,
      ),
    );
  });
}
```
