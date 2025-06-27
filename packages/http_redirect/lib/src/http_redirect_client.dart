// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:tekartik_http/http.dart';
import 'package:tekartik_http_redirect/src/http_redirect_common.dart';

/// An HTTP client wrapper that automatically call a redirect server.
class RedirectClientUsingHeaders extends BaseClient {
  /// The wrapped client.
  final Client _inner;

  /// Creates a client wrapping [_inner] that wrap HTTP requests to a redirect server
  RedirectClientUsingHeaders(this._inner, {required this.redirectServerUri});

  final Uri redirectServerUri;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final splitter = StreamSplitter(request.finalize());

    var response = await _inner.send(_copyRequest(request, splitter.split()));
    return response;
  }

  /// Returns a copy of [original] with the given [body].
  StreamedRequest _copyRequest(BaseRequest original, Stream<List<int>> body) {
    final request = StreamedRequest(original.method, redirectServerUri)
      ..contentLength = original.contentLength
      ..followRedirects = original.followRedirects
      ..headers.addAll(original.headers)
      ..headers.addAll({redirectUrlHeader: original.url.toString()})
      ..maxRedirects = original.maxRedirects
      ..persistentConnection = original.persistentConnection;

    body.listen(
      request.sink.add,
      onError: request.sink.addError,
      onDone: request.sink.close,
      cancelOnError: true,
    );

    return request;
  }

  @override
  void close() => _inner.close();
}

/// Using query parameter
class RedirectClient extends BaseClient {
  /// The wrapped client.
  final Client _inner;

  /// List of forwarded headers are set in the request using the
  /// x-tekartik-forward- prefix.
  final List<String>? forwardedRequestHeaders;

  /// Creates a client wrapping [_inner] that wrap HTTP requests to a redirect server
  RedirectClient(
    this._inner, {
    required this.redirectServerUri,
    this.forwardedRequestHeaders,
  });

  final Uri redirectServerUri;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final splitter = StreamSplitter(request.finalize());

    var response = await _inner.send(_copyRequest(request, splitter.split()));
    return response;
  }

  /// Returns a copy of [original] with the given [body].
  StreamedRequest _copyRequest(BaseRequest original, Stream<List<int>> body) {
    var headers = Map<String, String>.from(original.headers);
    if (forwardedRequestHeaders != null) {
      headers = redirectClientConvertRequestHeaders(
        headers,
        forwardedRequestHeaders!,
      );
    }
    headers[redirectUrlHeader] = original.url.toString();
    final request =
        StreamedRequest(
            original.method,
            redirectServerUri.replace(
              queryParameters: <String, dynamic>{}
                ..addAll(redirectServerUri.queryParameters),
            ),
          )
          // needed, maybe add an use query param option in the future
          //          ..[redirectUrlHeader] = original.url.toString())
          ..contentLength = original.contentLength
          ..followRedirects = original.followRedirects
          ..headers.addAll(headers)
          ..maxRedirects = original.maxRedirects
          ..persistentConnection = original.persistentConnection;

    body.listen(
      request.sink.add,
      onError: request.sink.addError,
      onDone: request.sink.close,
      cancelOnError: true,
    );

    return request;
  }

  @override
  void close() => _inner.close();
}

/// Redirect client factory
class RedirectClientFactory implements HttpClientFactory {
  final Uri redirectServerUri;
  final HttpClientFactory _inner;

  /// List of forwarded headers are set in the request using the
  /// x-tekartik-forward- prefix.
  final List<String>? forwardedRequestHeaders;

  RedirectClientFactory(
    this._inner, {
    required this.redirectServerUri,
    this.forwardedRequestHeaders,
  });

  @override
  Client newClient() {
    return RedirectClient(
      _inner.newClient(),
      redirectServerUri: redirectServerUri,
      forwardedRequestHeaders: forwardedRequestHeaders,
    );
  }
}
