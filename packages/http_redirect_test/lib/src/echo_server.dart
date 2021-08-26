import 'dart:typed_data';

import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_http/http.dart';

/// Use port 0 for automatic
///
/// Add x-echo-request-uri in response
Future<HttpServer> serveEchoParams(HttpServerFactory factory, int port) async {
  var server = await factory.bind(localhost, port);
  server.listen((request) async {
    var statusCode = parseInt(request.uri.queryParameters['statusCode']);

    request.response.headers.contentType =
        ContentType.parse(httpContentTypeText);
    dynamic body = request.uri.queryParameters['body'];
    if (body == null) {
      try {
        body = await request.getBodyBytes();
      } catch (e) {
        print('error reading body');
      }
    } else {
      body = utf8.encode(body as String);
    }
    if (statusCode != null) {
      request.response.statusCode = statusCode;
    }
    // devPrint('### ${request.uri}');
    request.response.headers.add('x-echo-request-uri', request.uri.toString());

    if (body != null) {
      if (body is String) {
        request.response.write(body);
      } else {
        request.response.add(body as Uint8List);
      }
    } else {
// needed for node
      request.response.write('');
    }

    await request.response.close();
  });
  var uri = httpServerGetUri(server);
  print('simple body <$uri?body=test>');
  print('Failed <$uri?body=test&statusCode=400>');
  return server;
}
