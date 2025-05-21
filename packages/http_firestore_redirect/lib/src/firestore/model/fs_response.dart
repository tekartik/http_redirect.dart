import 'package:tekartik_http_firestore_redirect/src/import.dart';

/// Error in response
class CvResponseError extends CvModelBase {
  /// Error message
  final message = CvField<String>('message');
  @override
  List<CvField> get fields => [message];
}

/// Response
class FsResponse extends CvFirestoreDocumentBase with WithServerTimestampMixin {
  final statusCode = CvField<int>('statusCode');
  final body = CvField<Blob>('body');
  final url = CvField<String>('url');
  final error = CvModelField<CvResponseError>('error');
  final headers = CvField<Map>('headers');
  @override
  List<CvField> get fields => [
    ...timedMixinFields,
    statusCode,
    body,
    url,
    error,
    headers,
  ];
}
