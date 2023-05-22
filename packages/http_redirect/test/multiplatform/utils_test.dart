import 'package:tekartik_http/src/http_client_memory.dart';
import 'package:tekartik_http_redirect/src/http_redirect_common.dart';
import 'package:test/test.dart';

void main() {
  test('redirectClientConvertRequestHeaders', () {
    expect(redirectClientConvertRequestHeaders({}, []), <String, String>{});
    expect(redirectClientConvertRequestHeaders({}, ['a']), <String, String>{});
    expect(redirectClientConvertRequestHeaders({'a': '1'}, []),
        <String, String>{'a': '1'});
    expect(redirectClientConvertRequestHeaders({'a': '1', 'b': '2'}, ['a']),
        <String, String>{'x-tekartik-forward-a': '1', 'b': '2'});
  });

  test('redirectServerConvertRequestHeaders', () {
    expect(redirectServerConvertRequestHeaders(HttpHeadersMemory()),
        <String, String>{});
    expect(
        redirectServerConvertRequestHeaders(HttpHeadersMemory()..set('a', '1')),
        <String, String>{});
    expect(
        redirectServerConvertRequestHeaders(
            HttpHeadersMemory()..set('x-tekartik-forward-a', '1')),
        <String, String>{'a': '1'});
  });
}
