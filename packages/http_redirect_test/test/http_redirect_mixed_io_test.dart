@TestOn('vm')
library;

import 'package:tekartik_http/http_memory.dart';
import 'package:tekartik_http_io/http_io.dart';
import 'package:tekartik_http_redirect_test/http_redirect_test.dart';
import 'package:test/test.dart';

/// The redirect server and the target server on different implementations:
/// the tests must reach the redirect server with a client of its own
/// implementation.
void main() {
  group('memory_proxy_io_target', () {
    runHttpRedirectTest(
      httpFactory: httpFactoryMemory,
      testServerHttpFactory: httpFactoryIo,
    );
  });
  group('io_proxy_memory_target', () {
    runHttpRedirectTest(
      httpFactory: httpFactoryIo,
      testServerHttpFactory: httpFactoryMemory,
    );
  });
}
