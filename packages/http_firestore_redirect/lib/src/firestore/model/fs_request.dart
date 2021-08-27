import 'package:tekartik_http_firestore_redirect/src/import.dart';

class FsRequest extends CvFirestoreDocumentBase with WithServerTimestampMixin {
  final url = CvField<String>('url');
  final method = CvField<String>('method');
  final body = CvField<Blob>('body');
  final headers = CvField<Map>('headers');
  @override
  List<CvField> get fields => [...timedMixinFields, url, method, body, headers];
}
