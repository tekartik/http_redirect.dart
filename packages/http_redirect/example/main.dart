// ignore_for_file: avoid_print

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
