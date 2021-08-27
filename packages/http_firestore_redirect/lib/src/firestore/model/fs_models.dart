import 'package:tekartik_http_firestore_redirect/src/firestore/model/fs_request.dart';
import 'package:tekartik_http_firestore_redirect/src/firestore/model/fs_response.dart';
import 'package:tekartik_http_firestore_redirect/src/import.dart';

var _initialized = false;
void initFirestoreBuilders() {
  if (!_initialized) {
    _initialized = true;
    cvAddBuilder<CvResponseError>((_) => CvResponseError());
    cvAddBuilder<FsResponse>((_) => FsResponse());
    cvAddBuilder<FsRequest>((_) => FsRequest());
    cvAddBuilder<CvMapModel>((_) => CvMapModel());
  }
}
