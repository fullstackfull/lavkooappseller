import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/repositories/platform_admin_api_client.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

import 'support/fixtures.dart';
import 'support/scripted_adapter.dart';

const String _platformToken =
    'lkpa_PLATFORMTOKEN0123456789PLATFORMTOKEN0123456789PLATFORMTOKEN01234';
const String _sellerToken =
    'SELLER-SESSION-TOKEN-THAT-MUST-NEVER-LEAVE-THE-SELLER-APP-0123456789';

/// The platform admin client is a second principal's way to the same host, and
/// the one thing it must never be is a second way for the seller's credentials
/// to travel. These tests look at every request that leaves it.
void main() {
  late String language;

  setUp(() => language = 'ar');

  PlatformAdminApiClient clientWith(ScriptedAdapter adapter) {
    final PlatformAdminApiClient client = PlatformAdminApiClient(
      baseUrl: AppConstants.baseUrl,
      languageCode: () => language,
    );
    client.dio.httpClientAdapter = adapter;
    return client;
  }

  group('where a request goes', () {
    test('to the platform admin API of the host the seller API is on',
        () async {
      final ScriptedAdapter adapter = ScriptedAdapter.replyingWith('me_owner');

      await clientWith(adapter).get('/me', bearerToken: _platformToken);

      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.uri.toString(),
          'https://lavkoo.com/api/platform-admin/v1/me');
    });

    test('with its parameters in the query and nowhere else', () async {
      final ScriptedAdapter adapter =
          ScriptedAdapter.replyingWith('overview_owner_kw');

      await clientWith(adapter).get(
        '/overview',
        bearerToken: _platformToken,
        query: <String, String>{'market': 'KW', 'from': '2026-11-11'},
      );

      expect(adapter.requests.single.uri.toString(),
          'https://lavkoo.com/api/platform-admin/v1/overview?market=KW&from=2026-11-11');
    });

    test(
        'a redirect is not followed, so a credential is never carried to another place',
        () {
      final PlatformAdminApiClient client =
          clientWith(ScriptedAdapter.replyingWith('me_owner'));

      expect(client.dio.options.followRedirects, isFalse);
    });

    test('a request that hangs gives up', () {
      final PlatformAdminApiClient client =
          clientWith(ScriptedAdapter.replyingWith('me_owner'));

      expect(client.dio.options.connectTimeout, isNotNull);
      expect(client.dio.options.receiveTimeout, isNotNull);
    });
  });

  group('what a request carries', () {
    test('the platform token as a bearer, JSON, and the language of the app',
        () async {
      final ScriptedAdapter adapter = ScriptedAdapter.replyingWith('me_owner');
      final PlatformAdminApiClient client = clientWith(adapter);

      await client.get('/me', bearerToken: _platformToken);
      language = 'en';
      await client.get('/me', bearerToken: _platformToken);

      expect(adapter.requests.first.header('Authorization'),
          'Bearer $_platformToken');
      expect(adapter.requests.first.header('Accept'), 'application/json');
      expect(adapter.requests.first.header('Accept-Language'), 'ar');
      expect(adapter.requests.last.header('Accept-Language'), 'en',
          reason: 'the language is read for every request, not once');
    });

    test(
        'and nothing else: not a seller header, not a storefront, not a version, not a cookie',
        () async {
      final ScriptedAdapter adapter = ScriptedAdapter.replyingWith('me_owner');

      await clientWith(adapter).get('/me', bearerToken: _platformToken);

      // Still an exact set rather than a list of forbidden names, so a storefront, a seller
      // language or this binary's version still fails it. The fourth is the shell declaring
      // which contract level it can read -- the shell's own, not the seller app's version.
      expect(adapter.requests.single.headers.keys.toSet(), <String>{
        'accept',
        'accept-language',
        'authorization',
        'x-platform-admin-contract'
      });
    });

    test(
        'a sign-in carries no Authorization header at all, not even an empty one',
        () async {
      final ScriptedAdapter adapter =
          ScriptedAdapter.replyingWith('login_success');

      await clientWith(adapter).post(
        '/auth/login',
        body: <String, Object?>{
          'email': 'owner@example.test',
          'password': 'a-password',
          'device_name': 'Pixel 9'
        },
      );

      final RecordedRequest request = adapter.requests.single;
      expect(request.headers.containsKey('authorization'), isFalse);
      expect(request.headers.keys.toSet(), <String>{
        'accept',
        'accept-language',
        'content-type',
        'content-length',
        'x-platform-admin-contract'
      });
      expect(request.header('Content-Type'), startsWith('application/json'));
    });

    test(
        'the credentials of a sign-in are in the body, which is all the API reads',
        () async {
      final ScriptedAdapter adapter =
          ScriptedAdapter.replyingWith('login_success');

      await clientWith(adapter).post(
        '/auth/login',
        body: <String, Object?>{
          'email': 'owner@example.test',
          'password': 'a-password',
          'device_name': 'Pixel 9'
        },
      );

      final RecordedRequest request = adapter.requests.single;
      expect(request.uri.toString(),
          'https://lavkoo.com/api/platform-admin/v1/auth/login');
      expect(request.uri.query, isEmpty);
      expect(request.uri.userInfo, isEmpty);
      expect(request.data, <String, Object?>{
        'email': 'owner@example.test',
        'password': 'a-password',
        'device_name': 'Pixel 9'
      });
    });

    test('the token is in the header and in no other part of the request',
        () async {
      final ScriptedAdapter adapter =
          ScriptedAdapter.replyingWith('sessions_owner');

      await clientWith(adapter)
          .delete('/sessions/7', bearerToken: _platformToken);

      final RecordedRequest request = adapter.requests.single;
      expect(request.method, 'DELETE');
      expect(request.uri.toString(), isNot(contains(_platformToken)));
      expect(request.data, isNull);
      expect(
          request.headers.entries
              .where((MapEntry<String, Object?> header) =>
                  '${header.value}'.contains(_platformToken))
              .map((MapEntry<String, Object?> header) => header.key),
          <String>['authorization']);
    });
  });

  group('a client of its own', () {
    Future<DioClient> sellerClient() async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppConstants.token: _sellerToken,
        AppConstants.languageCode: 'ar',
        'storefront_country': 'AE',
      });
      return DioClient(
        AppConstants.baseUrl,
        Dio(),
        loggingInterceptor: LoggingInterceptor(),
        sharedPreferences: await SharedPreferences.getInstance(),
      );
    }

    test('is not the seller client, and shares nothing with it', () async {
      final DioClient seller = await sellerClient();
      final PlatformAdminApiClient client =
          clientWith(ScriptedAdapter.replyingWith('me_owner'));

      expect(identical(client.dio, seller.dio), isFalse);
      expect(client.dio.options.baseUrl, isNot(seller.dio!.options.baseUrl));
      expect(
          client.dio.options.headers.keys
              .map((String name) => name.toLowerCase()),
          isNot(contains('authorization')),
          reason:
              'the token is given per request, so there is no standing credential to leak');
    });

    test('has no interceptor at all: no logger, and none of the seller app\'s',
        () {
      final PlatformAdminApiClient client =
          clientWith(ScriptedAdapter.replyingWith('me_owner'));

      expect(
        client.dio.interceptors.every((Interceptor interceptor) =>
            interceptor.runtimeType.toString() ==
            'ImplyContentTypeInterceptor'),
        isTrue,
        reason: client.dio.interceptors
            .map((Interceptor interceptor) => '${interceptor.runtimeType}')
            .join(', '),
      );
      expect(client.dio.interceptors.whereType<LogInterceptor>(), isEmpty);
      expect(client.dio.interceptors.whereType<LoggingInterceptor>(), isEmpty);
    });

    test(
        'never carries a seller who is signed in, a stored market or the seller language headers',
        () async {
      await sellerClient();
      final ScriptedAdapter adapter =
          ScriptedAdapter.replyingWith('markets_owner');

      await clientWith(adapter).get('/markets', bearerToken: _platformToken);

      expect(adapter.requests.single.everything, isNot(contains(_sellerToken)));
      expect(adapter.requests.single.headers.keys,
          isNot(contains('x-storefront')));
      expect(adapter.requests.single.headers.keys, isNot(contains('lang')));
      expect(adapter.requests.single.headers.keys,
          isNot(contains('x-localization')));
    });

    test('and the seller client is no more able to be given the platform token',
        () async {
      final DioClient seller = await sellerClient();
      final ScriptedAdapter sellerAdapter =
          ScriptedAdapter.replyingWith('me_owner');
      seller.dio!.httpClientAdapter = sellerAdapter;
      final ScriptedAdapter platformAdapter =
          ScriptedAdapter.replyingWith('me_owner');

      await clientWith(platformAdapter).get('/me', bearerToken: _platformToken);
      await seller.get('/api/v3/seller/seller-info');

      expect(sellerAdapter.requests.single.everything,
          isNot(contains(_platformToken)));
      expect(sellerAdapter.requests.single.header('Authorization'),
          'Bearer $_sellerToken');
    });
  });

  group('what it makes of an answer', () {
    test('a success carries its data, and its meta when it has one', () async {
      final PlatformAdminResult<PlatformAdminReply> alerts =
          await clientWith(ScriptedAdapter.replyingWith('alerts_owner'))
              .get('/alerts', bearerToken: _platformToken);
      final PlatformAdminResult<PlatformAdminReply> me =
          await clientWith(ScriptedAdapter.replyingWith('me_owner'))
              .get('/me', bearerToken: _platformToken);

      expect(alerts.isSuccess, isTrue);
      expect((alerts.value!.data as List), hasLength(4));
      expect(alerts.value!.meta['total'], 4);
      expect((me.value!.data as Map)['admin_id'], 4);
      expect(me.value!.meta, isEmpty);
    });

    test(
        'every refusal the real API produced becomes the failure the contract names',
        () async {
      const Map<String, PlatformAdminFailureKind> expected =
          <String, PlatformAdminFailureKind>{
        'error_unauthenticated': PlatformAdminFailureKind.unauthenticated,
        'login_failed_wrong_password': PlatformAdminFailureKind.unauthenticated,
        'error_market_not_allowed': PlatformAdminFailureKind.marketNotAllowed,
        'error_session_not_found': PlatformAdminFailureKind.sessionNotFound,
        'error_api_switched_off': PlatformAdminFailureKind.notAvailable,
        'error_api_switched_off_login': PlatformAdminFailureKind.notAvailable,
        'error_invalid_market': PlatformAdminFailureKind.invalidRequest,
        'error_invalid_window': PlatformAdminFailureKind.invalidRequest,
        'error_invalid_severity': PlatformAdminFailureKind.invalidRequest,
        'error_login_throttled': PlatformAdminFailureKind.throttled,
        'error_not_ready': PlatformAdminFailureKind.notReady,
      };

      for (final MapEntry<String, PlatformAdminFailureKind> entry
          in expected.entries) {
        final PlatformAdminResult<PlatformAdminReply> result =
            await clientWith(ScriptedAdapter.replyingWith(entry.key))
                .get('/me', bearerToken: _platformToken);

        expect(result.isSuccess, isFalse, reason: entry.key);
        expect(result.failure!.kind, entry.value, reason: entry.key);
        expect(result.failure!.statusCode, fixtureStatus(entry.key),
            reason: entry.key);
      }
    });

    test(
        'a throttled answer says to try again a minute from now, as its header does',
        () async {
      final DateTime before = DateTime.now();

      final PlatformAdminResult<PlatformAdminReply> result = await clientWith(
              ScriptedAdapter.replyingWith('error_login_throttled'))
          .post('/auth/login', body: <String, Object?>{});

      final DateTime retryAt = result.failure!.retryAt!;
      expect(retryAt.isAfter(before.add(const Duration(seconds: 59))), isTrue);
      expect(retryAt.isBefore(DateTime.now().add(const Duration(seconds: 61))),
          isTrue);
    });

    test('no answer at all is a network failure, whatever stopped it',
        () async {
      final List<DioException Function(RequestOptions)> causes =
          <DioException Function(RequestOptions)>[
        (RequestOptions options) => DioException.connectionError(
            requestOptions: options, reason: 'no route'),
        (RequestOptions options) => DioException.connectionTimeout(
            requestOptions: options, timeout: const Duration(seconds: 1)),
        (RequestOptions options) => DioException.receiveTimeout(
            requestOptions: options, timeout: const Duration(seconds: 1)),
        (RequestOptions options) => DioException.sendTimeout(
            requestOptions: options, timeout: const Duration(seconds: 1)),
        (RequestOptions options) =>
            DioException.badCertificate(requestOptions: options),
        (RequestOptions options) => DioException(
            requestOptions: options,
            error: const SocketException('Failed host lookup')),
      ];

      for (final DioException Function(RequestOptions) cause in causes) {
        final PlatformAdminResult<PlatformAdminReply> result =
            await clientWith(ScriptedAdapter.failingWith(cause))
                .get('/me', bearerToken: _platformToken);

        expect(result.failure!.kind, PlatformAdminFailureKind.network);
        expect(result.failure!.statusCode, isNull);
      }
    });

    test('a 200 that is not JSON is malformed and not a lost connection',
        () async {
      final PlatformAdminResult<PlatformAdminReply> result = await clientWith(
              ScriptedAdapter.replyingWithBody('<html>captive portal</html>',
                  headers: ScriptedAdapter.jsonHeaders))
          .get('/me', bearerToken: _platformToken);

      expect(result.failure!.kind, PlatformAdminFailureKind.malformed);
    });

    test('a 200 that has no data is malformed too', () async {
      for (final String body in <String>[
        '{}',
        '[]',
        '"ok"',
        '{"errors": []}',
        'null'
      ]) {
        final PlatformAdminResult<PlatformAdminReply> result = await clientWith(
                ScriptedAdapter.replyingWithBody(body,
                    headers: ScriptedAdapter.jsonHeaders))
            .get('/me', bearerToken: _platformToken);

        expect(result.failure?.kind, PlatformAdminFailureKind.malformed,
            reason: body);
      }
    });

    test('a page where the API was expected is the API not being there',
        () async {
      final PlatformAdminResult<PlatformAdminReply> result = await clientWith(
          ScriptedAdapter.replyingWithBody('<h1>Not Found</h1>',
              status: 404,
              headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>['text/html']
          })).get('/me', bearerToken: _platformToken);

      expect(result.failure!.kind, PlatformAdminFailureKind.notAvailable);
    });

    test(
        'a redirect is a failure and not a reason to go and ask somewhere else',
        () async {
      final ScriptedAdapter adapter = ScriptedAdapter.replyingWithBody('',
          status: 302,
          headers: <String, List<String>>{
            'location': <String>['https://elsewhere.example.test/me']
          });

      final PlatformAdminResult<PlatformAdminReply> result =
          await clientWith(adapter).get('/me', bearerToken: _platformToken);

      expect(result.isSuccess, isFalse);
      expect(adapter.requests, hasLength(1));
    });
  });

  group('what it does not say', () {
    test('nothing is printed or logged while it signs in, fails and is refused',
        () async {
      final List<String> printed = <String>[];
      final DebugPrintCallback original = debugPrint;
      debugPrint =
          (String? message, {int? wrapWidth}) => printed.add(message ?? '');

      try {
        await runZoned(
          () async {
            final PlatformAdminApiClient signIn =
                clientWith(ScriptedAdapter.replyingWith('login_success'));
            await signIn.post('/auth/login', body: <String, Object?>{
              'email': 'owner@example.test',
              'password': 'a-password',
              'device_name': 'Pixel 9'
            });
            await clientWith(
                    ScriptedAdapter.replyingWith('error_unauthenticated'))
                .get('/me', bearerToken: _platformToken);
            await clientWith(ScriptedAdapter.failingWith(
                (RequestOptions options) => DioException.connectionError(
                    requestOptions: options,
                    reason: 'x'))).get('/me', bearerToken: _platformToken);
          },
          zoneSpecification: ZoneSpecification(
              print: (Zone self, ZoneDelegate parent, Zone zone, String line) =>
                  printed.add(line)),
        );
      } finally {
        debugPrint = original;
      }

      expect(printed, isEmpty);
    });
  });
}
