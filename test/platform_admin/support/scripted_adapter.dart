import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'fixtures.dart';

/// What one request looked like when it left the app.
class RecordedRequest {
  final String method;
  final Uri uri;

  /// Every header, with its name in lower case.
  final Map<String, Object?> headers;
  final Object? data;

  const RecordedRequest({required this.method, required this.uri, required this.headers, required this.data});

  String? header(String name) => headers[name.toLowerCase()]?.toString();

  /// Everything the request carried, as text: the address, every header and the body.
  String get everything => '$method $uri ${jsonEncode(headers)} ${data is Map ? jsonEncode(data) : data}';
}

typedef _Respond = Future<ResponseBody> Function(RequestOptions options, RecordedRequest request);

/// A Dio adapter with nothing behind it: it remembers what it was asked and
/// answers from a script, so no test of the platform admin client reaches a network.
class ScriptedAdapter implements HttpClientAdapter {
  final List<RecordedRequest> requests = <RecordedRequest>[];
  final _Respond _respond;

  ScriptedAdapter(this._respond);

  /// Answers every request with the same recorded body.
  ScriptedAdapter.replyingWith(String fixtureName)
      : this((RequestOptions _, RecordedRequest __) async => reply(fixtureName));

  /// Answers every request with a body of its own.
  ScriptedAdapter.replyingWithBody(String body, {int status = 200, Map<String, List<String>>? headers})
      : this((RequestOptions _, RecordedRequest __) async =>
            ResponseBody.fromString(body, status, headers: headers ?? jsonHeaders));

  /// Answers each route with its own recorded body. The key is the method and the
  /// path without the API prefix or the query, like `GET /overview`; a route that
  /// is not listed is answered like a route the router does not have.
  ScriptedAdapter.routing(Map<String, String> fixtureByRoute)
      : this((RequestOptions _, RecordedRequest request) async => reply(
              fixtureByRoute['${request.method} ${request.uri.path.replaceFirst('/api/platform-admin/v1', '')}'] ??
                  'error_api_switched_off',
            ));

  /// Fails every request the way a phone with no signal does.
  ScriptedAdapter.failingWith(DioException Function(RequestOptions options) failure)
      : this((RequestOptions options, RecordedRequest _) => Future<ResponseBody>.error(failure(options)));

  static const Map<String, List<String>> jsonHeaders = <String, List<String>>{
    Headers.contentTypeHeader: <String>[Headers.jsonContentType],
  };

  /// The recorded answer, with the status and the header the server sent with it.
  static ResponseBody reply(String fixtureName) {
    final String? retryAfter = fixtureRetryAfter(fixtureName);

    return ResponseBody.fromString(
      rawFixture(fixtureName),
      fixtureStatus(fixtureName),
      headers: <String, List<String>>{
        ...jsonHeaders,
        if (retryAfter != null) 'retry-after': <String>[retryAfter],
      },
    );
  }

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    final RecordedRequest request = RecordedRequest(
      method: options.method,
      uri: options.uri,
      headers: <String, Object?>{
        for (final MapEntry<String, dynamic> entry in options.headers.entries) entry.key.toLowerCase(): entry.value,
      },
      data: options.data,
    );
    requests.add(request);

    return _respond(options, request);
  }

  @override
  void close({bool force = false}) {}
}
