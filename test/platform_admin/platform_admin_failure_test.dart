import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_capability_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';

import 'support/fixtures.dart';

/// What the app makes of every way the platform admin API says no.
///
/// The code in the body is the contract; the message is English for a person
/// reading a log and is never shown. The status alone is not enough either: a
/// 404 is "this session is not yours" from one route and "this API does not
/// exist" from the router, and the two want different screens.
void main() {
  final DateTime now = DateTime.utc(2026, 11, 17, 10);

  PlatformAdminFailure failureOf(String name, {DateTime? at}) => PlatformAdminFailure.fromResponse(
        statusCode: fixtureStatus(name),
        body: fixture(name),
        retryAfter: fixtureRetryAfter(name),
        now: at ?? now,
      );

  group('every refusal the real API produced', () {
    test('any failure to authenticate is one failure, whatever the route', () {
      for (final String name in <String>['error_unauthenticated', 'login_failed_wrong_password']) {
        expect(failureOf(name).kind, PlatformAdminFailureKind.unauthenticated, reason: name);
      }
    });

    test('a market the grant does not hold is its own failure', () {
      final PlatformAdminFailure failure = failureOf('error_market_not_allowed');

      expect(failure.kind, PlatformAdminFailureKind.marketNotAllowed);
      expect(failure.code, 'market_not_allowed');
      expect(failure.statusCode, 403);
    });

    test('a part of the API the grant leaves out is its own failure, and names the part', () {
      final PlatformAdminFailure failure = failureOf('error_capability_not_allowed');

      expect(failure.kind, PlatformAdminFailureKind.capabilityNotAllowed);
      expect(failure.code, 'capability_not_allowed');
      expect(failure.statusCode, 403);
      expect(failure.capability, PlatformCapability.audit);
      expect(failureOf('error_capability_not_allowed_markets').capability, PlatformCapability.markets);
    });

    test('a part the app has never heard of is still a part the grant leaves out, and is named by nothing', () {
      final PlatformAdminFailure failure = PlatformAdminFailure.fromResponse(
        statusCode: 403,
        body: <String, dynamic>{
          'errors': <Object?>[
            <String, dynamic>{'code': 'capability_not_allowed', 'message': 'x', 'capability': 'exports'},
          ],
        },
        now: now,
      );

      expect(failure.kind, PlatformAdminFailureKind.capabilityNotAllowed);
      expect(failure.capability, isNull);
    });

    test('a capability refusal is not an authentication failure: the token is good', () {
      expect(failureOf('error_capability_not_allowed').kind, isNot(PlatformAdminFailureKind.unauthenticated));
      expect(failureOf('error_capability_not_allowed').kind, isNot(PlatformAdminFailureKind.marketNotAllowed));
    });

    test('a session that is not one of mine is not found, and is not the API missing', () {
      expect(failureOf('error_session_not_found').kind, PlatformAdminFailureKind.sessionNotFound);
    });

    test('an API that is switched off is the router saying it has no such route', () {
      for (final String name in <String>['error_api_switched_off', 'error_api_switched_off_login']) {
        expect(failureOf(name).kind, PlatformAdminFailureKind.notAvailable, reason: name);
      }
    });

    test('a request the API cannot read is invalid, with the code it gave', () {
      expect(failureOf('error_invalid_market').kind, PlatformAdminFailureKind.invalidRequest);
      expect(failureOf('error_invalid_market').code, 'invalid_market');
      expect(failureOf('error_invalid_window').code, 'invalid_window');
      expect(failureOf('error_invalid_severity').code, 'invalid_severity');
    });

    test('too many attempts says when to try again, counted from the moment it answered', () {
      final PlatformAdminFailure failure = failureOf('error_login_throttled');

      expect(failure.kind, PlatformAdminFailureKind.throttled);
      expect(failure.retryAt, now.add(const Duration(seconds: 60)));
    });

    test('an API switched on before its tables exist is not ready yet', () {
      final PlatformAdminFailure failure = failureOf('error_not_ready');

      expect(failure.kind, PlatformAdminFailureKind.notReady);
      expect(failure.code, 'platform_admin_unavailable');
    });
  });

  group('what the real API does not promise', () {
    test('a 404 whose body is a page and not JSON is the API not being there', () {
      expect(
        PlatformAdminFailure.fromResponse(statusCode: 404, body: '<html><title>Not Found</title></html>', now: now)
            .kind,
        PlatformAdminFailureKind.notAvailable,
      );
    });

    test('a 404 with no body at all is the API not being there', () {
      expect(PlatformAdminFailure.fromResponse(statusCode: 404, body: null, now: now).kind,
          PlatformAdminFailureKind.notAvailable);
    });

    test('a 503 from the web server in front of the API is also not ready', () {
      expect(
        PlatformAdminFailure.fromResponse(statusCode: 503, body: '<h1>Service Unavailable</h1>', now: now).kind,
        PlatformAdminFailureKind.notReady,
      );
    });

    test('a 401 is a failure to authenticate even when the body says nothing', () {
      expect(PlatformAdminFailure.fromResponse(statusCode: 401, body: null, now: now).kind,
          PlatformAdminFailureKind.unauthenticated);
      expect(PlatformAdminFailure.fromResponse(statusCode: 401, body: '', now: now).kind,
          PlatformAdminFailureKind.unauthenticated);
    });

    test('a 403 that is not about a market is not claimed to be', () {
      expect(
        PlatformAdminFailure.fromResponse(statusCode: 403, body: <String, dynamic>{'message': 'Forbidden'}, now: now)
            .kind,
        PlatformAdminFailureKind.server,
      );
    });

    test('a server error, whatever its body, is a server error', () {
      for (final int status in <int>[500, 502, 504, 418]) {
        expect(
            PlatformAdminFailure.fromResponse(statusCode: status, body: <String, dynamic>{'message': 'boom'}, now: now)
                .kind,
            PlatformAdminFailureKind.server,
            reason: '$status');
      }
    });

    test('a body that lists no error has no code', () {
      expect(
          PlatformAdminFailure.fromResponse(statusCode: 422, body: <String, dynamic>{'errors': <Object?>[]}, now: now)
              .code,
          isNull);
      expect(
          PlatformAdminFailure.fromResponse(statusCode: 422, body: <String, dynamic>{'errors': 'nope'}, now: now).code,
          isNull);
      expect(
          PlatformAdminFailure.fromResponse(
                  statusCode: 422,
                  body: <String, dynamic>{
                    'errors': <Object?>['x']
                  },
                  now: now)
              .code,
          isNull);
    });
  });

  group('when to try again', () {
    PlatformAdminFailure throttled(String? header) =>
        PlatformAdminFailure.fromResponse(statusCode: 429, body: null, retryAfter: header, now: now);

    test('seconds are counted from now', () {
      expect(throttled('45').retryAt, now.add(const Duration(seconds: 45)));
      expect(throttled(' 120 ').retryAt, now.add(const Duration(seconds: 120)));
    });

    test('a header that is not a number of seconds gives no time rather than a wrong one', () {
      for (final String? header in <String?>[null, '', 'soon', 'Wed, 21 Oct 2026 07:28:00 GMT', '-5', '0', '1.5']) {
        expect(throttled(header).retryAt, isNull, reason: '$header');
        expect(throttled(header).kind, PlatformAdminFailureKind.throttled);
      }
    });

    test('an absurd wait is held to a day, so that the moment it names can still be written down', () {
      expect(throttled('99999999999999').retryAt, now.add(const Duration(days: 1)));
    });
  });

  group('failures that never reached the API', () {
    test('no connection is a network failure with no status', () {
      const PlatformAdminFailure failure = PlatformAdminFailure.network();

      expect(failure.kind, PlatformAdminFailureKind.network);
      expect(failure.statusCode, isNull);
    });

    test('an answer that is not what the contract says is malformed', () {
      expect(const PlatformAdminFailure.malformed().kind, PlatformAdminFailureKind.malformed);
    });

    test('a failure that names a part says so, and still prints nothing the server said', () {
      expect(failureOf('error_capability_not_allowed').toString(), contains('capability: audit'));
      expect(failureOf('error_capability_not_allowed').toString(), isNot(contains('This account')));
    });

    test('a failure never prints what the server said, only what happened', () {
      final PlatformAdminFailure failure = PlatformAdminFailure.fromResponse(
        statusCode: 422,
        body: <String, dynamic>{
          'errors': <Object?>[
            <String, dynamic>{'code': 'invalid_market', 'message': 'secret-looking message lkpa_${'x' * 64}'},
          ],
        },
        now: now,
      );

      expect(failure.toString(), isNot(contains('lkpa_')));
      expect(failure.toString(), isNot(contains('secret-looking')));
      expect(failure.toString(), contains('invalid_market'));
    });
  });

  group('results', () {
    test('a success carries its value and no failure', () {
      const PlatformAdminResult<int> result = PlatformAdminResult<int>.success(7);

      expect(result.isSuccess, isTrue);
      expect(result.value, 7);
      expect(result.failure, isNull);
    });

    test('a failure carries its failure and no value', () {
      const PlatformAdminResult<int> result = PlatformAdminResult<int>.failure(PlatformAdminFailure.network());

      expect(result.isSuccess, isFalse);
      expect(result.value, isNull);
      expect(result.failure!.kind, PlatformAdminFailureKind.network);
    });
  });
}
