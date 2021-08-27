import 'package:tekartik_http_firestore_redirect/src/firestore/model/fs_request.dart';
import 'package:tekartik_http_firestore_redirect/src/firestore/model/fs_response.dart';
import 'package:tekartik_http_firestore_redirect/src/import.dart';

import 'firestore_http_client.dart';

/// /root_project
///

CvDocumentReference<CvFirestoreDocumentBase> redirectorRootRef(String path) =>
    CvDocumentReference<CvFirestoreDocumentBase>(path);

/// <root>/request/
///
/// Requests
CvCollectionReference<FsRequest> requestsRef(String path) =>
    redirectorRootRef(path)
        .collection<FsRequest>(firestoreHttpContextRequestsPartName);

/// <root>/request/<requestId>
///
/// Request
CvDocumentReference<FsRequest> requestRef(String path, String id) =>
    requestsRef(path).doc(id);

/// <root>/response/
///
/// Responses
CvCollectionReference<FsResponse> responsesRef(String path) =>
    redirectorRootRef(path)
        .collection<FsResponse>(firestoreHttpContextResponsesPartName);

/// <root>/response/<requestId>
///
/// Response
CvDocumentReference<FsResponse> responseRef(String path, String id) =>
    responsesRef(path).doc(id);
