import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:tekartik_http/http.dart';
import 'package:tekartik_http/http_memory.dart';
import 'package:tekartik_http_redirect/http_redirect.dart';
import 'package:tekartik_http_redirect_test/src/echo_server.dart';
import 'package:test/test.dart';

void main() {
  run(httpFactory: httpFactoryMemory);
  runHttpRedirectTest(httpFactory: httpFactoryMemory);
}

/*
void main() {
  var firestore = newFirestoreMemory();
  var httpFactory = httpFactoryMemory;
  run(httpFactory: httpFactory, firestore: firestore);
}
*/
void runHttpRedirectTest(
    {required HttpFactory httpFactory,
    HttpFactory? testServerHttpFactory,
    HttpClientFactory? outboundHttpClientFactory,
    Uri? overridenClientUri}) {
  final httpClientFactory = httpFactory.client;
  final httpServerFactory = httpFactory.server;

  var targetServerHttpFactory = testServerHttpFactory ?? httpFactory;
  outboundHttpClientFactory ??= targetServerHttpFactory.client;
  group(
    'http_redirect_test',
    () {
      late HttpServer server;
      late http.Client client;
      late HttpRedirectServer httpRedirectServer;
      late Uri redirectUri;
      late Uri clientUri;
      setUpAll(() async {
        server = await serveEchoParams(targetServerHttpFactory.server, 0);
        var uri = httpServerGetUri(server);
        // devPrint('serverUri: $uri');
        /*if (newClientFactory != null) {
          newClientFactory = newClientFactory();
        }*/
        client = (outboundHttpClientFactory ?? httpClientFactory).newClient();
        httpRedirectServer = await HttpRedirectServer.startServer(
            httpClientFactory: outboundHttpClientFactory,
            httpServerFactory: httpServerFactory,
            options: Options()
              ..host = localhost
              ..port = 0
              ..baseUrl = uri.toString());
        redirectUri = httpServerGetUri(httpRedirectServer.httpServer);
        clientUri = overridenClientUri ?? redirectUri;
      });
      tearDownAll(() async {
        client.close();
        await server.close();
      });

      test('defaultStatusCode', () async {
        var uri = httpServerGetUri(server);
        expect(uri, isNot(clientUri));

        // devPrint(uri);
        // devPrint(redirectUri);
        var response = await httpClientSend(
            client, httpMethodGet, Uri.parse('$clientUri?statusCode=none'));
        expect(response.isSuccessful, isTrue);

        expect(response.statusCode, 200);
        //expect(response.toString(), startsWith('HTTP 200'));
        expect(response.toString(), startsWith('HTTP 200'));
      });

      test('success', () async {
        var response = await httpClientSend(
            client, httpMethodGet, Uri.parse('$clientUri?statusCode=200'));
        expect(response.isSuccessful, isTrue);

        expect(response.toString().startsWith('HTTP 200 size 0 headers '),
            isTrue); // 0');
      });

      test(
        'failure',
        () async {
          var response = await httpClientSend(
              client, httpMethodGet, Uri.parse('$clientUri?statusCode=400'));
          expect(response.isSuccessful, isFalse);
          expect(response.statusCode, 400);
        },
        // solo: true,
      );

      test('path', () async {
        var response = await httpClientSend(client, httpMethodGet,
            Uri.parse(url.join(redirectUri.toString(), 'some/path')));
        expect(response.isSuccessful, isTrue);
        expect(Uri.parse(response.headers['x-echo-request-uri']!).path,
            endsWith('/some/path'));
      });

      test('forwardArguments', () async {
        var result = await httpClientRead(
            client, httpMethodGet, Uri.parse('$clientUri?body=test'));
        expect(result, 'test');
      });

      test(
        'failure_throw',
        () async {
          try {
            await httpClientSend(client, httpMethodGet,
                Uri.parse('$clientUri?statusCode=400&body=test'),
                throwOnFailure: true);
            fail('should fail');
          } on HttpClientException catch (e) {
            expect(e.statusCode, 400);
            expect(e.response.statusCode, 400);
            expect(e.response.body, 'test');
          }
        },
      );

      test('port', () async {
        var server1 =
            await httpServerFactory.bind(InternetAddress.any, httpPortAny);
        var port1 = server1.port;
        var server2 =
            await httpServerFactory.bind(InternetAddress.any, httpPortAny);
        var port2 = server2.port;
        expect(port1, isNot(port2));
      });

      test('httpClientRead1', () async {
        var result = await httpClientRead(client, httpMethodGet,
            Uri.parse('$clientUri?statusCode=200&body=test'));
        expect(result, 'test');
      });

      test('httpClientRead2', () async {
        try {
          await httpClientRead(client, httpMethodGet,
              Uri.parse('$clientUri?statusCode=400&body=test'));
          fail('should fail');
        } on HttpClientException catch (e) {
          expect(e.statusCode, 400);
          expect(e.response.statusCode, 400);
          expect(e.response.body, 'test');
        }
      });

      test('httpClientReadEncoding', () async {
        var body = Uri.encodeComponent('é');
        var bytes = await httpClientReadBytes(
            client, httpMethodGet, Uri.parse('$clientUri?body=$body'));
        expect(bytes, [195, 169]);
        try {
          expect(
              await httpClientRead(
                  client, httpMethodGet, Uri.parse('$clientUri?body=$body')),
              'Ã©');
        } catch (_) {
          // failing on io...
          expect(
              await httpClientRead(
                  client, httpMethodGet, Uri.parse('$clientUri?body=$body')),
              'é');
        }
        expect(
            await httpClientRead(
                client, httpMethodGet, Uri.parse('$clientUri?body=$body'),
                responseEncoding: utf8),
            'é');
      });

      tearDownAll(() async {
        client.close();
        await server.close();
      });
    },
  );

  /*
  group('server_request_fragment', () {
    test('fragment', () async {
      var server = await httpServerFactory.bind(InternetAddress.anyIPv4, 0);
      server.listen((request) async {
        request.response.write(request.uri.fragment);
        await request.response.close();
      });
      var client = httpClientFactory.newClient();
      var response = await client.get(
          Uri.parse('${httpServerGetUri(server)}/some_path#some_fragment'));
      expect(response.body, '');
      expect(response.statusCode, 200);
      client.close();
      await server.close();
    });
  });

  group('server_request_bytes_response_bytes', () {
    test('fragment', () async {
      var server = await httpServerFactory.bind(localhost, 0);
      server.listen((request) async {
        var bytes = await httpStreamGetBytes(request);
        request.response.add(bytes);
        await request.response.close();
      });
      var client = httpClientFactory.newClient();
      var response = await client.post(Uri.parse('${httpServerGetUri(server)}'),
          body: Uint8List.fromList([1, 2, 3]));
      expect(response.bodyBytes, [1, 2, 3]);
      expect(response.statusCode, 200);
      client.close();
      await server.close();
    });
  });

  group('server_request_response_headers', () {
    test('headers', () async {
      var server = await httpServerFactory.bind(InternetAddress.anyIPv4, 0);
      server.listen((request) async {
        expect(request.headers.value('x-test'), 'test_value');
        expect(request.headers.value('X-Test'), 'test_value');
        expect(request.headers['x-test'], ['test_value']);
        expect(request.headers['X-Test'], ['test_value']);
        request.response.headers.set('x-test', 'test_value');
        request.response.statusCode = 200;
        await request.response.close();
      });
      var client = httpClientFactory.newClient();
      var response = await httpClientSend(client, httpMethodGet,
          httpServerGetUri(server), // 'http://127.0.0.1:${server.port}',
          //var response = await client.get('http://127.0.0.1:${server.port}',
          headers: <String, String>{'x-test': 'test_value'});
      expect(response.statusCode, 200);
      expect(response.headers.value('x-test'), 'test_value');
      expect(response.headers.value('X-Test'), 'test_value');
      expect(response.headers['x-test'], 'test_value');
      expect(response.headers['X-Test'], 'test_value');
      client.close();
      await server.close();
    });
  });
  group('client_server', () {
    late HttpServer server;
    late http.Client client;

    var host = '127.0.0.1';
    late String url;
    setUpAll(() async {
      server = await httpServerFactory.bind(host, 0);
      url = 'http://$host:${server.port}';

      server.listen((request) async {
        final body = await utf8.decoder.bind(request).join();
        request.response.headers.contentType =
            ContentType.parse(httpContentTypeText);
        request.response.headers.set('X-Foo', 'bar');
        request.response.headers.set(
            'set-cookie', ['JSESSIONID=verylongid; Path=/somepath; HttpOnly']);
        request.response.statusCode = 200;
        // devPrint('body ${body} ${body.length}');
        if (body.isNotEmpty) {
          request.response.write(body);
        } else {
          request.response.write('ok');
        }
        await request.response.close();
      });
      client = httpClientFactory.newClient();
    });

    tearDownAll(() async {
      client.close();
      await server.close();
    });

    test('make get request', () async {
      var client = httpClientFactory.newClient();
      var response = await client.get(Uri.parse(url));
      expect(response.statusCode, 200);
      expect(response.contentLength, greaterThan(0));
      expect(response.body, equals('ok'));
      expect(response.headers, contains('content-type'));
      expect(response.headers['set-cookie'],
          'JSESSIONID=verylongid; Path=/somepath; HttpOnly');
      client.close();
    });

    test('make post request with a body', () async {
      var client = httpClientFactory.newClient();
      var response = await client.post(Uri.parse(url), body: 'hello');
      expect(response.statusCode, 200);
      expect(response.contentLength, greaterThan(0));
      expect(response.body, equals('hello'));
      client.close();
    });

    test('make get request with library-level get method', () async {
      var client = httpClientFactory.newClient();
      var response = await client.get(Uri.parse(url));
      // devPrint(response.headers);
      expect(response.statusCode, 200);
      expect(response.contentLength, greaterThan(0));
      expect(response.body, equals('ok'));
      expect(response.headers, contains('content-type'));
      expect(response.headers['set-cookie'],
          'JSESSIONID=verylongid; Path=/somepath; HttpOnly');
      client.close();
    });
  });

  group('response_io_sink', () {
    test('writeln', () async {
      var server = await httpServerFactory.bind(localhost, 0);
      server.listen((request) {
        request.response
          ..writeln('test')
          ..close();
      });
      var client = httpClientFactory.newClient();
      expect(await client.read(Uri.parse('http://$localhost:${server.port}')),
          'test\n');
      client.close();
      await server.close();
    });

    test('writeAll', () async {
      var server = await httpServerFactory.bind(localhost, 0);
      server.listen((request) {
        request.response
          ..writeAll(['test', true, 1], ',')
          ..close();
      });
      var client = httpClientFactory.newClient();
      expect(await client.read(Uri.parse('http://$localhost:${server.port}')),
          'test,true,1');
      client.close();
      await server.close();
    });

    // This fails on node
    test('writeCharCode', () async {
      var server = await httpServerFactory.bind(localhost, 0);
      server.listen((request) {
        request.response
          ..writeCharCode('é'.codeUnitAt(0))
          ..close();
      });
      var client = httpClientFactory.newClient();
      expect(await client.read(Uri.parse('http://$localhost:${server.port}')),
          'é');
      client.close();
      await server.close();
    }, skip: true);
  });

  test('response_stream', () async {
    var server = await httpServerFactory.bind(localhost, 0);
    server.listen((request) {
      request.response
        ..write('abc')
        ..close();
    });
    var client = httpClientFactory.newClient();
    var url = 'http://$localhost:${server.port}';
    final bytes = await client.readBytes(Uri.parse(url));
    expect(bytes, const TypeMatcher<Uint8List>());

    client.close();
    await server.close();
  });

   */
}

void run({
  HttpFactory? httpFactory,
  //HttpClientFactory? httpClientFactory,
  //HttpServerFactory? httpServerFactory,
  HttpFactory? testServerHttpFactory,
}) {
  var clientFactory = testServerHttpFactory?.client ?? httpFactory!.client;
  var serverFactory = httpFactory!.server;
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
      //devPrint('port: $port');

      var httpRedirectServer = await HttpRedirectServer.startServer(
          httpClientFactory: testServerHttpFactory?.client ?? clientFactory,
          httpServerFactory: serverFactory,
          options: Options()
            ..host = localhost
            ..port = 0
            ..baseUrl = 'http://$localhost:$port');

      var client = clientFactory.newClient();
      var redirectPort = httpRedirectServer.port;
      //devPrint('redirectPort: $redirectPort');
      expect(port, isNot(redirectPort));
      expect(await client.read(Uri.parse('http://$localhost:$port')),
          'tekartik_http_redirect');
      client.close();

      await httpRedirectServer.close();
      await httpServer.close();
    });
  });
}
