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
  ResponseRequest(String method, Uri url) : super(method, url);
}

class FirestoreHttpClient extends Object implements http.Client {
  final HttpClientFactoryFirestore httpContext;

  FirestoreHttpClient(this.httpContext);

  Future<firestore.Firestore> get firestoreReady async {
    // await firestoreHttpReady;
    return httpContext.firestoreReady;
  }

  @override
  Future<ResponseFirestore> get(Uri url, {Map<String, String>? headers}) =>
      curl(Request(common.httpMethodGet, url, headers: headers));

  @override
  Future<ResponseFirestore> post(Uri url,
          {Map<String, String>? headers, body, Encoding? encoding}) =>
      curl(Request(common.httpMethodPost, url, headers: headers, body: body));

  @override
  Future<ResponseFirestore> delete(Uri url,
          {Map<String, String>? headers, body, Encoding? encoding}) =>
      curl(Request(common.httpMethodDelete, url, headers: headers, body: body));

  @override
  Future<ResponseFirestore> patch(Uri url,
          {Map<String, String>? headers, body, Encoding? encoding}) =>
      curl(Request(common.httpMethodPatch, url, headers: headers, body: body));

  @override
  Future<ResponseFirestore> put(Uri url,
          {Map<String, String>? headers, body, Encoding? encoding}) =>
      curl(Request(common.httpMethodPut, url, headers: headers, body: body));

  Future<ResponseFirestore> curl(Request request) async {
    StreamSubscription? responseSubscription;

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
              url.join(httpContext.path, firestoreHttpContextRequestsPartName))
          .doc(AutoIdGenerator.autoId());

      var responsePath = url.join(httpContext.path,
          firestoreHttpContextResponsesPartName, docReference.id);
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
        print('[REQ] ${docReference.id} $data');
      }
      //devPrint("request ${docReference?.path} $data");

      var responseData =
          await responseCompleter.future.timeout(Duration(seconds: 30));

      //devPrint("response ${responseReference?.path} $responseData");
      if (debugHttpToFirestore) {
        print('[RESP] $responseData');
      }
      cancelResponseSuscription();

      var bodyBytes = (responseData[paramBody] as Blob?)?.data ?? Uint8List(0);

      var statusCode = responseData[paramStatusCode] as int;
      var headers =
          (responseData[paramHeaders] as Map?)?.cast<String, String>() ??
              <String, String>{};
      var response = ResponseFirestore.bytes(bodyBytes, statusCode,
          headers: headers,
          request: ResponseRequest(request.method, request.url));
      return response;
    } finally {
      cancelResponseSuscription();
    }
  }

  @override
  void close() {}

  @override
  Future<http.Response> head(url, {Map<String, String>? headers}) {
    throw UnsupportedError('head');
  }

  @override
  Future<String> read(url, {Map<String, String>? headers}) {
    throw UnsupportedError('read');
  }

  @override
  Future<Uint8List> readBytes(url, {Map<String, String>? headers}) {
    throw UnsupportedError('readBytes');
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Encoding? encoding;
    Uint8List? bodyBytes;
    if (request is http.Request) {
      // encoding = request.encoding;
      bodyBytes = request.bodyBytes;
    } else if (request is http.MultipartRequest) {
      throw UnsupportedError('multi part streamed requests is not supported');
      /*
      requestCopy = http.MultipartRequest(request.method, request.url)
        ..fields.addAll(request.fields)
        ..files.addAll(request.files);*/
    } else if (request is http.StreamedRequest) {
      throw UnsupportedError('copying streamed requests is not supported');
    } else {
      throw UnsupportedError('request type is unknown, cannot copy');
    }
    var headers = Map<String, String>.from(request.headers);

    var response = await curl(Request(request.method, request.url,
        headers: headers, body: bodyBytes));

    try {
      return http.StreamedResponse(
          http.ByteStream.fromBytes(response.bodyBytes), response.statusCode,
          contentLength: response.contentLength,
          request: response.request,
          headers: response.headers,
          isRedirect: response.isRedirect,
          persistentConnection: response.persistentConnection,
          reasonPhrase: response.reasonPhrase);
    } catch (_) {
      rethrow;
    }
  }
}
