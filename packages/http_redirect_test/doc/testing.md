# Manual testing

Start the echo server (port 8501) and a redirect server (port 8180), each in
its own terminal:

```bash
dart run example/echo_server_8501.dart
dart run example/cors_no_headers.dart
```

Then:

```bash
# Echo server directly
curl 'http://localhost:8501?body=test'
# Through the redirect server
curl -H 'x-tekartik-redirect-url: http://localhost:8501?body=test' http://localhost:8180
```

`dart run example/call_echo_8501_through_redirect_8180.dart` does the same
from Dart with a `RedirectClient`; `example/kill_8180.dart` stops a server
left on port 8180 (linux, `lsof`).
