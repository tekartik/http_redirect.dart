import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:tekartik_firebase_firestore/firestore.dart' as firestore;
import 'package:tekartik_firebase_firestore/firestore.dart' as _firestore;
import 'package:tekartik_firebase_firestore/utils/auto_id_generator.dart';
import 'package:tekartik_http/http.dart' as common;

final String paramMethod = 'method';
final String paramBody = 'body';
final String paramError = 'error';
final String paramMessage = 'message';
final String paramUrl = 'url';
final String paramDate = 'date';
final String paramHeaders = 'headers';
final String paramStatusCode = 'statusCode'; // int response
final String httpClientFactoryFirestoreDefaultName = 'any';
final String firestoreHttpContextRequestsPartName = 'requests';
final String firestoreHttpContextResponsesPartName = 'responses';

class HttpClientFactoryFirestore implements common.HttpClientFactory {
  // FirebaseService _firebaseService;

  // final firestore.FirestoreService firestoreService;
  final _firestore.Firestore firestore;

  final String path;
  // final firebase.AppOptions? options;

  HttpClientFactoryFirestore({required this.firestore, required this.path});

  @override
  http.Client newClient() {
    return FirestoreHttpClient(this);
  }

  Future<_firestore.Firestore> get firestoreReady async {
    await ready;
    return firestore;
  }

  Future<bool> get ready async => true;
}

class ResponseFirestore implements http.Response {
  @override
  late String body;

  @override
  late int statusCode;

  @override
  Uint8List get bodyBytes => throw UnsupportedError('bodyBytes');

  @override
  int? get contentLength => throw UnsupportedError('contentLength');

  @override
  Map<String, String> get headers => throw UnsupportedError('headers');

  @override
  bool get isRedirect => throw UnsupportedError('isRedirect');

  @override
  bool get persistentConnection =>
      throw UnsupportedError('persistentConnection');

  @override
  String? get reasonPhrase => throw UnsupportedError('reasonPhrase');

  @override
  http.BaseRequest? get request => throw UnsupportedError('request');
}

class Request {
  String method;
  Uri url;
  Map<String, String>? headers;
  Object? body;

  Request(this.method, this.url, {this.headers, this.body});
}

String firestoreTekartikHttpCurlPath = url.join('tekartik_http'); //, 'curl');

class FirestoreHttpClient extends Object implements http.Client {
  final HttpClientFactoryFirestore httpContext;

  FirestoreHttpClient(this.httpContext);

  Future<firestore.Firestore> get firestoreReady async {
    // await firestoreHttpReady;
    return httpContext.firestoreReady;
  }

  @override
  Future<ResponseFirestore> get(url, {Map<String, String>? headers}) =>
      curl(Request(common.httpMethodGet, url, headers: headers));

  @override
  Future<ResponseFirestore> post(url,
          {Map<String, String>? headers, body, Encoding? encoding}) =>
      curl(Request(common.httpMethodPost, url, headers: headers, body: body));

  @override
  Future<ResponseFirestore> delete(url,
          {Map<String, String>? headers, body, Encoding? encoding}) =>
      curl(Request(common.httpMethodDelete, url, headers: headers, body: body));

  @override
  Future<ResponseFirestore> patch(url,
          {Map<String, String>? headers, body, Encoding? encoding}) =>
      curl(Request(common.httpMethodPatch, url, headers: headers, body: body));

  @override
  Future<ResponseFirestore> put(url,
          {Map<String, String>? headers, body, Encoding? encoding}) =>
      curl(Request(common.httpMethodPut, url, headers: headers, body: body));
  Future<ResponseFirestore> curl(Request request) async {
    var firestore = await firestoreReady;
    var data = <String, dynamic>{};

    data[paramUrl] = request.url;
    data[paramMethod] = request.method;
    if (request.headers != null) {
      data[paramHeaders] = request.headers;
    }
    if (request.body != null) {
      data[paramBody] = request.body;
    }
    data[paramDate] = _firestore.FieldValue.serverTimestamp;

    var docReference = firestore
        .collection(
            url.join(httpContext.path, firestoreHttpContextRequestsPartName))
        .doc(AutoIdGenerator.autoId());

    var responseReference = firestore.doc(url.join(httpContext.path,
        firestoreHttpContextResponsesPartName, docReference.id));

    Completer<Map<String, Object?>> responseCompleter =
        Completer<Map<String, Object>>();
    StreamSubscription? responseSubscription;

    void cancelResponseSuscription() {
      responseSubscription?.cancel();
      responseSubscription = null;
    }

    responseSubscription = responseReference.onSnapshot().listen((doc) {
      if (doc.exists) {
        var data = doc.data;
        responseCompleter.complete(data);
        cancelResponseSuscription();
      }
    });
    await docReference.set(data);

    //devPrint("request ${docReference?.path} $data");

    var responseData = await responseCompleter.future;

    //devPrint("response ${responseReference?.path} $responseData");

    cancelResponseSuscription();

    var response = ResponseFirestore()
      ..body = responseData[paramBody] as String
      ..statusCode = responseData[paramStatusCode] as int;
    return response;

    // TODO wait for response
  }

  @override
  void close() {
    // TODO: implement close
  }

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
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnsupportedError('send');
  }
}
