---
name: tekartik-http-redirect-server
description: >-
  Use when running or embedding the tekartik_http_redirect proxy/CORS server
  that forwards incoming HTTP requests to another host: HttpRedirectServer,
  HttpRedirectServer.startServer, Options (baseUrl, port, host, handleCors,
  corsHeaders, forwardedHeaders, forwardArguments, allowMissingRedirectHeader),
  proxyHttpRequest, corsDefaultHeaders, the x-tekartik-redirect-base-url,
  x-tekartik-redirect-url and x-tekartik-forward- headers, and the
  `dart run tekartik_http_redirect:http_redirect` command line.
---

# Http redirect server (tekartik_http_redirect)

`tekartik_http_redirect` is a tiny reverse proxy: it accepts a request, picks a
target url from a header, a query parameter or a default `baseUrl`, replays the
request there with `package:http` and copies the response back, adding CORS
headers on the way. Its main use is letting browser code reach a server that
serves no CORS header. The server side is written against the `tekartik_http`
abstractions, so it runs on `dart:io` (`httpFactoryIo`) or fully in memory
(`httpFactoryMemory`) in tests.

## Guidelines

* Dependency (git, not on pub.dev):
  ```yaml
  dependencies:
    tekartik_http_redirect:
      git:
        url: https://github.com/tekartik/http_redirect.dart
        path: packages/http_redirect
      version: '>=0.0.1'
  ```
  It brings `tekartik_http` and `tekartik_http_io`; declare them explicitly too
  when you import their factories.
* Server import: `package:tekartik_http_redirect/http_redirect.dart`. It
  exports `HttpRedirectServer`, `Options`, `proxyHttpRequest`,
  `corsDefaultHeaders`, `redirectBaseUrlHeader`, `redirectUrlHeader`,
  `redirectClientConvertRequestHeaders` and
  `redirectServerConvertRequestHeaders`. The client side lives in
  `package:tekartik_http_redirect/http_redirect_client.dart` (see the
  `tekartik-http-redirect-client` skill, [../tekartik-http-redirect-client/SKILL.md](../tekartik-http-redirect-client/SKILL.md)).
* Start with `await HttpRedirectServer.startServer(httpFactory: httpFactoryIo,
  options: Options()..port = 8180)`. Either pass `httpFactory:`, or pass both
  `httpClientFactory:` and `httpServerFactory:` (useful to mix
  implementations, e.g. a memory server calling an io client). Passing none of
  them throws a null check error.
* The returned `HttpRedirectServer` exposes `port`, `httpServer` (the bound
  `HttpServer`, so `httpServerGetUri(server.httpServer)` gives the url) and
  `close()`. Use `port: 0` (`httpPortAny`) to get a free port in tests.
* `options.host` accepts anything `HttpServerFactory.bind` accepts:
  `localhost`, `localhostIpV4`, `InternetAddress.anyIPv4` (the default when
  `host` is null). Default port is `8180`.
* Target resolution, per request: full url from the `x-tekartik-redirect-url`
  request header wins; otherwise the base url is the
  `x-tekartik-redirect-base-url` header, then the query parameter of the same
  name, then the legacy `_tekartik_redirect_host` header, then
  `options.baseUrl`, and the request path is joined to it. With no base url and
  no full url the server answers `405` unless
  `options.allowMissingRedirectHeader` is true.
* `options.forwardArguments` (default true) merges the incoming query
  parameters into the target uri.
* CORS (`options.handleCors`, default true): every response gets
  `Access-Control-Allow-Origin: *`, `Access-Control-Allow-Methods: POST,
  OPTIONS, GET, PATCH, DELETE` and `Access-Control-Allow-Headers:
  options.corsHeadersText`; `OPTIONS` requests are answered `200` without
  proxying. `options.corsHeaders = [...]` replaces the allowed header list
  (default `corsDefaultHeaders`; the two redirect headers are always appended).
* Request headers sent to the target: `host` is never forwarded; any
  `x-tekartik-forward-<name>` header is forwarded as `<name>` (that is what the
  client's `forwardedRequestHeaders` produces); with `handleCors` true only the
  headers listed in `corsHeaders` are forwarded, and the two redirect headers
  are dropped. Setting `options.forwardedHeaders = ['x-api-key']` switches to
  an explicit allow list and takes precedence over everything else.
  `Options.forwardHeaders` only backs the cli flag: the proxy never reads it.
* Response: status code and headers are copied back except `content-length` and
  `content-encoding`, and `x-tekartik-redirect-url` is set to the resolved
  target url.
* A request whose only query parameter is `x-tekartik-redirect-help` returns a
  usage line instead of proxying.
* Command line, no code needed:
  `dart run tekartik_http_redirect:http_redirect -p 8180 -b https://example.com`
  (`-c/--cors`, `-o/--cors-headers`, `-l/--log`, `--[no-]forward-headers`,
  `--[no-]forward-arguments`, `-h` for help).
* Anti-patterns: the top level `startServer(factory, options)` is deprecated,
  use `HttpRedirectServer.startServer`; `debugHttpRedirectServer` is only
  reachable through `package:tekartik_http_redirect/src/http_redirect_server.dart`
  (test code only); when calling `proxyHttpRequest` yourself, set
  `options.corsHeaders` first (it is lazily initialized by `corsHeadersText`).
* Testing: run the whole thing in memory with `httpFactoryMemory` from
  `package:tekartik_http/http_memory.dart`, or reuse the shared suite
  `runHttpRedirectTest(httpFactory: ...)` of the `tekartik_http_redirect_test`
  package.

## Examples

### CORS proxy on port 8180 with a default target

```dart
import 'package:tekartik_http_io/http_io.dart';
import 'package:tekartik_http_redirect/http_redirect.dart';

Future<void> main() async {
  var server = await HttpRedirectServer.startServer(
    httpFactory: httpFactoryIo,
    options: Options()
      ..host = InternetAddress.anyIPv4
      ..port = 8180
      ..baseUrl = 'https://example.com'
      ..handleCors = true,
  );
  print('redirecting ${httpServerGetUri(server.httpServer)} to example.com');
}
```

### Open proxy driven by the client headers, forwarding an api key

```dart
import 'package:tekartik_http_io/http_io.dart';
import 'package:tekartik_http_redirect/http_redirect.dart';

/// No baseUrl: each request must carry x-tekartik-redirect-url (full target)
/// or x-tekartik-redirect-base-url. Only x-api-key is forwarded.
Future<HttpRedirectServer> startProxy({int port = 0}) async {
  var server = await HttpRedirectServer.startServer(
    httpFactory: httpFactoryIo,
    options: Options()
      ..host = localhost
      ..port = port
      ..forwardedHeaders = ['x-api-key']
      ..forwardArguments = true,
  );
  print('listening on ${httpServerGetUri(server.httpServer)}');
  return server;
}
```

### In memory round trip (no socket, no port conflict)

```dart
import 'package:tekartik_http/http.dart';
import 'package:tekartik_http/http_memory.dart';
import 'package:tekartik_http_redirect/http_redirect.dart';
import 'package:test/test.dart';

void main() {
  test('redirect', () async {
    var target = await httpFactoryMemory.server.bind(localhost, httpPortAny);
    target.listen((request) {
      request.response
        ..write('hello')
        ..close();
    });

    var redirectServer = await HttpRedirectServer.startServer(
      httpFactory: httpFactoryMemory,
      options: Options()
        ..host = localhost
        ..port = httpPortAny
        ..baseUrl = httpServerGetUri(target).toString(),
    );

    var client = httpFactoryMemory.client.newClient();
    var uri = httpServerGetUri(redirectServer.httpServer);
    expect(await client.read(uri), 'hello');
    client.close();

    await redirectServer.close();
    await target.close();
  });
}
```

### Mixing implementations: memory front end, real io client

```dart
import 'package:tekartik_http/http_memory.dart';
import 'package:tekartik_http_io/http_io.dart';
import 'package:tekartik_http_redirect/http_redirect.dart';

/// Serves in memory (fast tests) but performs the outgoing calls for real.
Future<HttpRedirectServer> startHybridServer(String baseUrl) async {
  return await HttpRedirectServer.startServer(
    httpServerFactory: httpFactoryMemory.server,
    httpClientFactory: httpFactoryIo.client,
    options: Options()
      ..host = localhost
      ..port = 0
      ..baseUrl = baseUrl,
  );
}
```

### Command line

```bash
# proxy http://localhost:8180/<path> to https://example.com/<path>
dart run tekartik_http_redirect:http_redirect -p 8180 -b https://example.com

# header driven, one off call through the proxy
curl -H 'x-tekartik-redirect-url: http://localhost:8501?body=test' \
  http://localhost:8180
```
