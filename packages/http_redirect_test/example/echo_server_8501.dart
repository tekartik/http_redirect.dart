import 'package:tekartik_http_io/http_io.dart';
import 'package:tekartik_http_redirect_test/src/echo_server.dart';

// Run
// - echo_server_8501.dart
// - no_cors_header.dart
// curl http://localhost:8180
// curl http://localhost:8501
Future<void> main() async {
  await serveEchoParams(httpFactoryIo.server, 8501);
}
