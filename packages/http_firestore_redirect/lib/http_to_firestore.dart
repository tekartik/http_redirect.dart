import 'package:tekartik_firebase_firestore/firestore.dart';
import 'package:tekartik_http/http.dart';

import 'src/firestore/http_to_firestore_client.dart' as _impl;

/// Create a new firestore client (only one needed).
HttpClientFactory newHttpClientFactoryToFirestore(
        {required String path, required Firestore firestore}) =>
    _impl.HttpClientFactoryFirestore(firestore: firestore, path: path);
