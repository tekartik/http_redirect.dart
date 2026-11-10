import 'package:http/http.dart' as http;
import 'package:tekartik_http_firestore_redirect/src/import.dart' as firestore;
import 'package:tekartik_http_firestore_redirect/src/import.dart' as common;
import 'package:tekartik_http_firestore_redirect/src/import.dart';

final String paramMethod = 'method';
final String paramBody = 'body';
final String paramError = 'error';
final String paramMessage = 'message';
final String paramUrl = 'url';
final String paramTimestamp = 'timestamp';
final String paramHeaders = 'headers';
final String paramStatusCode = 'statusCode'; // int response
final String httpClientFactoryFirestoreDefaultName = 'any';
final String firestoreHttpContextRequestsPartName = 'request';
final String firestoreHttpContextResponsesPartName = 'response';

var debugHttpToFirestore = false; // devWarning(true); // false

class HttpClientFactoryFirestore implements common.HttpClientFactory {
  // FirebaseService _firebaseService;

  // final firestore.FirestoreService firestoreService;
  final common.Firestore firestore;

  final String path;

  // final firebase.AppOptions? options;

  HttpClientFactoryFirestore({required this.firestore, required this.path});

  @override
  http.Client newClient() {
    return FirestoreHttpClient(this);
  }

  Future<common.Firestore> get firestoreReady async {
    await ready;
    return firestore;
  }

  Future<bool> get ready async => true;
}

typedef ResponseFirestore = http.Response;

class Request {
  String method;
  Uri url;
  Map<String, String>? headers;
  Object? body;

  Request(this.method, this.url, {this.headers, this.body});
}

String firestoreTekartikHttpCurlPath = url.join('tekartik_http'); //, 'curl');

class ResponseRequest extends http.BaseRequest {
  ResponseRequest(super.method, super.url);
}

/// A `package:http` client whose calls go through firestore: each request is
/// written to `<path>/request/<id>`, the `RedirectorService` performs it and
/// writes `<path>/response/<id>`, deleted once read.
///
/// Every `http.Client` method (`get`, `post`, `read`, `head`...) builds an
/// `http.Request` and goes through [send], as for any [http.BaseClient].
class FirestoreHttpClient extends http.BaseClient {
  final HttpClientFactoryFirestore httpContext;

  FirestoreHttpClient(this.httpContext);

  Future<firestore.Firestore> get firestoreReady async {
    // await firestoreHttpReady;
    return httpContext.firestoreReady;
  }

  /// Sends [request] through firestore and waits (30 seconds at most) for
  /// the response document.
  Future<ResponseFirestore> curl(Request request) async {
    StreamSubscription<DocumentSnapshot>? responseSubscription;

    void cancelResponseSuscription() {
      responseSubscription?.cancel();
      responseSubscription = null;
    }

    try {
      var firestore = await firestoreReady;
      var data = <String, Object?>{};

      data[paramUrl] = request.url.toString();
      data[paramMethod] = request.method;
      if (request.headers != null) {
        data[paramHeaders] = request.headers;
      }
      if (request.body != null) {
        if (request.body is Uint8List) {
          data[paramBody] = Blob(request.body as Uint8List);
        } else {
          data[paramBody] = request.body;
        }
      }
      data[paramTimestamp] = common.FieldValue.serverTimestamp;

      var docReference = firestore
          .collection(
            url.join(httpContext.path, firestoreHttpContextRequestsPartName),
          )
          .doc(AutoIdGenerator.autoId());

      var responsePath = url.join(
        httpContext.path,
        firestoreHttpContextResponsesPartName,
        docReference.id,
      );
      var responseReference = firestore.doc(responsePath);

      var responseCompleter = Completer<Model>();

      responseSubscription = responseReference.onSnapshot().listen((doc) {
        if (doc.exists) {
          var data = doc.data;
          responseCompleter.complete(data);
          cancelResponseSuscription();
        }
      });
      await docReference.set(data);

      if (debugHttpToFirestore) {
        // ignore: avoid_print
        print('[REQ] ${docReference.id} $data');
      }
      //devPrint("request ${docReference?.path} $data");

      var responseData = await responseCompleter.future.timeout(
        Duration(seconds: 30),
      );

      //devPrint("response ${responseReference?.path} $responseData");
      if (debugHttpToFirestore) {
        // ignore: avoid_print
        print('[RESP] $responseData');
      }
      cancelResponseSuscription();
      // The response document is only for this call (the redirector deletes
      // the request): delete it, best effort, without delaying the call (a
      // refused delete must not fail it).
      unawaited(() async {
        try {
          await responseReference.delete();
        } catch (e) {
          if (debugHttpToFirestore) {
            // ignore: avoid_print
            print('[RESP] delete $responsePath failed: $e');
          }
        }
      }());

      var statusCode = responseData[paramStatusCode];
      if (statusCode is! int) {
        // The redirector could not reach the url
        var error = responseData[paramError];
        var message = error is Map ? error[paramMessage] : null;
        throw http.ClientException(
          message?.toString() ?? 'no response from the redirector',
          request.url,
        );
      }
      var bodyBytes = (responseData[paramBody] as Blob?)?.data ?? Uint8List(0);

      var headers =
          (responseData[paramHeaders] as Map?)?.cast<String, String>() ??
          <String, String>{};
      var response = ResponseFirestore.bytes(
        bodyBytes,
        statusCode,
        headers: headers,
        request: ResponseRequest(request.method, request.url),
      );
      return response;
    } finally {
      cancelResponseSuscription();
    }
  }

  /// Any request: [http.Request], [http.StreamedRequest],
  /// [http.MultipartRequest]. Its body is read whole and sent as bytes with
  /// the headers of the finalized request (a multipart request sets its
  /// content type when finalized).
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    var bodyBytes = await request.finalize().toBytes();
    var headers = Map<String, String>.from(request.headers);

    var response = await curl(
      Request(request.method, request.url, headers: headers, body: bodyBytes),
    );

    return http.StreamedResponse(
      http.ByteStream.fromBytes(response.bodyBytes),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }
}
