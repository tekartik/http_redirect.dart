---
name: tekartik-http-redirect-test-setup
description: >-
  Use when running the shared tekartik_http_redirect conformance suite against
  an http implementation or a custom outbound client: runHttpRedirectTest
  (httpFactory, testServerHttpFactory, outboundHttpClientFactory,
  overridenClientUri), the legacy run() group, and the serveEchoParams echo
  server (?body=, ?statusCode=, x-echo-request-uri) of
  package:tekartik_http_redirect_test.
---

# Shared redirect test suite (tekartik_http_redirect_test)

`tekartik_http_redirect_test` is a test helper package: it starts an echo
server, puts an `HttpRedirectServer` in front of it and runs a `package:test`
suite of calls through the proxy. Point it at any `HttpFactory`
(`httpFactoryMemory`, `httpFactoryIo`, ...) or at any outbound
`HttpClientFactory` to check that a transport behaves like a real http client.

## Guidelines

* Dev dependency (git, not on pub.dev):
  ```yaml
  dev_dependencies:
    tekartik_http_redirect_test:
      git:
        url: https://github.com/tekartik/http_redirect.dart
        path: packages/http_redirect_test
      version: '>=0.0.1'
    test:
    # whichever implementation you test, e.g.
    tekartik_http_io:
      git:
        url: https://github.com/tekartik/http.dart
        path: http_io
  ```
  `httpFactoryIo` also comes from `package:tekartik_app_http/app_http.dart`,
  which compiles on the web too.
* Import `package:tekartik_http_redirect_test/http_redirect_test.dart` and call
  the entry points from the `main()` of one of your own test files. The library
  itself has a `main()` that runs everything against `httpFactoryMemory`.
* `runHttpRedirectTest(httpFactory: ...)` is the suite. It declares a
  `http_redirect_test` group that, in `setUpAll`, starts the echo server, starts
  `HttpRedirectServer` with `baseUrl` set to the echo server uri, port `0` and
  host `localhost`, then checks: default status code, `?statusCode=200/400`
  (including `HttpClientException` with `throwOnFailure`), path joining through
  the proxy (`x-echo-request-uri`), `forwardArguments`, dynamic port
  allocation, `httpClientRead` / `httpClientReadBytes` and utf-8 decoding with
  `responseEncoding`.
* Named parameters of `runHttpRedirectTest`:
  * `httpFactory` (required): implementation under test; serves the redirect
    server and provides the fallback client.
  * `testServerHttpFactory`: serve the echo target with another implementation
    (cross implementation run, e.g. memory proxy in front of an io server).
  * `outboundHttpClientFactory`: the client factory the redirect server uses to
    reach the target *and* the client the tests use; defaults to the target
    factory's client. This is the hook for testing an exotic transport (for
    instance the firestore backed client factory of
    `tekartik_http_firestore_redirect`).
  * `overridenClientUri`: call that uri instead of the started redirect server
    uri (an already running proxy on a fixed port).
* `run({httpFactory, testServerHttpFactory})` is the older, smaller `redirect`
  group (one plain redirection test). Keep using `runHttpRedirectTest` for new
  code; `httpFactory` is nullable in the signature but must be provided.
* Echo server: `serveEchoParams(HttpServerFactory factory, int port)` from
  `package:tekartik_http_redirect_test/src/echo_server.dart` (a `src/` import,
  as in this package's own `example/`; the main library does not re-export it).
  Port `0` picks a free port. It answers `?body=<text>` with that text,
  `?statusCode=<code>` with that status, echoes the request body bytes when no
  `body` parameter is given, always sets `text/plain` and adds the
  `x-echo-request-uri` response header. It prints two sample urls on startup.
* Run with `dart test` (add `@TestOn('vm')` to a file using `httpFactoryIo`).
  The memory factory needs no port and is the fastest way to run the suite.
* The `example/` folder of this package is the manual setup: run
  `echo_server_8501.dart`, then a proxy on 8180 (`cors_no_headers.dart` of the
  same folder or `dart run tekartik_http_redirect:http_redirect -p 8180`), then
  `call_echo_8501_through_redirect_8180.dart`.
* For the generic (non redirect) http client/server conformance suites, use the
  `tekartik_http_test` package instead.

## Examples

### Run the suite on the Dart VM

```dart
@TestOn('vm')
library;

import 'package:tekartik_http_io/http_io.dart';
import 'package:tekartik_http_redirect_test/http_redirect_test.dart';
import 'package:test/test.dart';

void main() {
  runHttpRedirectTest(httpFactory: httpFactoryIo);
}
```

### Memory only, then memory proxy in front of a real server

```dart
@TestOn('vm')
library;

import 'package:tekartik_http/http_memory.dart';
import 'package:tekartik_http_io/http_io.dart';
import 'package:tekartik_http_redirect_test/http_redirect_test.dart';
import 'package:test/test.dart';

void main() {
  group('memory', () {
    runHttpRedirectTest(httpFactory: httpFactoryMemory);
  });
  group('memory_proxy_io_target', () {
    runHttpRedirectTest(
      httpFactory: httpFactoryMemory,
      testServerHttpFactory: httpFactoryIo,
    );
  });
}
```

### Check a custom transport (outbound client factory)

```dart
import 'package:tekartik_http/http.dart';
import 'package:tekartik_http/http_memory.dart';
import 'package:tekartik_http_redirect_test/http_redirect_test.dart';

/// [myClientFactory] is any HttpClientFactory implementation: the redirect
/// server and the test client both use it, so the whole suite runs through it.
void defineMyTransportTests(HttpClientFactory myClientFactory) {
  runHttpRedirectTest(
    httpFactory: httpFactoryMemory,
    outboundHttpClientFactory: myClientFactory,
  );
}
```

### Start the echo server alone (manual testing)

```dart
import 'package:tekartik_http_io/http_io.dart';
import 'package:tekartik_http_redirect_test/src/echo_server.dart';

/// curl 'http://localhost:8501?body=test'
/// curl 'http://localhost:8501?body=test&statusCode=400'
Future<void> main() async {
  await serveEchoParams(httpFactoryIo.server, 8501);
}
```

### Test an already running proxy on a fixed port

```dart
@TestOn('vm')
library;

import 'package:tekartik_http_io/http_io.dart';
import 'package:tekartik_http_redirect_test/http_redirect_test.dart';
import 'package:test/test.dart';

void main() {
  // dart run tekartik_http_redirect:http_redirect -p 8180 -b <echo server uri>
  runHttpRedirectTest(
    httpFactory: httpFactoryIo,
    overridenClientUri: Uri.parse('http://localhost:8180'),
  );
}
```
