import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// What one request looked like when it left the app.
class RecordedRequest {
  const RecordedRequest({required this.method, required this.uri, required this.headers});

  final String method;
  final Uri uri;

  /// Every header, with its name in lower case.
  final Map<String, Object?> headers;

  /// The query exactly as it was written on the wire, without the question mark.
  String get rawQuery => uri.query;
}

/// One answer of the scripted server: a status and a body that is already text.
class ScriptedAnswer {
  const ScriptedAnswer(this.body, {this.status = 200, this.contentType = Headers.jsonContentType});

  ScriptedAnswer.json(Object? value, {int status = 200}) : this(jsonEncode(value), status: status);

  /// What a proxy or a crashed server sends instead of the API's own answer.
  const ScriptedAnswer.page(String html, {int status = 500}) : this(html, status: status, contentType: 'text/html');

  final String body;
  final int status;
  final String contentType;
}

typedef ScriptedServer = ScriptedAnswer Function(RecordedRequest request);

/// A Dio adapter with nothing behind it: it remembers what it was asked and answers from a script, so no test of
/// the point-of-sale scan reaches a network.
class ScriptedAdapter implements HttpClientAdapter {
  ScriptedAdapter(this._server);

  /// Answers every request with the same answer.
  ScriptedAdapter.always(ScriptedAnswer answer) : this((RecordedRequest _) => answer);

  /// Answers the first request with the first answer, the second with the second, and so on. A request the script has no
  /// answer for is a test that sent more than it meant to, so it fails loudly.
  factory ScriptedAdapter.inOrder(List<ScriptedAnswer> answers) {
    int next = 0;
    return ScriptedAdapter((RecordedRequest request) {
      if (next >= answers.length) {
        throw StateError('The script has no answer for request ${next + 1}: ${request.method} ${request.uri}');
      }
      return answers[next++];
    });
  }

  /// Fails every request the way a phone with no signal does.
  factory ScriptedAdapter.offline() => ScriptedAdapter((RecordedRequest request) => throw DioException.connectionError(
        requestOptions: RequestOptions(path: request.uri.path),
        reason: 'no signal',
      ));

  final ScriptedServer _server;
  final List<RecordedRequest> requests = <RecordedRequest>[];

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final RecordedRequest request = RecordedRequest(
      method: options.method,
      uri: options.uri,
      headers: <String, Object?>{
        for (final MapEntry<String, dynamic> entry in options.headers.entries) entry.key.toLowerCase(): entry.value,
      },
    );
    requests.add(request);

    final ScriptedAnswer answer = _server(request);
    return ResponseBody.fromString(
      answer.body,
      answer.status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[answer.contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
