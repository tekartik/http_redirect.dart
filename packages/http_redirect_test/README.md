# tekartik_http_redirect_test

The shared test suite of
[tekartik_http_redirect](../http_redirect): it starts an echo server, puts an
`HttpRedirectServer` in front of it and checks calls through the proxy
(status codes, paths, query parameters, utf-8 bodies). Run it against an
http implementation (`httpFactoryMemory`, `httpFactoryIo`...), a mix of two
(`testServerHttpFactory`), or a custom transport
(`outboundHttpClientFactory`, as tekartik_http_firestore_redirect does).

## Getting started

```yaml
dev_dependencies:
  tekartik_http_redirect_test:
    git:
      url: https://github.com/tekartik/http_redirect.dart
      path: packages/http_redirect_test
  test:
```

```dart
@TestOn('vm')
library;

import 'package:tekartik_http/http_memory.dart';
import 'package:tekartik_http_io/http_io.dart';
import 'package:tekartik_http_redirect_test/http_redirect_test.dart';
import 'package:test/test.dart';

void main() {
  group('io', () {
    runHttpRedirectTest(httpFactory: httpFactoryIo);
  });
  group('memory_proxy_io_target', () {
    runHttpRedirectTest(
      httpFactory: httpFactoryMemory,
      testServerHttpFactory: httpFactoryIo,
    );
  });
}
```

See [doc/testing.md](doc/testing.md) for a manual run with curl.
