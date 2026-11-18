import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_capability_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_mfa_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_overview_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_session_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/repositories/platform_admin_api_client.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/repositories/platform_admin_repository.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/repositories/platform_admin_token_store.dart';

import 'support/fixtures.dart';
import 'support/scripted_adapter.dart';

const String _password = 'the-admins-own-password';
const String _email = 'owner@example.test';

/// The platform session, from sign-in to sign-out, against the bodies the real
/// API produced and a Keystore that is only a map.
void main() {
  late Map<String, String> secure;
  late SecurePlatformAdminTokenStore store;
  late DateTime now;

  setUp(() {
    secure = <String, String>{};
    FlutterSecureStorage.setMockInitialValues(secure);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    store = SecurePlatformAdminTokenStore();
    now = DateTime.utc(2026, 11, 17, 10);
  });

  PlatformAdminRepository repositoryOn(ScriptedAdapter adapter) {
    final PlatformAdminApiClient client =
        PlatformAdminApiClient(baseUrl: 'https://lavkoo.com', languageCode: () => 'en');
    client.dio.httpClientAdapter = adapter;
    return PlatformAdminRepository(apiClient: client, tokenStore: store, now: () => now);
  }

  Future<PlatformAdminRepository> signedIn(ScriptedAdapter adapter) async {
    final PlatformAdminRepository repository = repositoryOn(adapter);
    await repository.signIn(email: _email, password: _password, deviceName: 'Pixel 9');
    adapter.requests.clear();
    return repository;
  }

  const Map<String, String> routes = <String, String>{
    'POST /auth/login': 'login_success',
    'POST /auth/logout': 'logout',
    'GET /me': 'me_owner',
    'GET /markets': 'markets_owner',
    'GET /overview': 'overview_owner_all',
    'GET /alerts': 'alerts_owner',
    'GET /sessions': 'sessions_owner',
    'DELETE /sessions/2': 'session_revoked',
    'DELETE /sessions': 'sessions_end_others',
    'GET /audit-logs': 'audit_logs_owner',
  };

  group('signing in', () {
    test('sends the credentials to the platform sign-in and keeps the token it is given, once, in secure storage',
        () async {
      final ScriptedAdapter adapter = ScriptedAdapter.routing(routes);

      final PlatformAdminResult<PlatformAdminSignInStep> result =
          await repositoryOn(adapter).signIn(email: _email, password: _password, deviceName: 'Pixel 9');

      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.uri.path, '/api/platform-admin/v1/auth/login');
      expect(adapter.requests.single.data,
          <String, Object?>{'email': _email, 'password': _password, 'device_name': 'Pixel 9'});
      expect((result.value! as PlatformAdminSessionOpened).signIn.profile.adminId, 4);
      final StoredPlatformSession stored = (await store.read())!;
      expect(stored.token, fixtureToken);
      expect(stored.expiresAt, DateTime.utc(2026, 11, 17, 14));
    });

    test('keeps neither the e-mail nor the password anywhere', () async {
      final SharedPreferences preferences = await SharedPreferences.getInstance();

      await repositoryOn(ScriptedAdapter.routing(routes))
          .signIn(email: _email, password: _password, deviceName: 'Pixel 9');

      expect(secure.values.join(), isNot(contains(_password)));
      expect(secure.values.join(), isNot(contains(_email)));
      expect(preferences.getKeys(), isEmpty);
    });

    test('a refused sign-in keeps nothing, and leaves nothing to call the API with', () async {
      final ScriptedAdapter adapter =
          ScriptedAdapter.routing(<String, String>{'POST /auth/login': 'login_failed_wrong_password'});
      final PlatformAdminRepository repository = repositoryOn(adapter);

      final PlatformAdminResult<PlatformAdminSignInStep> result =
          await repository.signIn(email: _email, password: 'wrong', deviceName: 'Pixel 9');
      adapter.requests.clear();
      final PlatformAdminResult<Object?> afterwards = await repository.markets();

      expect(result.failure!.kind, PlatformAdminFailureKind.unauthenticated);
      expect(secure, isEmpty);
      expect(afterwards.failure!.kind, PlatformAdminFailureKind.unauthenticated);
      expect(adapter.requests, isEmpty);
    });

    test('a throttled sign-in says when to try again and keeps nothing', () async {
      final PlatformAdminResult<PlatformAdminSignInStep> result =
          await repositoryOn(ScriptedAdapter.routing(<String, String>{'POST /auth/login': 'error_login_throttled'}))
              .signIn(email: _email, password: _password, deviceName: 'Pixel 9');

      expect(result.failure!.kind, PlatformAdminFailureKind.throttled);
      expect(result.failure!.retryAt, isNotNull);
      expect(secure, isEmpty);
    });

    test('an answer with no token is malformed, keeps nothing and signs nobody in', () async {
      final ScriptedAdapter adapter = ScriptedAdapter.replyingWithBody(
          '{"data": {"token_type": "Bearer", "me": {"admin_id": 4}}}',
          headers: ScriptedAdapter.jsonHeaders);
      final PlatformAdminRepository repository = repositoryOn(adapter);

      final PlatformAdminResult<PlatformAdminSignInStep> result =
          await repository.signIn(email: _email, password: _password, deviceName: 'Pixel 9');
      adapter.requests.clear();
      await repository.markets();

      expect(result.failure!.kind, PlatformAdminFailureKind.malformed);
      expect(secure, isEmpty);
      expect(adapter.requests, isEmpty);
    });

    test('an API that is switched off cannot be signed in to', () async {
      final PlatformAdminResult<PlatformAdminSignInStep> result = await repositoryOn(
              ScriptedAdapter.routing(<String, String>{'POST /auth/login': 'error_api_switched_off_login'}))
          .signIn(email: _email, password: _password, deviceName: 'Pixel 9');

      expect(result.failure!.kind, PlatformAdminFailureKind.notAvailable);
      expect(secure, isEmpty);
    });
  });

  group('picking up a session a previous launch left', () {
    test('with none, there is nothing to pick up and nothing is asked', () async {
      final ScriptedAdapter adapter = ScriptedAdapter.routing(routes);

      final PlatformAdminResult<PlatformAdminProfile?> result = await repositoryOn(adapter).restore();

      expect(result.isSuccess, isTrue);
      expect(result.value, isNull);
      expect(adapter.requests, isEmpty);
    });

    test('asks the server who it belongs to, and goes on using that token', () async {
      await store.write(StoredPlatformSession(token: fixtureToken, expiresAt: DateTime.utc(2026, 11, 17, 14)));
      final ScriptedAdapter adapter = ScriptedAdapter.routing(routes);
      final PlatformAdminRepository repository = repositoryOn(adapter);

      final PlatformAdminResult<PlatformAdminProfile?> result = await repository.restore();
      await repository.markets();

      expect(result.value!.adminId, 4);
      expect(adapter.requests.map((RecordedRequest request) => request.uri.path),
          <String>['/api/platform-admin/v1/me', '/api/platform-admin/v1/markets']);
      expect(adapter.requests.map((RecordedRequest request) => request.header('Authorization')).toSet(),
          <String>{'Bearer $fixtureToken'});
    });

    test('a session whose time has run out is over without asking anyone, and is thrown away', () async {
      await store.write(StoredPlatformSession(token: fixtureToken, expiresAt: now));
      final ScriptedAdapter adapter = ScriptedAdapter.routing(routes);

      final PlatformAdminResult<PlatformAdminProfile?> result = await repositoryOn(adapter).restore();

      expect(result.failure!.kind, PlatformAdminFailureKind.unauthenticated);
      expect(adapter.requests, isEmpty);
      expect(secure, isEmpty);
    });

    test('a session with no end is tried and not refused', () async {
      await store.write(const StoredPlatformSession(token: fixtureToken));

      final PlatformAdminResult<PlatformAdminProfile?> result =
          await repositoryOn(ScriptedAdapter.routing(routes)).restore();

      expect(result.value!.adminId, 4);
    });

    test('a session the server refuses is over, thrown away, and not used again', () async {
      await store.write(StoredPlatformSession(token: fixtureToken, expiresAt: DateTime.utc(2026, 11, 17, 14)));
      final ScriptedAdapter adapter = ScriptedAdapter.routing(<String, String>{'GET /me': 'error_unauthenticated'});
      final PlatformAdminRepository repository = repositoryOn(adapter);

      final PlatformAdminResult<PlatformAdminProfile?> result = await repository.restore();
      adapter.requests.clear();
      await repository.markets();

      expect(result.failure!.kind, PlatformAdminFailureKind.unauthenticated);
      expect(secure, isEmpty);
      expect(adapter.requests, isEmpty);
    });

    test('a session that could not be checked is kept, because nothing says it is over', () async {
      final List<ScriptedAdapter> unable = <ScriptedAdapter>[
        ScriptedAdapter.failingWith(
            (RequestOptions options) => DioException.connectionError(requestOptions: options, reason: 'no route')),
        ScriptedAdapter.routing(<String, String>{'GET /me': 'error_api_switched_off'}),
        ScriptedAdapter.routing(<String, String>{'GET /me': 'error_not_ready'}),
      ];

      for (final ScriptedAdapter adapter in unable) {
        await store.write(StoredPlatformSession(token: fixtureToken, expiresAt: DateTime.utc(2026, 11, 17, 14)));

        final PlatformAdminResult<PlatformAdminProfile?> result = await repositoryOn(adapter).restore();

        expect(result.isSuccess, isFalse);
        expect(result.failure!.kind, isNot(PlatformAdminFailureKind.unauthenticated));
        expect((await store.read())!.token, fixtureToken);
      }
    });
  });

  group('the sign-in when the server wants a second factor', () {
    // A code the fixtures' tokens do not contain, so that looking for it in what was stored means something.
    const String code = '865931';
    const String recoveryCode = 'abcde-fghj2';
    final Map<String, String> twoSteps = <String, String>{
      ...routes,
      'POST /auth/login': 'login_mfa_required',
      'POST /auth/mfa': 'mfa_success_totp',
      'GET /me': 'me_with_capabilities',
    };

    Future<PlatformAdminSecondFactorWanted> passwordStep(PlatformAdminRepository repository) async {
      final PlatformAdminResult<PlatformAdminSignInStep> result =
          await repository.signIn(email: _email, password: _password, deviceName: 'Pixel 9');
      return result.value! as PlatformAdminSecondFactorWanted;
    }

    test('a good password that is not enough gives the challenge, and keeps nothing: there is no session yet',
        () async {
      final ScriptedAdapter adapter = ScriptedAdapter.routing(twoSteps);
      final PlatformAdminRepository repository = repositoryOn(adapter);

      final PlatformAdminSecondFactorWanted wanted = await passwordStep(repository);

      expect(wanted.challenge.value, fixtureChallenge);
      expect(wanted.challenge.expiresAt, DateTime.utc(2026, 11, 17, 10, 5));
      expect(secure, isEmpty);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    });

    test('and leaves nothing to call the API with: no call that needs a session is sent', () async {
      final ScriptedAdapter adapter = ScriptedAdapter.routing(twoSteps);
      final PlatformAdminRepository repository = repositoryOn(adapter);
      await passwordStep(repository);
      adapter.requests.clear();

      final List<PlatformAdminResult<Object?>> afterwards = <PlatformAdminResult<Object?>>[
        await repository.profile(),
        await repository.markets(),
        await repository.sessions(),
        await repository.endOtherSessions(),
      ];

      expect(adapter.requests, isEmpty);
      expect(afterwards.map((PlatformAdminResult<Object?> result) => result.failure!.kind).toSet(),
          <PlatformAdminFailureKind>{PlatformAdminFailureKind.unauthenticated});
    });

    test('a code goes to the second step with the challenge, and with no token and nothing else of a credential',
        () async {
      final ScriptedAdapter adapter = ScriptedAdapter.routing(twoSteps);
      final PlatformAdminRepository repository = repositoryOn(adapter);
      final PlatformAdminSecondFactorWanted wanted = await passwordStep(repository);
      adapter.requests.clear();

      await repository.signInWithSecondFactor(
          challenge: wanted.challenge.value, method: PlatformAdminMfaMethod.totp, code: code);

      final RecordedRequest request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/platform-admin/v1/auth/mfa');
      expect(request.data, <String, Object?>{'challenge': fixtureChallenge, 'code': code});
      expect(request.header('Authorization'), isNull);
      expect(request.everything, isNot(contains(_password)));
      expect(request.everything, isNot(contains(_email)));
    });

    test('a recovery code goes under its own name, and a code never goes under it', () async {
      final ScriptedAdapter adapter = ScriptedAdapter.routing(twoSteps);
      final PlatformAdminRepository repository = repositoryOn(adapter);

      await repository.signInWithSecondFactor(
          challenge: fixtureChallenge, method: PlatformAdminMfaMethod.recoveryCode, code: recoveryCode);

      expect(adapter.requests.single.data,
          <String, Object?>{'challenge': fixtureChallenge, 'recovery_code': recoveryCode});
    });

    test('a code that is right opens the session: the token is kept as the one-step sign-in keeps it, and is used',
        () async {
      final ScriptedAdapter adapter = ScriptedAdapter.routing(twoSteps);
      final PlatformAdminRepository repository = repositoryOn(adapter);

      final PlatformAdminResult<PlatformAdminSignIn> result = await repository.signInWithSecondFactor(
          challenge: fixtureChallenge, method: PlatformAdminMfaMethod.totp, code: code);
      adapter.requests.clear();
      final PlatformAdminResult<PlatformAdminProfile> profile = await repository.profile();

      expect(result.value!.token, fixtureToken);
      final StoredPlatformSession stored = (await store.read())!;
      expect(stored.token, fixtureToken);
      expect(stored.expiresAt, DateTime.utc(2026, 11, 17, 18));
      expect(adapter.requests.single.header('Authorization'), 'Bearer $fixtureToken');
      expect(profile.value!.can(PlatformCapability.sessions), isTrue);
    });

    test('keeps neither the challenge nor the code, nor the password, anywhere', () async {
      final SharedPreferences preferences = await SharedPreferences.getInstance();
      final PlatformAdminRepository repository = repositoryOn(ScriptedAdapter.routing(twoSteps));
      final PlatformAdminSecondFactorWanted wanted = await passwordStep(repository);

      await repository.signInWithSecondFactor(
          challenge: wanted.challenge.value, method: PlatformAdminMfaMethod.totp, code: code);

      expect(secure.keys, <String>[SecurePlatformAdminTokenStore.sessionKey]);
      for (final String secret in <String>[fixtureChallenge, code, _password, _email]) {
        expect(secure.values.join(), isNot(contains(secret)), reason: secret);
      }
      expect(preferences.getKeys(), isEmpty);
    });

    test('the answer says how many recovery codes are left', () async {
      final PlatformAdminResult<PlatformAdminSignIn> result = await repositoryOn(
              ScriptedAdapter.routing(<String, String>{...twoSteps, 'POST /auth/mfa': 'mfa_success_recovery_code'}))
          .signInWithSecondFactor(
              challenge: fixtureChallenge, method: PlatformAdminMfaMethod.recoveryCode, code: recoveryCode);

      expect(result.value!.recoveryCodesLeft, 2);
    });

    test('a refusal says nothing of why, keeps nothing, and is not the refusal of a session', () async {
      final ScriptedAdapter adapter =
          ScriptedAdapter.routing(<String, String>{...twoSteps, 'POST /auth/mfa': 'mfa_failed'});
      final PlatformAdminRepository repository = repositoryOn(adapter);
      await store.write(StoredPlatformSession(token: fixtureToken, expiresAt: DateTime.utc(2026, 11, 17, 14)));

      final PlatformAdminResult<PlatformAdminSignIn> result = await repository.signInWithSecondFactor(
          challenge: fixtureChallenge, method: PlatformAdminMfaMethod.totp, code: code);

      expect(result.failure!.kind, PlatformAdminFailureKind.unauthenticated);
      expect(result.value, isNull);
      expect((await store.read())!.token, fixtureToken,
          reason: 'a wrong code is not a reason to drop a session this phone had stored');
    });

    test('a throttled second step says when to try again and keeps nothing', () async {
      final PlatformAdminResult<PlatformAdminSignIn> result =
          await repositoryOn(ScriptedAdapter.routing(<String, String>{...twoSteps, 'POST /auth/mfa': 'mfa_throttled'}))
              .signInWithSecondFactor(challenge: fixtureChallenge, method: PlatformAdminMfaMethod.totp, code: code);

      expect(result.failure!.kind, PlatformAdminFailureKind.throttled);
      expect(result.failure!.retryAt, isNotNull);
      expect(secure, isEmpty);
    });

    test('no connection is a failure to reach the server, with nothing kept', () async {
      final PlatformAdminResult<PlatformAdminSignIn> result = await repositoryOn(ScriptedAdapter.failingWith(
              (RequestOptions options) => DioException.connectionError(requestOptions: options, reason: 'no route')))
          .signInWithSecondFactor(challenge: fixtureChallenge, method: PlatformAdminMfaMethod.totp, code: code);

      expect(result.failure!.kind, PlatformAdminFailureKind.network);
      expect(secure, isEmpty);
    });

    test('an answer that opens a session with no token is malformed and keeps nothing', () async {
      final ScriptedAdapter adapter = ScriptedAdapter.replyingWithBody(
          '{"data": {"token_type": "Bearer", "me": {"admin_id": 4}, "mfa": {"state": "verified"}}}',
          headers: ScriptedAdapter.jsonHeaders);

      final PlatformAdminResult<PlatformAdminSignIn> result = await repositoryOn(adapter)
          .signInWithSecondFactor(challenge: fixtureChallenge, method: PlatformAdminMfaMethod.totp, code: code);

      expect(result.failure!.kind, PlatformAdminFailureKind.malformed);
      expect(secure, isEmpty);
    });

    test('an answer that asks for a code and also carries a token opens no session', () async {
      final ScriptedAdapter adapter = ScriptedAdapter.replyingWithBody(
          '{"data": {"mfa_required": true, "challenge": "$fixtureChallenge", "token": "$fixtureToken"}}',
          headers: ScriptedAdapter.jsonHeaders);
      final PlatformAdminRepository repository = repositoryOn(adapter);

      final PlatformAdminResult<PlatformAdminSignInStep> result =
          await repository.signIn(email: _email, password: _password, deviceName: 'Pixel 9');
      adapter.requests.clear();
      await repository.markets();

      expect(result.value, isA<PlatformAdminSecondFactorWanted>());
      expect(secure, isEmpty);
      expect(adapter.requests, isEmpty, reason: 'the token that was there was never used');
    });

    test('an answer that asks for a code and carries no challenge is malformed', () async {
      final ScriptedAdapter adapter =
          ScriptedAdapter.replyingWithBody('{"data": {"mfa_required": true}}', headers: ScriptedAdapter.jsonHeaders);

      final PlatformAdminResult<PlatformAdminSignInStep> result =
          await repositoryOn(adapter).signIn(email: _email, password: _password, deviceName: 'Pixel 9');

      expect(result.failure!.kind, PlatformAdminFailureKind.malformed);
      expect(secure, isEmpty);
    });

    test('a locked-out admin who gives the right password is told when to try again, with no challenge', () async {
      final PlatformAdminResult<PlatformAdminSignInStep> result = await repositoryOn(
              ScriptedAdapter.routing(<String, String>{...twoSteps, 'POST /auth/login': 'error_login_throttled'}))
          .signIn(email: _email, password: _password, deviceName: 'Pixel 9');

      expect(result.failure!.kind, PlatformAdminFailureKind.throttled);
      expect(result.value, isNull);
    });

    test('a server that does not require a second factor still opens the session at the password, as it always did',
        () async {
      final ScriptedAdapter adapter = ScriptedAdapter.routing(routes);

      final PlatformAdminResult<PlatformAdminSignInStep> result =
          await repositoryOn(adapter).signIn(email: _email, password: _password, deviceName: 'Pixel 9');

      expect(result.value, isA<PlatformAdminSessionOpened>());
      expect((await store.read())!.token, fixtureToken);
    });
  });

  group('ending the other sessions', () {
    test('asks the server to end every session but this one, with this token, and says how many it ended', () async {
      final ScriptedAdapter adapter = ScriptedAdapter.routing(routes);
      final PlatformAdminRepository repository = await signedIn(adapter);

      final PlatformAdminResult<int> result = await repository.endOtherSessions();

      final RecordedRequest request = adapter.requests.single;
      expect(request.method, 'DELETE');
      expect(request.uri.path, '/api/platform-admin/v1/sessions');
      expect(request.header('Authorization'), 'Bearer $fixtureToken');
      expect(result.value, 2);
    });

    test('none ended is zero, and a success', () async {
      final PlatformAdminRepository repository = await signedIn(
          ScriptedAdapter.routing(<String, String>{...routes, 'DELETE /sessions': 'sessions_end_others_none'}));

      final PlatformAdminResult<int> result = await repository.endOtherSessions();

      expect(result.isSuccess, isTrue);
      expect(result.value, 0);
    });

    test('a refusal of the token ends the session for good', () async {
      final ScriptedAdapter adapter =
          ScriptedAdapter.routing(<String, String>{...routes, 'DELETE /sessions': 'error_unauthenticated'});
      final PlatformAdminRepository repository = await signedIn(adapter);

      final PlatformAdminResult<int> result = await repository.endOtherSessions();

      expect(result.failure!.kind, PlatformAdminFailureKind.unauthenticated);
      expect(secure, isEmpty);
    });

    test('a part the grant leaves out is a refusal, and the session stays', () async {
      final PlatformAdminRepository repository = await signedIn(
          ScriptedAdapter.routing(<String, String>{...routes, 'DELETE /sessions': 'error_capability_not_allowed'}));

      final PlatformAdminResult<int> result = await repository.endOtherSessions();

      expect(result.failure!.kind, PlatformAdminFailureKind.capabilityNotAllowed);
      expect((await store.read())!.token, fixtureToken);
    });

    test('an answer with no count is malformed', () async {
      final PlatformAdminRepository repository =
          await signedIn(ScriptedAdapter((RequestOptions options, RecordedRequest request) async {
        return request.method == 'DELETE'
            ? ResponseBody.fromString('{"data": {"revoked": true}}', 200, headers: ScriptedAdapter.jsonHeaders)
            : ScriptedAdapter.reply('login_success');
      }));

      final PlatformAdminResult<int> result = await repository.endOtherSessions();

      expect(result.failure!.kind, PlatformAdminFailureKind.malformed);
    });
  });

  group('every call after sign-in', () {
    test('without a session sends nothing and says there is no session', () async {
      final ScriptedAdapter adapter = ScriptedAdapter.routing(routes);
      final PlatformAdminRepository repository = repositoryOn(adapter);

      final List<PlatformAdminResult<Object?>> results = <PlatformAdminResult<Object?>>[
        await repository.profile(),
        await repository.markets(),
        await repository.overview(market: 'all'),
        await repository.alerts(market: 'all', page: 1, perPage: 50),
        await repository.sessions(),
        await repository.endSession(2),
        await repository.endOtherSessions(),
        await repository.auditLogs(page: 1, perPage: 25),
      ];

      expect(adapter.requests, isEmpty);
      expect(results.map((PlatformAdminResult<Object?> result) => result.failure!.kind).toSet(),
          <PlatformAdminFailureKind>{PlatformAdminFailureKind.unauthenticated});
    });

    test('carry the token the sign-in gave, and nothing else of a credential', () async {
      final ScriptedAdapter adapter = ScriptedAdapter.routing(routes);
      final PlatformAdminRepository repository = await signedIn(adapter);

      await repository.profile();
      await repository.markets();
      await repository.overview(market: 'all');
      await repository.alerts(market: 'all', page: 1, perPage: 50);
      await repository.sessions();
      await repository.endSession(2);
      await repository.endOtherSessions();
      await repository.auditLogs(page: 1, perPage: 25);

      expect(adapter.requests, hasLength(8));
      for (final RecordedRequest request in adapter.requests) {
        expect(request.header('Authorization'), 'Bearer $fixtureToken');
        expect(request.everything, isNot(contains(_password)));
      }
    });

    test('the overview asks for the market and, when there is one, the first day of the window', () async {
      final ScriptedAdapter adapter = ScriptedAdapter.routing(routes);
      final PlatformAdminRepository repository = await signedIn(adapter);

      await repository.overview(market: 'KW');
      await repository.overview(market: 'all', from: '2026-11-11');

      expect(adapter.requests.first.uri.query, 'market=KW');
      expect(adapter.requests.last.uri.query, 'market=all&from=2026-11-11');
    });

    test('the alerts ask for the market, the page and its size, and the severity only when there is one', () async {
      final ScriptedAdapter adapter = ScriptedAdapter.routing(routes);
      final PlatformAdminRepository repository = await signedIn(adapter);

      await repository.alerts(market: 'KW', page: 2, perPage: 50);
      await repository.alerts(market: 'all', page: 1, perPage: 50, severity: 'critical');

      expect(adapter.requests.first.uri.query, 'market=KW&page=2&per_page=50');
      expect(adapter.requests.last.uri.query, 'market=all&page=1&per_page=50&severity=critical');
    });

    test('the audit log asks for the page and its size, and a session is ended by its own id', () async {
      final ScriptedAdapter adapter = ScriptedAdapter.routing(routes);
      final PlatformAdminRepository repository = await signedIn(adapter);

      await repository.auditLogs(page: 3, perPage: 25);
      final PlatformAdminResult<int> ended = await repository.endSession(2);

      expect(adapter.requests.first.uri.query, 'page=3&per_page=25');
      expect(adapter.requests.last.method, 'DELETE');
      expect(adapter.requests.last.uri.path, '/api/platform-admin/v1/sessions/2');
      expect(ended.value, 2);
    });

    test('read the answer into the models the screens use', () async {
      final PlatformAdminRepository repository = await signedIn(ScriptedAdapter.routing(routes));

      expect((await repository.profile()).value!.markets, hasLength(6));
      expect((await repository.markets()).value!.codes, hasLength(6));
      expect((await repository.overview(market: 'all')).value!.markets, hasLength(6));
      expect((await repository.alerts(market: 'all', page: 1, perPage: 50)).value!.alerts, hasLength(4));
      expect((await repository.sessions()).value!.where((PlatformSessionModel session) => session.isCurrent),
          hasLength(1));
      expect((await repository.auditLogs(page: 1, perPage: 25)).value!.lines, hasLength(25));
    });

    test('an answer of the wrong shape is malformed and not a crash', () async {
      final PlatformAdminRepository repository =
          await signedIn(ScriptedAdapter((RequestOptions options, RecordedRequest request) async {
        return request.uri.path.endsWith('/auth/login')
            ? ScriptedAdapter.reply('login_success')
            : ResponseBody.fromString('{"data": "nothing"}', 200, headers: ScriptedAdapter.jsonHeaders);
      }));

      final List<PlatformAdminResult<Object?>> results = <PlatformAdminResult<Object?>>[
        await repository.profile(),
        await repository.markets(),
        await repository.overview(market: 'all'),
        await repository.alerts(market: 'all', page: 1, perPage: 50),
        await repository.sessions(),
        await repository.endSession(2),
        await repository.endOtherSessions(),
        await repository.auditLogs(page: 1, perPage: 25),
      ];

      expect(results.map((PlatformAdminResult<Object?> result) => result.failure?.kind).toSet(),
          <PlatformAdminFailureKind?>{PlatformAdminFailureKind.malformed});
      expect((await store.read())?.token, fixtureToken,
          reason: 'an answer that cannot be read is not a refusal of the token');
    });

    test('a refusal of the token ends the session for good, whichever call met it', () async {
      final ScriptedAdapter adapter =
          ScriptedAdapter.routing(<String, String>{...routes, 'GET /overview': 'error_unauthenticated'});
      final PlatformAdminRepository repository = await signedIn(adapter);

      final PlatformAdminResult<PlatformOverviewModel> result = await repository.overview(market: 'all');
      adapter.requests.clear();
      final PlatformAdminResult<Object?> afterwards = await repository.sessions();

      expect(result.failure!.kind, PlatformAdminFailureKind.unauthenticated);
      expect(secure, isEmpty);
      expect(afterwards.failure!.kind, PlatformAdminFailureKind.unauthenticated);
      expect(adapter.requests, isEmpty);
    });

    test('any other failure leaves the session alone', () async {
      for (final String refusal in <String>[
        'error_market_not_allowed',
        'error_invalid_market',
        'error_login_throttled',
        'error_not_ready',
        'error_api_switched_off'
      ]) {
        final PlatformAdminRepository repository =
            await signedIn(ScriptedAdapter.routing(<String, String>{...routes, 'GET /overview': refusal}));

        await repository.overview(market: 'all');

        expect((await store.read())?.token, fixtureToken, reason: refusal);
      }
    });

    test('an answer that comes after the admin has signed out and in again does not end the new session', () async {
      const String secondToken = 'lkpa_SECONDSESSION0123456789SECONDSESSION0123456789SECONDSESSION01234';
      final Completer<void> late = Completer<void>();
      int logins = 0;
      final ScriptedAdapter adapter = ScriptedAdapter((RequestOptions options, RecordedRequest request) async {
        if (request.uri.path.endsWith('/overview')) {
          await late.future;
          return ScriptedAdapter.reply('error_unauthenticated');
        }
        if (request.uri.path.endsWith('/auth/login')) {
          logins++;
          final String body = rawFixture('login_success');
          return ResponseBody.fromString(logins == 1 ? body : body.replaceAll(fixtureToken, secondToken), 200,
              headers: ScriptedAdapter.jsonHeaders);
        }
        return ScriptedAdapter.reply('logout');
      });
      final PlatformAdminRepository repository = repositoryOn(adapter);
      await repository.signIn(email: _email, password: _password, deviceName: 'Pixel 9');
      final Future<PlatformAdminResult<PlatformOverviewModel>> inFlight = repository.overview(market: 'all');

      await repository.signOut();
      await repository.signIn(email: _email, password: _password, deviceName: 'Pixel 9 again');
      late.complete();
      final PlatformAdminResult<PlatformOverviewModel> result = await inFlight;

      expect(result.failure!.kind, PlatformAdminFailureKind.unauthenticated);
      expect(logins, 2);
      expect((await store.read())?.token, secondToken, reason: 'the old session was refused, the new one is not');
      expect((await repository.profile()).isSuccess, isTrue);
    });
  });

  group('signing out', () {
    test('ends the session on this phone and asks the server to end it there, with the token it had', () async {
      final ScriptedAdapter adapter = ScriptedAdapter.routing(routes);
      final PlatformAdminRepository repository = await signedIn(adapter);

      await repository.signOut();

      expect(secure, isEmpty);
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.uri.path, '/api/platform-admin/v1/auth/logout');
      expect(adapter.requests.single.header('Authorization'), 'Bearer $fixtureToken');
    });

    test('is over on this phone even when the server cannot be reached', () async {
      final PlatformAdminRepository repository =
          await signedIn(ScriptedAdapter((RequestOptions options, RecordedRequest request) async {
        if (request.uri.path.endsWith('/auth/login')) return ScriptedAdapter.reply('login_success');
        throw DioException.connectionError(requestOptions: options, reason: 'no route');
      }));

      await repository.signOut();

      expect(secure, isEmpty);
    });

    test('with no session sends nothing', () async {
      final ScriptedAdapter adapter = ScriptedAdapter.routing(routes);

      await repositoryOn(adapter).signOut();

      expect(adapter.requests, isEmpty);
    });

    test('leaves nothing to call the API with afterwards', () async {
      final ScriptedAdapter adapter = ScriptedAdapter.routing(routes);
      final PlatformAdminRepository repository = await signedIn(adapter);
      await repository.signOut();
      adapter.requests.clear();

      final PlatformAdminResult<Object?> afterwards = await repository.overview(market: 'all');

      expect(afterwards.failure!.kind, PlatformAdminFailureKind.unauthenticated);
      expect(adapter.requests, isEmpty);
    });
  });
}
