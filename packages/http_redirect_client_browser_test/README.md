# tekartik_http_redirect_client_browser_test

A manual browser check of `RedirectClient` (`tekartik_http_redirect`): a web
menu (`tekartik_test_menu_browser`) calling an echo server directly and
through the redirect proxy. Only a real browser enforces CORS, which is what
the proxy is for. Not a library, not a `dart test` suite.

## Run

Three terminals:

```bash
# 1. echo server on 8501 (no CORS header), from packages/http_redirect_test
dart run example/echo_server_8501.dart

# 2. redirect proxy on 8180, CORS on by default, from this package
dart run tekartik_http_redirect:http_redirect -p 8180

# 3. this app, from this package
dart run build_runner serve web:8080
```

Then open http://localhost:8080 and run the menu items:

* `call_echo_8501_through_redirect_8180` prints `my_body`: the call went
  through the proxy, which adds the CORS headers.
* `call_echo_8501` fails (`ClientException: Failed to fetch`, a CORS error in
  the browser console): the same call made directly.
* `prompt` checks the menu input.

The menu code is `web/main.dart`; add an `item(...)` there for a new check.
The agent skill (`skills/tekartik-http-redirect-client-browser-test-setup/`)
has more details. Automated tests of the proxy: `runHttpRedirectTest` of
`tekartik_http_redirect_test`.
