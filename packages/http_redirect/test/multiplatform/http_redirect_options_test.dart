import 'dart:convert';

import 'package:tekartik_http/http.dart';
import 'package:tekartik_http/http_memory.dart';
import 'package:tekartik_http_redirect/http_redirect.dart';
import 'package:test/test.dart';

void main() {
  var httpFactory = httpFactoryMemory;
  group('options', () {
    late HttpServer target;
    late Uri targetUri;
    late Client client;

    setUpAll(() async {
      // Echo the request uri and headers as json
      target = await httpFactory.server.bind(localhost, 0);
      target.listen((request) async {
        var headers = <String, String>{};
        request.headers.forEach((name, values) {
          headers[name.toLowerCase()] = values.join(',');
        });
        request.response.write(
          jsonEncode({'uri': request.uri.toString(), 'headers': headers}),
        );
        await request.response.close();
      });
      targetUri = httpServerGetUri(target);
      client = httpFactory.client.newClient();
    });
    tearDownAll(() async {
      client.close();
      await target.close();
    });

    /// Start a redirect server, call [path] through it and return the
    /// response (the target echo as json for a 200)
    Future<HttpClientResponse> redirect(
      Options options, {
      String path = '',
      Map<String, String>? headers,
    }) async {
      var server = await HttpRedirectServer.startServer(
        httpFactory: httpFactory,
        options: options
          ..host = localhost
          ..port = 0,
      );
      try {
        return await httpClientSend(
          client,
          httpMethodGet,
          httpServerGetUri(server.httpServer).resolve(path),
          headers: headers,
        );
      } finally {
        await server.close();
      }
    }

    Map<String, Object?> echoHeaders(HttpClientResponse response) =>
        (jsonDecode(response.body) as Map)['headers'] as Map<String, Object?>;
    Uri echoUri(HttpClientResponse response) =>
        Uri.parse((jsonDecode(response.body) as Map)['uri'] as String);

    test('forward all headers without cors', () async {
      var response = await redirect(
        Options()
          ..handleCors = false
          ..baseUrl = targetUri.toString(),
        headers: {'x-custom': 'value1', 'authorization': 'Bearer 1'},
      );
      expect(response.statusCode, 200, reason: response.body);
      var headers = echoHeaders(response);
      expect(headers['x-custom'], 'value1');
      expect(headers['authorization'], 'Bearer 1');
    });

    test('forward cors headers only with cors', () async {
      var response = await redirect(
        Options()..baseUrl = targetUri.toString(),
        headers: {'x-custom': 'value1', 'authorization': 'Bearer 1'},
      );
      var headers = echoHeaders(response);
      expect(headers['x-custom'], isNull);
      expect(headers['authorization'], 'Bearer 1');
    });

    test('forwardHeaders false', () async {
      for (var handleCors in [true, false]) {
        var response = await redirect(
          Options()
            ..handleCors = handleCors
            ..forwardHeaders = false
            ..baseUrl = targetUri.toString(),
          headers: {
            'x-custom': 'value1',
            'authorization': 'Bearer 1',
            'x-tekartik-forward-x-other': 'value2',
          },
        );
        var headers = echoHeaders(response);
        expect(headers['x-custom'], isNull);
        expect(headers['authorization'], isNull);
        // Explicitly forwarded
        expect(headers['x-other'], 'value2');
      }
    });

    test('redirect query parameters not forwarded', () async {
      var response = await redirect(
        Options(),
        path:
            '/sub?a=1&$redirectBaseUrlHeader=${Uri.encodeComponent(targetUri.toString())}',
      );
      expect(response.statusCode, 200, reason: response.body);
      var uri = echoUri(response);
      expect(uri.path, '/sub');
      expect(uri.queryParametersAll, {
        'a': ['1'],
      });
    });

    test('no query parameters', () async {
      var response = await redirect(
        Options()..baseUrl = targetUri.toString(),
        path: '/sub',
      );
      var uri = echoUri(response);
      expect(uri.path, '/sub');
      expect(uri.hasQuery, isFalse);
      expect(uri.toString(), endsWith('/sub'));
    });

    test('missing redirect header and no base url', () async {
      for (var path in ['', '/', '/some/path']) {
        var response = await redirect(
          Options()..allowMissingRedirectHeader = true,
          path: path,
        ).timeout(const Duration(seconds: 10));
        expect(response.statusCode, 400, reason: '$path ${response.body}');
        expect(response.body, contains('missing'));
      }
      var response = await redirect(Options(), path: '/some/path');
      expect(response.statusCode, 405);
    });
  });
}
