# tekartik_http_redirect

A small HTTP redirect (proxy) server that adds CORS headers, and the client that
goes through it. Typical use: browser code calling an api that serves no CORS
header, during development or in tests.

* Server: `HttpRedirectServer` receives a request, picks the target url (a
  header, a query parameter or a default base url), replays the request with
  `package:http` and copies the response back with CORS headers.
* Client: `RedirectClient` (a `package:http` `Client`) sends every request to
  the redirect server with the real url in the `x-tekartik-redirect-url`
  header.

Both are written on the `tekartik_http` abstractions: the server runs on
`dart:io` (`httpFactoryIo`) or in memory (`httpFactoryMemory`, for tests).

## Getting started

Git package, not on pub.dev:

```yaml
dependencies:
  tekartik_http_redirect:
    git:
      url: https://github.com/tekartik/http_redirect.dart
      path: packages/http_redirect
```

### Command line

```bash
# http://localhost:8180/<path> is proxied to https://example.com/<path>
dart run tekartik_http_redirect:http_redirect -p 8180 -b https://example.com
```

Options: `-p` port (8180), `-b` default base url, `--no-cors`,
`-o` CORS allowed headers, `--no-forward-headers`, `--no-forward-arguments`,
`-h` usage. Without `-b`, each request gives its target in the
`x-tekartik-redirect-url` header (full url) or `x-tekartik-redirect-base-url`
(header or query parameter, the request path is appended).

### In code

A redirect server and a client using it (see [example/main.dart](example/main.dart),
it runs with `dart run example/main.dart`):

```dart
import 'package:tekartik_http_io/http_io.dart';
import 'package:tekartik_http_redirect/http_redirect.dart';
import 'package:tekartik_http_redirect/http_redirect_client.dart';

Future<void> main() async {
  // The target: a server without CORS headers
  var target = await httpFactoryIo.server.bind(localhost, 0);
  target.listen((request) async {
    request.response.write('hello ${request.uri.path}');
    await request.response.close();
  });

  // The redirect server, on localhost only
  var redirectServer = await HttpRedirectServer.startServer(
    httpFactory: httpFactoryIo,
    options: Options()
      ..host = localhost
      ..port = 0, // 0: a free port, default 8180
  );

  // A client sending its requests through the redirect server
  var client = RedirectClient(
    httpFactoryIo.client.newClient(),
    redirectServerUri: httpServerGetUri(redirectServer.httpServer),
  );
  try {
    var uri = httpServerGetUri(target).replace(path: 'world');
    print(await client.read(uri)); // hello /world
  } finally {
    client.close();
    await redirectServer.close();
    await target.close();
  }
}
```

## Platforms

* Server and command line: Dart VM (`httpFactoryIo`); in memory everywhere
  (`httpFactoryMemory`, tests).
* Client: everywhere `package:http` runs (browser, Flutter, VM, node). Wrap any
  `http.Client`, or use `RedirectClientFactory` to route a whole
  `HttpClientFactory`.

## Imports

| Import | Gives |
|---|---|
| `package:tekartik_http_redirect/http_redirect.dart` | `HttpRedirectServer`, `Options`, `proxyHttpRequest`, `corsDefaultHeaders`, the header constants and conversion helpers |
| `package:tekartik_http_redirect/http_redirect_client.dart` | `RedirectClient`, `RedirectClientFactory` |

## Common pitfalls

* The command line binds all the network interfaces (`0.0.0.0`): anyone on the
  same network can use it to reach any url, including services the machine
  only exposes on localhost. Use it on a trusted network, or start
  `HttpRedirectServer` in code with `host = localhost`.
* With CORS on (the default), only the CORS headers (`corsDefaultHeaders`:
  `Content-Type`, `Authorization`, `Accept`...) of a request reach the target.
  Send other headers through `RedirectClient(forwardedRequestHeaders: [...])`
  (they travel as `x-tekartik-forward-<name>`), or start the server with
  `forwardHeaders` and `handleCors = false`.
* With no target (no header, no query parameter, no `baseUrl`) the server
  answers 405 (400 with `allowMissingRedirectHeader`); an error while calling
  the target is also answered 405, with the error text.
* Every request is printed on stdout (method and uri, query parameters
  included).
* The server follows the target's redirects and decompresses its body: the
  client gets the final response, without `content-encoding`.
* Several `set-cookie` headers of the target are joined in one header line.
* The top level `startServer` is deprecated: use `HttpRedirectServer.startServer`.

## Testing

```bash
dart test
```

The tests run the server and the client in memory and on io.
