@TestOn('vm')
library;

import 'package:tekartik_http/http_memory.dart';
import 'package:tekartik_http_io/http_io.dart';
import 'package:tekartik_http_redirect/http_redirect.dart';
import 'package:test/test.dart';

import 'multiplatform/http_redirect_test.dart';

void main() {
  // debugHttpRedirectServer = devWarning(true);
  run(httpFactory: httpFactoryIo);
  run(httpFactory: httpFactoryIo, testServerHttpFactory: httpFactoryMemory);

  run(httpFactory: httpFactoryMemory, testServerHttpFactory: httpFactoryIo);

  test('deprecated startServer', () async {
    var target = await httpFactoryIo.server.bind(localhost, 0);
    target.listen((request) async {
      request.response.write('${request.uri}');
      await request.response.close();
    });
    // ignore: deprecated_member_use_from_same_package
    var server = await startServer(
      httpFactoryIo.server,
      Options()
        ..host = localhost
        ..port = 0
        ..baseUrl = httpServerGetUri(target).toString(),
    );
    var client = httpFactoryIo.client.newClient();
    try {
      var response = await httpClientSend(
        client,
        httpMethodGet,
        httpServerGetUri(server).resolve('/sub?a=1'),
      );
      expect(response.statusCode, 200, reason: response.body);
      expect(response.body, '/sub?a=1');
    } finally {
      client.close();
      await server.close(force: true);
      await target.close();
    }
  });
}
