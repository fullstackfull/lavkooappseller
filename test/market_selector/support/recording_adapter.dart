import 'dart:typed_data';

import 'package:dio/dio.dart';

/// What one request looked like when it left the app.
class RecordedRequest {
  const RecordedRequest({required this.method, required this.uri, required this.headers});

  final String method;
  final Uri uri;

  /// Every header, with its name in lower case.
  final Map<String, Object?> headers;

  Object? header(String name) => headers[name.toLowerCase()];
}

/// A Dio adapter with nothing behind it: it remembers what it was asked and answers every request with an empty JSON object, so no
/// test of the market reaches a network.
class RecordingAdapter implements HttpClientAdapter {
  final List<RecordedRequest> requests = <RecordedRequest>[];

  RecordedRequest get last => requests.last;

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(RecordedRequest(
      method: options.method,
      uri: options.uri,
      headers: <String, Object?>{
        for (final MapEntry<String, dynamic> entry in options.headers.entries) entry.key.toLowerCase(): entry.value,
      },
    ));

    return ResponseBody.fromString(
      '{}',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
