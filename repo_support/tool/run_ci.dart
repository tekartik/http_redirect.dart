import 'package:dev_test/package.dart';
import 'package:path/path.dart';

Future main() async {
  for (var dir in [
    'http_firestore_redirect',
    'http_redirect',
    'http_redirect_test',
    'http_redirect_client_browser_test',
  ]) {
    await packageRunCi(join('..', 'packages', dir));
  }
}
