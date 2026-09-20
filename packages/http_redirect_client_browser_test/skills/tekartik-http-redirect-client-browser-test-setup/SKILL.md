---
name: tekartik-http-redirect-client-browser-test-setup
description: >-
  Use when manually checking RedirectClient from a real browser with the
  tekartik_http_redirect_client_browser_test web app: initTestMenuBrowser,
  menu/item/write/prompt from tekartik_test_menu_browser, the
  call_echo_8501_through_redirect_8180 entry, running it with
  build_runner serve / webdev, and the echo server (8501) plus redirect proxy
  (8180) it expects.
---

# Browser check of the redirect client (tekartik_http_redirect_client_browser_test)

This package is not a library: it is a tiny `web/` application whose menu calls
an echo server twice, once directly and once through a `RedirectClient`. Only a
real browser enforces CORS, so this is how a change to the redirect client or
to the proxy is verified end to end.

## Guidelines

* Nothing to depend on: this package exists to be run, not imported (no
  `lib/`). Inside the repo it uses `tekartik_http_redirect` through a local
  `path: ../http_redirect` dependency and
  `tekartik_test_menu_browser` (git, `https://github.com/tekartik/test_menu.dart`,
  `path: test_menu_browser`). Copy the same two dependencies plus `http` to
  make a similar app elsewhere.
* Run order (three terminals):
  1. echo server on 8501:
     `dart run example/echo_server_8501.dart` in the sibling
     `packages/http_redirect_test` package (it calls `serveEchoParams` on port
     8501).
  2. redirect proxy on 8180 with CORS on (the default):
     `dart run tekartik_http_redirect:http_redirect -p 8180`.
  3. this app: `dart run build_runner serve web:8080` from this package
     directory, then open `http://localhost:8080`.
  `build_runner` and `build_web_compilers` are already dev dependencies;
  `webdev serve` works too.
* The page shows a text menu. `call_echo_8501` calls
  `http://localhost:8501?body=my_body` directly and is expected to fail with a
  CORS error in the browser console (the echo server sends no CORS header);
  `call_echo_8501_through_redirect_8180` performs the same call through
  `RedirectClient` and must print `my_body`. That difference is the whole
  point of the app.
* App structure: `await initTestMenuBrowser();` first (from
  `package:tekartik_test_menu_browser/test_menu_browser.dart`, which also
  re-exports `menu`, `item`, `write` and `prompt`), then one `menu('main', ()
  { ... })` block declaring `item('<name>', () async { ... })` entries. `write`
  prints in the page, `prompt` asks for a line of input.
* In the browser, use a plain `Client()` from `package:http` as the inner
  client (it is a `BrowserClient` once compiled to JS) and wrap it in
  `RedirectClient(client, redirectServerUri: Uri.parse('http://localhost:8180'))`.
  Keep passing the real target url to `read`/`get`; the proxy url is only the
  `redirectServerUri`.
* Custom request headers do not survive the proxy unless they are listed in
  `forwardedRequestHeaders` (they become `x-tekartik-forward-<name>`) or in the
  proxy's own cors/forwarded header lists; see the
  `tekartik-http-redirect-client` skill of `tekartik_http_redirect`.
* This is a manual app, not a `dart test` suite: there is no headless runner
  here. For automated coverage use `runHttpRedirectTest` from
  `tekartik_http_redirect_test`.
* `web/index.html` only loads `main.dart.js`, so a new page needs no html
  change: add an `item(...)` to `web/main.dart`.

## Examples

### web/main.dart: the menu app

```dart
import 'package:http/http.dart';
import 'package:tekartik_http_redirect/http_redirect_client.dart';
import 'package:tekartik_test_menu_browser/test_menu_browser.dart';

Future<void> main() async {
  await initTestMenuBrowser();

  menu('main', () {
    item('prompt', () async {
      write('RESULT prompt: ${await prompt('Some text please then [ENTER]')}');
    });
    item('call_echo_8501_through_redirect_8180', () async {
      var client = Client();
      var redirectClient = RedirectClient(
        client,
        redirectServerUri: Uri.parse('http://localhost:8180'),
      );
      write(
        await redirectClient.read(
          Uri.parse('http://localhost:8501?body=my_body'),
        ),
      );
    });
    item('call_echo_8501', () async {
      var client = Client();
      write(await client.read(Uri.parse('http://localhost:8501?body=my_body')));
    });
  });
}
```

### Adding an item that forwards a header

```dart
import 'package:http/http.dart';
import 'package:tekartik_http_redirect/http_redirect_client.dart';
import 'package:tekartik_test_menu_browser/test_menu_browser.dart';

void declareForwardedHeaderItem() {
  item('call_echo_8501_with_header', () async {
    var client = RedirectClient(
      Client(),
      redirectServerUri: Uri.parse('http://localhost:8180'),
      forwardedRequestHeaders: ['x-test'],
    );
    // The echo server returns the request uri in x-echo-request-uri.
    var response = await client.get(
      Uri.parse('http://localhost:8501?body=my_body'),
      headers: {'x-test': '1234'},
    );
    write('${response.statusCode} ${response.body}');
    write('${response.headers['x-echo-request-uri']}');
    client.close();
  });
}
```

### Starting everything

```bash
# terminal 1, from packages/http_redirect_test
dart run example/echo_server_8501.dart

# terminal 2, from any package depending on tekartik_http_redirect
dart run tekartik_http_redirect:http_redirect -p 8180

# terminal 3, from packages/http_redirect_client_browser_test
dart pub get
dart run build_runner serve web:8080
# then open http://localhost:8080 and run the menu items
```
