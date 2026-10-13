import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_common_utils/log_utils.dart';
import 'package:tekartik_http/http.dart';
import 'package:tekartik_http_redirect/src/http_redirect_common.dart';
import 'package:tekartik_http_redirect/src/http_redirect_server.dart';

export 'src/http_redirect_common.dart'
    show
        redirectUrlHeader,
        redirectBaseUrlHeader,
        redirectServerConvertRequestHeaders,
        redirectClientConvertRequestHeaders;
export 'src/http_redirect_server.dart' show HttpRedirectServer;

Level? logLevel;

// request
const String hostHeader = 'host';

void _log(Object? object) {
  // ignore: avoid_print
  print(object);
}

/// Proxy the HTTP request to the specified server.
///
/// The target is [uri] if set, otherwise the request path relative to
/// [baseUrl]. Throws an [ArgumentError] if there is no target.
///
/// Request headers forwarded:
/// - only the ones in [Options.forwardedHeaders] if set
/// - otherwise, if [Options.forwardHeaders] is true (default), the CORS headers
///   when [Options.handleCors] is true (default), all the headers otherwise
/// - `x-tekartik-forward-<name>` headers are always forwarded as `<name>`.
///
/// The host and redirect headers are never forwarded, neither are the
/// `x-tekartik-redirect-*` query parameters.
Future<void> proxyHttpRequest(
  Options options,
  HttpRequest request,
  String? baseUrl, {
  Uri? uri,
  required http.Client client,
}) async {
  if (uri == null) {
    var path = request.uri.path;
    if (path.startsWith('/')) {
      path = path.substring(1);
    }

    if (baseUrl == null) {
      // Never redirect to the redirect server itself
      throw ArgumentError.value(
        baseUrl,
        'baseUrl',
        'no redirect url (missing $redirectBaseUrlHeader or $redirectUrlHeader)',
      );
    }
    // print('baseUrl: $baseUrl, path: $path, headers: ${request.headers}');
    String url;
    if (path == '' || path == '.' || path == '/') {
      url = baseUrl;
    } else {
      url = p.url.join(baseUrl, path);
      // print('baseUrl: $baseUrl, path: $path, url $url');
    }
    uri = Uri.parse(url);
  }

  if (options.forwardArguments) {
    // Fix arguments, the redirect parameters are not forwarded
    var queryParameters = <String, List<String>>{
      ...uri.queryParametersAll,
      for (var entry in request.uri.queryParametersAll.entries)
        if (!_isRedirectParameter(entry.key)) entry.key: entry.value,
    };
    if (queryParameters.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParameters);
    }
  }

  if (debugHttpRedirectServer) {
    _log('calling ${request.method} $uri');
  }

  final headers = <String, String>{};

  request.headers.forEach((name, List<String> values) {
    void setValues() {
      headers[name] = values.join(',');
    }

    if (options.forwardedHeaders != null) {
      for (var forwardedHeaders in options.forwardedHeaders!) {
        if (forwardedHeaders.toLowerCase() == name.toLowerCase()) {
          setValues();
        }
      }
      return;
    }
    if (name == hostHeader) {
      // don't forward host (likely localhost: 8180)
      // needed for google storage
      return;
    }
    if (name.startsWith(redirectForwardKeyPrefix)) {
      var forwardedName = name.substring(redirectForwardKeyPrefix.length);
      headers[forwardedName] = values.join(',');
      return;
    }
    // don't forward redirect urls
    if (_isRedirectParameter(name) || name == '_tekartik_redirect_host') {
      return;
    }
    if (!options.forwardHeaders) {
      return;
    }
    if (options.handleCors) {
      if (options.containsHeader(name)) {
        setValues();
      }
    } else {
      setValues();
    }
  });
  // print('headers: $headers');

  var bytes = <int>[];
  for (var list in await request.toList()) {
    bytes.addAll(list);
  }

  // if ((!options.forwardHeaders) || false) {
  //  headers = null;
  // }

  var innerResponse = await httpClientSend(
    client,
    request.method,
    uri,
    body: bytes,
    headers: headers,
  );
  var innerBody = innerResponse.bodyBytes;
  var innerHeaders = innerResponse.headers;

  // final HttpClientRequest rq = await _client.openUrl(request.method, uri);

  // rq.contentLength = request.contentLength == null ? -1 : request.contentLength;
  /*
  rq
    ..followRedirects = request.
    ..maxRedirects = request.maxRedirects;
*/
  // await rq.addStream(request);
  // final HttpClientResponse rs = await rq.close();
  final r = request.response;

  r.statusCode = innerResponse.statusCode;
  // print('response: ${r.statusCode}');
  // print('response headers: ${innerResponse.headers}');

  innerHeaders.forEach((key, values) {
    final lowercaseKey = key.toLowerCase();
    if (lowercaseKey == 'content-length') {
      return;
    }
    if (lowercaseKey == 'content-encoding') {
      return;
    }
    r.headers.set(key, values);
  });
  // r.contentLength = rs.contentLength == null ? -1 : rs.contentLength;
  // r.headers.contentType = ContentType.parse(innerResponse.headers[httpHeaderContentType]); //.contentType;
  // print('fwd response headers: ${r.headers}');
  r.headers.set(redirectUrlHeader, uri.toString());

  // devPrint('out $innerBody');
  try {
    if (innerBody.isNotEmpty) {
      r.add(innerBody);
    }
  } catch (e, st) {
    _log('Error writing body $e');
    if (debugHttpRedirectServer) {
      _log(st);
    }
    rethrow;
  }
  // devPrint('flush');
  try {
    await r.flush();
  } catch (e, st) {
    _log('Error flushing $e');
    if (debugHttpRedirectServer) {
      _log(st);
    }
  }

  // devPrint('closing');
  try {
    await r.close();
  } catch (e, st) {
    _log('Error closing $e');
    if (debugHttpRedirectServer) {
      _log(st);
    }
  }
  // devPrint('done');
}

/// x-tekartik-redirect-* header or query parameter
bool _isRedirectParameter(String name) =>
    name.toLowerCase().startsWith('x-tekartik-redirect-');

class Options {
  var handleCors = true;

  /// Forward the request headers (the CORS headers when [handleCors] is true),
  /// see [proxyHttpRequest].
  var forwardHeaders = true;
  var forwardArguments = true;
  int? port;
  Object? host;

  List<String>? forwardedHeaders;

  bool allowMissingRedirectHeader = false;

  bool containsHeader(String name) {
    if (_corsHeaders == null) {
      corsHeaders = corsDefaultHeaders;
    }
    return _lowerCaseCorsHeaders.contains(name.toLowerCase());
  }

  // The default url to redirect too
  String? baseUrl;

  set corsHeaders(List<String> corsHeaders) {
    corsHeaders = _corsHeaders = List<String>.from(corsHeaders);
    corsHeaders.add(redirectBaseUrlHeader);
    corsHeaders.add(redirectUrlHeader);
    _lowerCaseCorsHeaders = <String>[];
    for (var name in corsHeaders) {
      _lowerCaseCorsHeaders.add(name.toLowerCase());
    }
  }

  List<String> get corsHeaders => _corsHeaders!;

  List<String>? _corsHeaders;
  late List<String> _lowerCaseCorsHeaders;
  String? _corsHeadersText;

  String get corsHeadersText => _corsHeadersText ??= () {
    if (_corsHeaders == null) {
      corsHeaders = corsDefaultHeaders;
    }
    return corsHeaders.join(',');
  }();
}

/// start http redirect server
@Deprecated('Use Redirect server')
Future<HttpServer> startServer(
  HttpServerFactory factory,
  Options options,
) async {
  var host = options.host ?? InternetAddress.anyIPv4;
  var port = options.port ?? 8180;
  final server = await factory.bind(host, port);
  _log('listening on $host port $port');
  _log('from ${httpServerGetUri(server)}');
  if (options.baseUrl != null) {
    _log('default redirection to ${options.baseUrl}');
  }
  http.Client? client;
  server.listen((request) async {
    await redirectServerHandleRequest(
      options,
      request,
      () => client ??= http.Client(),
    );
  });
  return server;
}

var corsDefaultHeaders = [
  'Origin',
  'Content-Type',
  'Authorization',
  'Accept',
  'Connection',
  'Content-length',
  'Host',
  'User-Agent',
];
