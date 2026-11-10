/// Service side of the http over firestore tunnel: a [RedirectorService]
/// performs the calls written in firestore by the clients of
/// `newHttpClientFactoryToFirestore` (`http_to_firestore.dart`) and writes the
/// responses back.
library;

export 'src/firestore/firestore_to_http_redirector.dart'
    show RedirectorService, Redirector;
