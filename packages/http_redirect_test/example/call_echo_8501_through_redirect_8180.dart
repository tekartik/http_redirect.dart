import 'package:http/http.dart';
import 'package:tekartik_http_redirect/http_redirect_client.dart';

// Run
// - echo_server_8501.dart
// - no_cors_header.dart
// curl http://localhost:8180
// curl http://localhost:8501
Future<void> main() async {
  var client = Client();
  print(await client.read(Uri.parse('http://localhost:8501?body=my_body')));

  var redirectClient = RedirectClient(client,
      redirectServerUri: Uri.parse('http://localhost:8180'));
  print(await redirectClient
      .read(Uri.parse('http://localhost:8501?body=my_body')));
}
