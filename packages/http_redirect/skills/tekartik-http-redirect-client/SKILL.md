---
name: tekartik-http-redirect-client
description: >-
  Use when client code (browser or vm) must reach a server through a
  tekartik_http_redirect proxy to work around missing CORS headers:
  RedirectClient, RedirectClientFactory, the redirectServerUri and
  forwardedRequestHeaders parameters, the x-tekartik-redirect-url /
  x-tekartik-redirect-base-url headers, the x-tekartik-forward- prefix and the
  redirectClientConvertRequestHeaders / redirectServerConvertRequestHeaders
  helpers of package:tekartik_http_redirect/http_redirect_client.dart.
---

# Http redirect client (tekartik_http_redirect)

`RedirectClient` is a `package:http` `Client` wrapper: it sends every request to
a redirect (proxy) server instead of the real target, and puts the real target
url in the `x-tekartik-redirect-url` header. Browser code can then call an api
that serves no CORS header, because the proxy answers the preflight and adds
the CORS headers itself.

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
* Import `package:tekartik_http_redirect/http_redirect_client.dart`: it exports
  exactly `RedirectClient` and `RedirectClientFactory`. The header constants and
  helpers live in `package:tekartik_http_redirect/http_redirect.dart`
  (`redirectUrlHeader`, `redirectBaseUrlHeader`,
  `redirectClientConvertRequestHeaders`,
  `redirectServerConvertRequestHeaders`). Starting the proxy itself is the
  `tekartik-http-redirect-server` skill,
  [../tekartik-http-redirect-server/SKILL.md](../tekartik-http-redirect-server/SKILL.md).
* `RedirectClient(inner, redirectServerUri: Uri.parse('http://localhost:8180'))`
  wraps any `http.Client` (`Client()` from `package:http`, or
  `httpClientFactoryMemory.newClient()` in tests). Use it like a normal client:
  `read`, `get`, `post`, `send`... keep passing the *real* target url; method,
  body, content length, redirect settings and headers are preserved.
  `close()` closes the inner client.
* `forwardedRequestHeaders: ['x-test']` renames the listed request headers to
  `x-tekartik-forward-x-test` so a CORS-handling proxy unwraps them and sends
  them to the target. Without it, custom headers are dropped by the proxy
  (only the headers of its `corsHeaders` list survive). Names are matched
  lowercase.
* `RedirectClientFactory(innerFactory, redirectServerUri: ...,
  forwardedRequestHeaders: ...)` implements `tekartik_http`'s
  `HttpClientFactory`: `newClient()` returns a `RedirectClient` wrapping
  `innerFactory.newClient()`. Pass it to any api layer that takes an
  `HttpClientFactory` to route a whole app through the proxy without touching
  the call sites.
* `redirectClientConvertRequestHeaders(headers, forwardedHeaders)` applies the
  same prefixing to a plain header map (useful when you build the request
  yourself); `redirectServerConvertRequestHeaders(httpHeaders)` is the server
  side counterpart that strips the prefix.
* Without any wrapper, a plain `http.Client` can call the proxy directly: send
  the request to the proxy url with an `x-tekartik-redirect-url` header (full
  target), an `x-tekartik-redirect-base-url` header (or query parameter) plus a
  path, or let the proxy use its own `baseUrl`.
* The proxy must be reachable from the browser: a proxy started with
  `handleCors: false` breaks web usage. If the proxy was started with
  `options.forwardedHeaders`, it forwards those header names verbatim: keep
  them plain on the client and do not also list them in
  `forwardedRequestHeaders`.
* Web tests: the `tekartik_http_redirect_client_browser_test` package of the
  same repo has a ready made browser menu calling an echo server through a
  proxy on `http://localhost:8180`.

## Examples

### Call a CORS-less api through a local proxy

```dart
import 'package:http/http.dart';
import 'package:tekartik_http_redirect/http_redirect_client.dart';

/// Works in the browser: the proxy on 8180 adds the CORS headers.
Future<String> readThroughProxy(Uri target) async {
  var client = RedirectClient(
    Client(),
    redirectServerUri: Uri.parse('http://localhost:8180'),
  );
  try {
    return await client.read(target);
  } finally {
    client.close();
  }
}
```

### A factory for the whole app, forwarding an authorization header

```dart
import 'package:tekartik_http/http.dart';
import 'package:tekartik_http_io/http_io.dart';
import 'package:tekartik_http_redirect/http_redirect_client.dart';

/// [HttpClientFactory] that routes every client through the proxy and keeps
/// the authorization header alive across it.
HttpClientFactory proxiedClientFactory(Uri redirectServerUri) =>
    RedirectClientFactory(
      httpFactoryIo.client,
      redirectServerUri: redirectServerUri,
      forwardedRequestHeaders: ['authorization'],
    );

Future<String> callApi(HttpClientFactory factory, Uri uri, String token) async {
  var client = factory.newClient();
  try {
    return await httpClientRead(
      client,
      httpMethodGet,
      uri,
      headers: {'authorization': 'Bearer $token'},
    );
  } finally {
    client.close();
  }
}
```

### End to end test, everything in memory

```dart
import 'package:tekartik_http/http.dart';
import 'package:tekartik_http/http_memory.dart';
import 'package:tekartik_http_redirect/http_redirect.dart';
import 'package:tekartik_http_redirect/http_redirect_client.dart';
import 'package:test/test.dart';

void main() {
  test('forwarded header', () async {
    var target = await httpFactoryMemory.server.bind(localhost, httpPortAny);
    target.listen((request) {
      request.response
        ..write('${request.headers.value('x-test')}')
        ..close();
    });
    var targetUri = httpServerGetUri(target);

    var proxy = await HttpRedirectServer.startServer(
      httpFactory: httpFactoryMemory,
      options: Options()
        ..host = localhost
        ..port = httpPortAny
        ..baseUrl = targetUri.toString(),
    );

    var factory = RedirectClientFactory(
      httpFactoryMemory.client,
      redirectServerUri: httpServerGetUri(proxy.httpServer),
      forwardedRequestHeaders: ['x-test'],
    );
    var client = factory.newClient();
    expect(await client.read(targetUri, headers: {'x-test': '1234'}), '1234');
    client.close();

    await proxy.close();
    await target.close();
  });
}
```

### Plain http client, header set by hand

```dart
import 'package:http/http.dart';
import 'package:tekartik_http_redirect/http_redirect.dart';

/// Same effect as [RedirectClient] for a single call.
Future<String> readThroughProxyByHand(Uri proxyUri, Uri target) async {
  var client = Client();
  try {
    return await client.read(
      proxyUri,
      headers: {redirectUrlHeader: target.toString()},
    );
  } finally {
    client.close();
  }
}
```
