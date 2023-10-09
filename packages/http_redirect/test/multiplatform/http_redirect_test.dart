import 'package:tekartik_http/http.dart';
import 'package:tekartik_http/http_memory.dart';
import 'package:tekartik_http_redirect/http_redirect.dart';
import 'package:tekartik_http_redirect/src/http_redirect_client.dart';
import 'package:test/test.dart';

void main() {
  run(httpFactory: httpFactoryMemory);
}

void run({
  required HttpFactory httpFactory,
  //HttpClientFactory? httpClientFactory,
  //HttpServerFactory? httpServerFactory,
  HttpFactory? testServerHttpFactory,
}) {
  var clientFactory = httpFactory.client;
  var serverFactory = httpFactory.server;
  var finalServerClientFactory = testServerHttpFactory?.client ?? clientFactory;

  group('redirect', () {
    test('redirect', () async {
      var httpServer = await (testServerHttpFactory?.server ?? serverFactory)
          .bind(localhost, 0);

      httpServer.listen((HttpRequest request) {
        request.response
          ..write('tekartik_http_redirect')
          ..close();
      });
      var port = httpServer.port;

      var finalUri = httpServerGetUri(httpServer);
      // devPrint('finalUri: $finalUri');

      var httpRedirectServer = await HttpRedirectServer.startServer(
          httpClientFactory: finalServerClientFactory,
          httpServerFactory: serverFactory,
          options: Options()
            ..host = localhost
            ..port = 0
            ..baseUrl = finalUri.toString());

      var client = clientFactory.newClient();
      var redirectPort = httpRedirectServer.port;
      var redirectUri = httpServerGetUri(httpRedirectServer.httpServer);
      //devPrint('redirectPort: $redirectPort');
      expect(port, isNot(redirectPort));
      expect(await client.read(redirectUri), 'tekartik_http_redirect');
      client.close();

      await httpRedirectServer.close();
      await httpServer.close();
    });

    test('redirectClient', () async {
      var finalServerFactory = testServerHttpFactory?.server ?? serverFactory;
      var httpServer = await (finalServerFactory).bind(localhost, 0);

      httpServer.listen((HttpRequest request) {
        request.response
          ..write('tekartik_http_redirect')
          ..close();
      });
      //var port = httpServer.port;
      var uri = httpServerGetUri(httpServer);
      // devPrint('uri: $uri');

      var httpRedirectServer = await HttpRedirectServer.startServer(
          httpClientFactory: finalServerClientFactory,
          httpServerFactory: serverFactory,
          options: Options()
            ..host = localhost
            ..port = 0
            ..baseUrl = uri.toString());

      var redirectServerUri = httpServerGetUri(httpRedirectServer.httpServer);
      // devPrint('redirectServerUrl: $redirectServerUri');
      var redirectClientFactory = RedirectClientFactory(clientFactory,
          redirectServerUri: redirectServerUri);
      var client = redirectClientFactory.newClient();

      //devPrint('redirectPort: $redirectPort');
      // expect(port, isNot(redirectPort));
      expect(await client.read(uri), 'tekartik_http_redirect');
      client.close();

      await httpRedirectServer.close();
      await httpServer.close();
    });

    test('headers redirectClient', () async {
      var finalServerFactory = testServerHttpFactory?.server ?? serverFactory;
      var httpServer = await (finalServerFactory).bind(localhost, 0);

      httpServer.listen((HttpRequest request) {
        request.response
          ..write('${request.headers.value('x-test')}')
          ..close();
      });
      //var port = httpServer.port;
      var uri = httpServerGetUri(httpServer);
      // devPrint('uri: $uri');

      var httpRedirectServer = await HttpRedirectServer.startServer(
          httpClientFactory: finalServerClientFactory,
          httpServerFactory: serverFactory,
          options: Options()
            ..host = localhost
            ..port = 0
            ..baseUrl = uri.toString());

      var redirectServerUri = httpServerGetUri(httpRedirectServer.httpServer);
      // devPrint('redirectServerUrl: $redirectServerUri');
      var redirectClientFactory = RedirectClientFactory(clientFactory,
          redirectServerUri: redirectServerUri,
          forwardedRequestHeaders: ['x-test']);
      var client = redirectClientFactory.newClient();

      //devPrint('redirectPort: $redirectPort');
      // expect(port, isNot(redirectPort));
      expect(await client.read(uri, headers: {'x-test': '1234'}), '1234');
      client.close();

      redirectClientFactory = RedirectClientFactory(
        clientFactory,
        redirectServerUri: redirectServerUri,
      );
      client = redirectClientFactory.newClient();

      //devPrint('redirectPort: $redirectPort');
      // expect(port, isNot(redirectPort));
      expect(await client.read(uri, headers: {'x-test': '1234'}), 'null');
      client.close();

      await httpRedirectServer.close();
      await httpServer.close();
    });
  });
}
