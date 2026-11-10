# tekartik_http_firestore_redirect

Http calls tunnelled through Firestore. The caller gets a normal
`package:http` `Client`; each request is written to a Firestore document,
a `RedirectorService` running where the target is reachable performs the
real call and writes the response back. Use it when the caller cannot reach
the target directly (a browser blocked by CORS, a device without access to a
private network) but both can reach the same Firestore project.

## Getting started

Not on pub.dev, a git dependency:

```yaml
dependencies:
  tekartik_http_firestore_redirect:
    git:
      url: https://github.com/tekartik/http_redirect.dart
      path: packages/http_firestore_redirect
```

The snippets also import `tekartik_app_http` (the http factories) and
`tekartik_firebase_firestore` (the `Firestore` type), both pulled by this
package: declare them too when you import them.

Both sides use the same Firestore instance (project) and the same `path`, a
Firestore document path:

```dart
import 'package:tekartik_app_http/app_http.dart';
import 'package:tekartik_firebase_firestore/firestore.dart';
import 'package:tekartik_http_firestore_redirect/firestore_to_http_redirect.dart';
import 'package:tekartik_http_firestore_redirect/http_to_firestore.dart';

/// Service side, where https://example.com is reachable (dart:io).
Future<RedirectorService> startService(Firestore firestore) async {
  var service = RedirectorService(
    Redirector('my_tunnel', 'https://example.com'),
    firestore: firestore,
    path: 'redirect/my_tunnel',
    httpClientFactory: httpFactoryIo.client,
  );
  await service.start(); // service.stop() when done
  return service;
}

/// Caller side, anywhere.
Future<String> callThroughFirestore(Firestore firestore) async {
  var client = newHttpClientFactoryToFirestore(
    firestore: firestore,
    path: 'redirect/my_tunnel',
  ).newClient();
  try {
    // Relative to the service's base url: https://example.com/api/info
    return await client.read(Uri.parse('api/info'));
  } finally {
    client.close();
  }
}
```

`example/main.dart` runs both sides in one process on a memory Firestore
(`newFirestoreMemory()` of tekartik_firebase_firestore_sembast).

## Platforms

Pure Dart: Dart VM, Flutter, web (dart2js and dart2wasm). The caller works
with any tekartik `Firestore` implementation. The service needs an http
client able to reach the target: `httpFactoryIo.client` on the Dart VM or
Flutter (a browser would hit CORS).

## How it works

* The caller writes `<path>/request/<id>` (`url`, `method`, `headers`, `body`
  as a `Blob`, `timestamp`) and waits for `<path>/response/<id>`
  (`statusCode`, `headers`, `body`, or `error.message` when the call
  failed), then deletes it.
* The service listens to `<path>/request`, performs each call (any method,
  with its headers and body), writes the response and deletes the request.
  With a `Redirector` base url, a relative request url is joined to it; with
  a null base url, the service reads the `baseUrl` field of the document at
  `path` (changes are followed).
* Every `http.Client` method works (`get`, `post`, `read`, `head`,
  `send` of a streamed or multipart request...): the body is sent whole.

## Pitfalls

* No service running: the call fails after 30 seconds with a
  `TimeoutException`. Run one service per `path`.
* The target unreachable: an `http.ClientException` with the service's
  error message.
* Firestore limits a document to 1 MiB: a request or response body close to
  that size cannot go through.
* Everything (urls, headers, bodies) is stored in clear in Firestore: protect
  the collections with security rules, and let callers delete their response
  documents (otherwise they stay).
* A call that timed out leaves its request: a service started later still
  performs it.

## More

* Agent skill: `skills/tekartik-http-firestore-redirect-setup/SKILL.md`.
* The http version of the tunnel (a proxy server): `tekartik_http_redirect`
  in the same repository.
