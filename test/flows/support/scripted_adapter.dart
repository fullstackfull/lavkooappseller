import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// What one request looked like when it left the app.
class RecordedRequest {
  const RecordedRequest({required this.method, required this.uri, required this.headers, required this.body});

  final String method;
  final Uri uri;

  /// Every header, with its name in lower case.
  final Map<String, Object?> headers;

  /// What went over the wire: the decoded JSON of a JSON body, the text of any other body, null when there was none.
  final Object? body;

  String get path => uri.path;

  Map<String, String> get query => uri.queryParameters;

  /// The query exactly as it was written on the wire, without the question mark.
  String get rawQuery => uri.query;

  /// The body as the map of fields a form or a JSON object carries.
  Map<String, Object?> get fields => Map<String, Object?>.from(body! as Map<dynamic, dynamic>);
}

/// One answer of the scripted server: a status and a body that is already text, or a failure of the connection itself.
class ScriptedAnswer {
  const ScriptedAnswer(this.body, {this.status = 200, this.contentType = Headers.jsonContentType}) : failure = null;

  ScriptedAnswer.json(Object? value, {int status = 200}) : this(jsonEncode(value), status: status);

  /// What a proxy or a crashed server sends instead of the API's own answer.
  const ScriptedAnswer.page(String html, {int status = 500}) : this(html, status: status, contentType: 'text/html');

  /// A phone with no signal.
  ScriptedAnswer.offline()
      : body = '',
        status = 0,
        contentType = Headers.jsonContentType,
        failure = DioException.connectionError(requestOptions: RequestOptions(), reason: 'no signal');

  /// A connection that never completes.
  ScriptedAnswer.timeout()
      : body = '',
        status = 0,
        contentType = Headers.jsonContentType,
        failure =
            DioException.connectionTimeout(timeout: const Duration(seconds: 60), requestOptions: RequestOptions());

  /// A socket that was reset underneath the app.
  ScriptedAnswer.socketReset()
      : body = '',
        status = 0,
        contentType = Headers.jsonContentType,
        failure = DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.unknown,
          error: const SocketException('Connection reset by peer'),
        );

  final String body;
  final int status;
  final String contentType;

  /// What the transport throws instead of answering.
  final DioException? failure;
}

typedef ScriptedServer = ScriptedAnswer Function(RecordedRequest request);

/// A Dio adapter with nothing behind it: it remembers what it was asked and answers from a script, so no test of a
/// seller flow reaches a network.
class ScriptedAdapter implements HttpClientAdapter {
  ScriptedAdapter(this._server);

  /// Answers every request with the same answer.
  ScriptedAdapter.always(ScriptedAnswer answer) : this((RecordedRequest _) => answer);

  /// Answers the first request with the first answer, the second with the second, and so on. A request the script has
  /// no answer for is a test that sent more than it meant to, so it fails loudly.
  factory ScriptedAdapter.inOrder(List<ScriptedAnswer> answers) {
    int next = 0;
    return ScriptedAdapter((RecordedRequest request) {
      if (next >= answers.length) {
        throw StateError('The script has no answer for request ${next + 1}: ${request.method} ${request.uri}');
      }
      return answers[next++];
    });
  }

  /// Answers by method and path; a request the routes do not name fails loudly.
  factory ScriptedAdapter.routes(Map<String, ScriptedServer> routes) {
    return ScriptedAdapter((RecordedRequest request) {
      final ScriptedServer? route = routes['${request.method} ${request.path}'];
      if (route == null) {
        throw StateError('The script names no route for ${request.method} ${request.uri}');
      }
      return route(request);
    });
  }

  final ScriptedServer _server;
  final List<RecordedRequest> requests = <RecordedRequest>[];

  /// The one request the test sent; a test that sent more or fewer fails here rather than on a later line.
  RecordedRequest get only => requests.single;

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final RecordedRequest request = RecordedRequest(
      method: options.method,
      uri: options.uri,
      headers: <String, Object?>{
        for (final MapEntry<String, dynamic> entry in options.headers.entries) entry.key.toLowerCase(): entry.value,
      },
      body: await _wireBody(options, requestStream),
    );
    requests.add(request);

    final ScriptedAnswer answer = _server(request);
    final DioException? failure = answer.failure;
    if (failure != null) {
      throw DioException(
        requestOptions: options,
        type: failure.type,
        error: failure.error,
        message: failure.message,
      );
    }

    return ResponseBody.fromString(
      answer.body,
      answer.status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[answer.contentType],
      },
    );
  }

  Future<Object?> _wireBody(RequestOptions options, Stream<Uint8List>? requestStream) async {
    if (requestStream == null) return null;

    final List<int> bytes = <int>[
      for (final Uint8List chunk in await requestStream.toList()) ...chunk,
    ];
    if (bytes.isEmpty) return null;

    final String text = utf8.decode(bytes);
    return (options.contentType ?? '').contains('json') ? jsonDecode(text) : text;
  }

  @override
  void close({bool force = false}) {}
}
