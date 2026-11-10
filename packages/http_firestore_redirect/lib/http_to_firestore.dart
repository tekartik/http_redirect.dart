/// Caller side of the http over firestore tunnel:
/// [newHttpClientFactoryToFirestore].
library;

import 'package:tekartik_http_firestore_redirect/src/import.dart';

import 'src/firestore/http_to_firestore_client.dart' as impl;

/// A factory of `package:http` clients whose calls go through [firestore]:
/// written to `<path>/request/<id>`, performed by the `RedirectorService`
/// listening on the same [path] (a firestore document path), answered in
/// `<path>/response/<id>`. One factory is enough for an app.
///
/// A call fails with a `TimeoutException` after 30 seconds when no service
/// answers, with an `http.ClientException` when the service could not reach
/// the url.
HttpClientFactory newHttpClientFactoryToFirestore({
  required String path,
  required Firestore firestore,
}) => impl.HttpClientFactoryFirestore(firestore: firestore, path: path);
