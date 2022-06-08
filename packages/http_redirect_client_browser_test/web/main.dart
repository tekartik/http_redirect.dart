import 'package:http/http.dart';
import 'package:tekartik_http_redirect/http_redirect_client.dart';
import 'package:tekartik_test_menu_browser/test_menu_mdl_browser.dart';
//import '

Future<void> main() async {
  await initTestMenuBrowser();

  menu('main', () {
    item('prompt', () async {
      write('RESULT prompt: ${await prompt('Some text please then [ENTER]')}');
    });
    item('call_echo_8501_through_redirect_8180', () async {
      var client = Client();
      var redirectClient = RedirectClient(client,
          redirectServerUri: Uri.parse('http://localhost:8180'));
      write(await redirectClient
          .read(Uri.parse('http://localhost:8501?body=my_body')));
    });
    item('call_echo_8501', () async {
      var client = Client();
      write(await client.read(Uri.parse('http://localhost:8501?body=my_body')));
    });
    menu('sub', () {
      item('print hi', () => print('hi'));
    });
  });
}
