import 'package:tekartik_http_firestore_redirect/src/import.dart';

class FsRequest extends CvFirestoreDocumentBase with WithServerTimestampMixin {
  final url = CvField<String>('url');
  final method = CvField<String>('method');
  final body = CvField<Blob>('body');
  // Raw map kept as is (any stored map type, fill and tests rely on it)
  // ignore: strict_raw_type
  final headers = CvField<Map>('headers');
  @override
  List<CvField> get fields => [...timedMixinFields, url, method, body, headers];
}
