import 'package:tekartik_http_io/http_io.dart';
import 'package:tekartik_http_redirect/http_redirect.dart';

Future<void> main() async {
  await HttpRedirectServer.startServer(
    httpFactory: httpFactoryIo,
    options: Options()
      ..handleCors = true
      ..forwardHeaders = false,
  );
}
