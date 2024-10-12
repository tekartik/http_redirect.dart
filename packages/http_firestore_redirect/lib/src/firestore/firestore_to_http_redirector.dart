import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:path/path.dart' as p;
import 'package:tekartik_http_firestore_redirect/src/firestore/http_to_firestore_client.dart';
import 'package:tekartik_http_firestore_redirect/src/import.dart';

class Redirector {
  // Find by name if any
  final String name;

  // otherwise use hostPort
  final String? baseUrl;

  Redirector(this.name, this.baseUrl);
}

abstract class Listener {
  void info(String message, Object? data);
}

class RedirectorService {
  final Firestore firestore;
  final Redirector redirector;
  Listener? listener;

  // late HttpClientFactoryFirestore firestoreHttpContext;
  final HttpClientFactory httpClientFactory;
  StreamSubscription<QuerySnapshot>? requestsStreamSubscription;
  StreamSubscription<DocumentSnapshot>? paramSubscription;
  http.Client? _httpClient;

  RedirectorService(this.redirector,
      {this.listener,
      AppOptions? options,
      required this.firestore,
      required this.path,
      required this.httpClientFactory}) {
    // firestoreHttpContext =        HttpClientFactoryFirestore(redirector.name, options: options, firestore: firestore);
  }

  String? baseUrl;

  final String path;

  Future<void> start() async {
    if (requestsStreamSubscription == null) {
      //var path = this.path;
      //devPrint("handling in $path");
      // var firestore = await firestoreHttpContext.firestoreReady;
      //listener?.info("firestore", firestore.app.options.projectId);

      Future<void> handleRequests() async {
        await _handleRequests(
            firestore, url.join(path, firestoreHttpContextRequestsPartName));
      }

      if (redirector.baseUrl == null) {
        paramSubscription =
            firestore.doc(path).onSnapshot().listen((snapshot) async {
          if (snapshot.exists) {
            baseUrl = snapshot.data['baseUrl'] as String?;
            listener?.info('baseUrl', baseUrl);
          } else {
            baseUrl = null;
          }
          await handleRequests();
        });
      } else {
        baseUrl = redirector.baseUrl;
        await handleRequests();
      }
    }
  }

  // final _lock = Lock();
  var _requestIds = <String>[];

  Future _handleRequests(Firestore firestore, String path) async {
    listener?.info('listening', path);
    listener?.info('baseUrl', baseUrl);
    requestsStreamSubscription =
        firestore.collection(path).onSnapshot().listen((snapshot) async {
      //devPrint(snapshot.docs);
      var docs = snapshot.docs;
      for (var doc in docs) {
        if (doc.exists) {
          var requestId = doc.ref.id;
          if (_requestIds.contains(requestId)) {
            continue;
          }
          // await _lock.synchronized(() async {
          try {
            // Track answered requestId
            _requestIds.add(requestId);
            if (_requestIds.length > 50) {
              _requestIds = _requestIds.sublist(10);
            }
            var responsePath = p.url.join(
                this.path, firestoreHttpContextResponsesPartName, requestId);
            print('redirector request ${doc.ref.path} ${doc.data}');

            var httpClient = _httpClient ?? httpClientFactory.newClient();
            var data = doc.data;
            listener?.info('request', data);
            var method = data[paramMethod] as String? ?? httpMethodGet;
            var url = data[paramUrl] as String?;
            var dataResponse = <String, dynamic>{};
            //url ??= '';
            if (url != null) {
              var dataHeaders = data[paramHeaders] as Map?;
              var headers = <String, String>{};
              if (dataHeaders is Map) {
                dataHeaders.forEach((k, v) {
                  String? value;
                  if (v is List) {
                    value = v.join(',');
                  } else if (v is String) {
                    value = v;
                  }
                  if (value != null) {
                    headers[k as String] = value;
                  }
                });
              }

              if (baseUrl != null) {
                url = p.url.join(baseUrl!, url);
              }

              Response? response;

              dynamic body = data[paramBody];
              if (body is Map) {
                body = json.encode(body);
              }
              print('url $url');
              // headers ??= {};
              //headers['Access-Control-Allow-Origin'] = "*";

              try {
                switch (method) {
                  case httpMethodGet:
                    response =
                        await httpClient.get(Uri.parse(url), headers: headers);
                    break;
                  case httpMethodPost:
                    response = await httpClient.post(Uri.parse(url),
                        headers: headers, body: body);
                    break;
                  case httpMethodDelete:
                    response = await httpClient.delete(Uri.parse(url),
                        headers: headers);
                    break;
                  case httpMethodPut:
                    response = await httpClient.put(Uri.parse(url),
                        headers: headers, body: body);
                    break;
                  case httpMethodPatch:
                    response = await httpClient.patch(Uri.parse(url),
                        headers: headers, body: body);
                    break;
                }
              } catch (e, st) {
                dataResponse[paramError] = <String, dynamic>{
                  paramMessage: e.toString()
                };
                if (isDebug) {
                  print(st);
                }
              }

              if (response != null) {
                dataResponse[paramStatusCode] = response.statusCode;
                dataResponse[paramBody] = Blob(response.bodyBytes);
                dataResponse[paramHeaders] = response.headers;
              }
              dataResponse[paramUrl] = url;
              dataResponse[paramTimestamp] = FieldValue.serverTimestamp;
            }

            print('redirector response $responsePath $dataResponse');

            listener?.info('response', dataResponse);
            await firestore.doc(responsePath).set(dataResponse);
          } finally {
            await firestore.doc(doc.ref.path).delete();
          }
          //});
        }
      }
    });
  }

  void stop() {
    requestsStreamSubscription?.cancel();
    requestsStreamSubscription = null;
    paramSubscription?.cancel();
    paramSubscription = null;
    _httpClient?.close();
  }
}
