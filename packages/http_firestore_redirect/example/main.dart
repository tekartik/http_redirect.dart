// Both sides of the tunnel in one process, on a memory firestore and a memory
// http server. In a real setup the RedirectorService runs where the target
// is reachable (a server, a desktop tool, with httpFactoryIo.client) and the
// caller anywhere the same firestore project is, both on the same path.
import 'package:tekartik_app_http/app_http.dart';
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:tekartik_http_firestore_redirect/firestore_to_http_redirect.dart';
import 'package:tekartik_http_firestore_redirect/http_to_firestore.dart';

Future<void> main() async {
  var firestore = newFirestoreMemory();
  // A firestore document path, the same on both sides.
  var path = 'redirect/example';

  // The target: an http server only the service side can reach.
  var target = await httpFactoryMemory.server.bind(localhost, 0);
  target.listen((request) async {
    request.response.write('hello from ${request.uri.path}');
    await request.response.close();
  });

  // Service side: performs the calls written in firestore.
  var service = RedirectorService(
    Redirector('example', httpServerGetUri(target).toString()),
    firestore: firestore,
    path: path,
    httpClientFactory: httpFactoryMemory.client,
  );
  await service.start();

  // Caller side: a normal package:http client.
  var client = newHttpClientFactoryToFirestore(
    firestore: firestore,
    path: path,
  ).newClient();
  // A relative url is joined to the service's base url.
  var text = await client.read(Uri.parse('greeting'));
  // ignore: avoid_print
  print(text); // hello from /greeting

  client.close();
  service.stop();
  await target.close();
}
