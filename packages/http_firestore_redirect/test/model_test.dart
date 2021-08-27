import 'package:cv/cv.dart';
import 'package:tekartik_firebase_firestore/firestore.dart';
import 'package:tekartik_http_firestore_redirect/src/firestore/model/fs_models.dart';
import 'package:tekartik_http_firestore_redirect/src/firestore/model/fs_request.dart';
import 'package:tekartik_http_firestore_redirect/src/firestore/model/fs_response.dart';
import 'package:tekartik_http_firestore_redirect/src/import.dart';
import 'package:test/test.dart';

CvFillOptions get firestoreFillOptions => CvFillOptions(
    valueStart: 0,
    collectionSize: 1,
    generate: (type, options) {
      if (options.valueStart != null) {
        if (type == Timestamp) {
          var value = options.valueStart = options.valueStart! + 1;
          return Timestamp(value, 0);
        } else if (type == Map) {
          var value = options.valueStart = options.valueStart! + 1;
          return <String, Object?>{'value': value};
        } else if (type == Blob) {
          var value = options.valueStart = options.valueStart! + 1;
          return Blob(Uint8List.fromList(
              List<int>.generate(value, (index) => index % 256)));
        }
      }
      return null;
    });
CvFillOptions get fillOptions => firestoreFillOptions;
void main() {
  initFirestoreBuilders();
  group('fs_request', () {
    test('fields', () {
      var doc = FsRequest()..fillModel(fillOptions);
      expect(doc.toMap(), {
        'timestamp': Timestamp(1, 0),
        'url': 'text_2',
        'method': 'text_3',
        'body': Blob.fromList([0, 1, 2, 3]),
        'headers': {'value': 5}
      });
    });
  });
  group('fs_response', () {
    test('fields', () {
      var doc = FsResponse()..fillModel(fillOptions);
      expect(doc.toMap(), {
        'timestamp': Timestamp(1, 0),
        'statusCode': 2,
        'body': Blob.fromList([0, 1, 2]),
        'url': 'text_4',
        'error': {'message': 'text_5'},
        'headers': {'value': 6}
      });
    });
  });
}
