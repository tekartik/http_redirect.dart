import 'package:tekartik_http/http.dart';

/// Header for base url
const String redirectBaseUrlHeader = 'x-tekartik-redirect-base-url';

/// Header for full url
const String redirectUrlHeader = 'x-tekartik-redirect-url';

/// ?x-help to print help messages
const String redirectHelpKey = 'x-tekartik-redirect-help';

/// Converted headers
const String redirectForwardKeyPrefix = 'x-tekartik-forward-';

/// Renames the [headers] named in [forwarderHeaders] with the
/// `x-tekartik-forward-` prefix (lower case name), header names being case
/// insensitive. Returns [headers] when none is renamed.
Map<String, String> redirectClientConvertRequestHeaders(
  Map<String, String> headers,
  List<String> forwarderHeaders,
) {
  var lowerCaseForwarderHeaders = forwarderHeaders
      .map((name) => name.toLowerCase())
      .toSet();
  Map<String, String>? convertedHeaders;
  headers.forEach((String name, String value) {
    var lowerCaseName = name.toLowerCase();
    if (lowerCaseForwarderHeaders.contains(lowerCaseName)) {
      convertedHeaders ??= Map<String, String>.from(headers);
      convertedHeaders!.remove(name);
      convertedHeaders!['$redirectForwardKeyPrefix$lowerCaseName'] = value;
    }
  });
  return convertedHeaders ?? headers;
}

Map<String, String> redirectServerConvertRequestHeaders(HttpHeaders headers) {
  var convertedHeaders = <String, String>{};
  headers.forEach((String name, List<String> values) {
    name = name.toLowerCase();
    if (name.startsWith(redirectForwardKeyPrefix)) {
      name = name.substring(redirectForwardKeyPrefix.length);
      var value = values.join(',');
      convertedHeaders[name] = value;
    }
  });
  return convertedHeaders;
}
