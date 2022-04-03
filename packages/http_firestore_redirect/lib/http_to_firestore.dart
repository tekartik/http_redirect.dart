import 'package:tekartik_http_firestore_redirect/src/import.dart';

import 'src/firestore/http_to_firestore_client.dart' as impl;

/// Create a new firestore client (only one needed).
HttpClientFactory newHttpClientFactoryToFirestore(
        {required String path, required Firestore firestore}) =>
    impl.HttpClientFactoryFirestore(firestore: firestore, path: path);
