import 'package:dio/dio.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_json.dart';

/// What a successful call answered: `data`, and `meta` for a list.
class PlatformAdminReply {
  final Object? data;
  final Map<String, dynamic> meta;

  const PlatformAdminReply({required this.data, required this.meta});
}

/// The app's only way to the platform admin API.
///
/// A second principal reaches the same host as the seller, so this is a client of
/// its own and not a use of the seller's: its own Dio, with no interceptor, so
/// that nothing which logs, counts or signs a seller request touches it, and no
/// header it did not set itself. The bearer token is handed to every call and is
/// never kept here, so there is no standing credential to leak, and the seller's
/// token, storefront, language headers and version are not within its reach.
///
/// Nothing here prints. A request of this client carries a password or the keys
/// to every market, and a log line is a copy nobody can take back.
class PlatformAdminApiClient {
  static const String apiPath = '/api/platform-admin/v1';

  /// Public so that a test can give it an adapter that answers from a script.
  final Dio dio;

  final String Function() _languageCode;

  PlatformAdminApiClient({required String baseUrl, required String Function() languageCode})
      : _languageCode = languageCode,
        dio = Dio(
          BaseOptions(
            baseUrl: '$baseUrl$apiPath',
            connectTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 60),
            // A redirect would carry the token to wherever it points.
            followRedirects: false,
            headers: <String, Object>{Headers.acceptHeader: Headers.jsonContentType},
          ),
        );

  Future<PlatformAdminResult<PlatformAdminReply>> get(
    String path, {
    String? bearerToken,
    Map<String, String>? query,
  }) =>
      _send('GET', path, bearerToken: bearerToken, query: query);

  Future<PlatformAdminResult<PlatformAdminReply>> post(
    String path, {
    String? bearerToken,
    Map<String, Object?>? body,
  }) =>
      _send('POST', path, bearerToken: bearerToken, body: body);

  Future<PlatformAdminResult<PlatformAdminReply>> delete(String path, {String? bearerToken}) =>
      _send('DELETE', path, bearerToken: bearerToken);

  Future<PlatformAdminResult<PlatformAdminReply>> _send(
    String method,
    String path, {
    String? bearerToken,
    Map<String, String>? query,
    Map<String, Object?>? body,
  }) async {
    try {
      final Response<Object?> response = await dio.request<Object?>(
        path,
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          headers: <String, Object>{
            'Accept-Language': _languageCode(),
            if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
          },
        ),
      );
      return _reply(response.data);
    } on DioException catch (error) {
      return PlatformAdminResult<PlatformAdminReply>.failure(_failureOf(error));
    }
  }

  PlatformAdminResult<PlatformAdminReply> _reply(Object? body) {
    if (body is! Map || !body.containsKey('data')) {
      return const PlatformAdminResult<PlatformAdminReply>.failure(PlatformAdminFailure.malformed());
    }
    return PlatformAdminResult<PlatformAdminReply>.success(
      PlatformAdminReply(data: body['data'], meta: PlatformJson.map(body['meta'])),
    );
  }

  PlatformAdminFailure _failureOf(DioException error) {
    final Response<Object?>? response = error.response;

    if (response != null) {
      return PlatformAdminFailure.fromResponse(
        statusCode: response.statusCode ?? 0,
        body: response.data,
        retryAfter: response.headers.value('retry-after'),
      );
    }

    // A body that could not be read arrives here too, and is not a lost connection.
    return error.error is FormatException
        ? const PlatformAdminFailure.malformed()
        : const PlatformAdminFailure.network();
  }
}
