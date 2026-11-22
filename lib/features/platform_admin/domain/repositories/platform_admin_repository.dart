import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_alert_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_audit_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_json.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_market_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_mfa_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_overview_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_session_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/repositories/platform_admin_api_client.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/repositories/platform_admin_repository_interface.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/repositories/platform_admin_token_store.dart';

/// Holds the platform session, and is the only thing that does.
///
/// It talks only to [PlatformAdminApiClient] and [PlatformAdminTokenStore]. It has
/// no seller repository, no seller client and no seller storage, so signing in
/// here cannot start a seller session and signing out cannot end one.
///
/// A token the server refuses is dropped on the spot, here, so that no path of
/// the app can go on using a session that is over. Nothing is sent without a
/// token except the sign-in.
class PlatformAdminRepository implements PlatformAdminRepositoryInterface {
  final PlatformAdminApiClient apiClient;
  final PlatformAdminTokenStore tokenStore;
  final DateTime Function() _now;

  String? _token;

  PlatformAdminRepository({required this.apiClient, required this.tokenStore, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  @override
  Future<PlatformAdminResult<PlatformAdminSignInStep>> signIn({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    final PlatformAdminResult<PlatformAdminReply> result = await apiClient.post(
      '/auth/login',
      body: <String, Object?>{'email': email, 'password': password, 'device_name': deviceName},
    );
    final PlatformAdminResult<PlatformAdminSignInStep> shaped = _shaped(result, (PlatformAdminReply reply) {
      return reply.data is Map ? PlatformAdminSignInStep.fromJson(PlatformJson.map(reply.data)) : null;
    });
    final PlatformAdminSignInStep? step = shaped.value;

    // A refusal, or a challenge: no session exists yet, so there is nothing to keep.
    if (step is! PlatformAdminSessionOpened) return shaped;

    final PlatformAdminFailure? failure = await _open(step.signIn);
    return failure == null ? shaped : PlatformAdminResult<PlatformAdminSignInStep>.failure(failure);
  }

  @override
  Future<PlatformAdminResult<PlatformAdminSignIn>> signInWithSecondFactor({
    required String challenge,
    required PlatformAdminMfaMethod method,
    required String code,
  }) async {
    final PlatformAdminResult<PlatformAdminReply> result = await apiClient.post(
      '/auth/mfa',
      body: <String, Object?>{
        'challenge': challenge,
        switch (method) {
          PlatformAdminMfaMethod.totp => 'code',
          PlatformAdminMfaMethod.recoveryCode => 'recovery_code',
        }: code,
      },
    );
    final PlatformAdminResult<PlatformAdminSignIn> shaped = _shaped(result, (PlatformAdminReply reply) {
      return reply.data is Map ? PlatformAdminSignIn.fromJson(PlatformJson.map(reply.data)) : null;
    });
    final PlatformAdminSignIn? signIn = shaped.value;
    if (signIn == null) return shaped;

    final PlatformAdminFailure? failure = await _open(signIn);
    return failure == null ? shaped : PlatformAdminResult<PlatformAdminSignIn>.failure(failure);
  }

  @override
  Future<PlatformAdminResult<PlatformAdminProfile?>> restore() async {
    final StoredPlatformSession? stored = await tokenStore.read();
    if (stored == null) return const PlatformAdminResult<PlatformAdminProfile?>.success(null);

    final DateTime? expiresAt = stored.expiresAt;
    if (expiresAt != null && !expiresAt.isAfter(_now())) {
      await _forget();
      return const PlatformAdminResult<PlatformAdminProfile?>.failure(PlatformAdminFailure.unauthenticated());
    }

    _token = stored.token;
    return _authenticated<PlatformAdminProfile?>(
        (String token) => apiClient.get('/me', bearerToken: token), _profileOf);
  }

  @override
  Future<PlatformAdminResult<PlatformAdminProfile>> profile() =>
      _authenticated<PlatformAdminProfile>((String token) => apiClient.get('/me', bearerToken: token), _profileOf);

  @override
  Future<void> signOut() async {
    final String? token = _token;
    await _forget();
    if (token != null) await apiClient.post('/auth/logout', bearerToken: token);
  }

  @override
  Future<PlatformAdminResult<PlatformMarketDirectory>> markets() => _authenticated<PlatformMarketDirectory>(
        (String token) => apiClient.get('/markets', bearerToken: token),
        (PlatformAdminReply reply) =>
            reply.data is Map ? PlatformMarketDirectory.fromJson(PlatformJson.map(reply.data)) : null,
      );

  @override
  Future<PlatformAdminResult<PlatformOverviewModel>> overview({required String market, String? from}) =>
      _authenticated<PlatformOverviewModel>(
        (String token) => apiClient.get(
          '/overview',
          bearerToken: token,
          query: <String, String>{'market': market, if (from != null) 'from': from},
        ),
        (PlatformAdminReply reply) =>
            reply.data is Map ? PlatformOverviewModel.fromJson(PlatformJson.map(reply.data)) : null,
      );

  @override
  Future<PlatformAdminResult<PlatformAlertPage>> alerts({
    required String market,
    required int page,
    required int perPage,
    String? severity,
  }) =>
      _authenticated<PlatformAlertPage>(
        (String token) => apiClient.get(
          '/alerts',
          bearerToken: token,
          query: <String, String>{
            'market': market,
            'page': '$page',
            'per_page': '$perPage',
            if (severity != null) 'severity': severity,
          },
        ),
        (PlatformAdminReply reply) =>
            reply.data is List ? PlatformAlertPage.fromJson(PlatformJson.maps(reply.data), reply.meta) : null,
      );

  @override
  Future<PlatformAdminResult<List<PlatformSessionModel>>> sessions() => _authenticated<List<PlatformSessionModel>>(
        (String token) => apiClient.get('/sessions', bearerToken: token),
        (PlatformAdminReply reply) =>
            reply.data is List ? PlatformJson.maps(reply.data).map(PlatformSessionModel.fromJson).toList() : null,
      );

  @override
  Future<PlatformAdminResult<int>> endSession(int id) => _authenticated<int>(
        (String token) => apiClient.delete('/sessions/$id', bearerToken: token),
        (PlatformAdminReply reply) =>
            reply.data is Map ? PlatformJson.integer(PlatformJson.map(reply.data)['id']) : null,
      );

  @override
  Future<PlatformAdminResult<int>> endOtherSessions() => _authenticated<int>(
        (String token) => apiClient.delete('/sessions', bearerToken: token),
        (PlatformAdminReply reply) =>
            reply.data is Map ? PlatformJson.integer(PlatformJson.map(reply.data)['ended']) : null,
      );

  @override
  Future<PlatformAdminResult<PlatformAuditPage>> auditLogs({required int page, required int perPage}) =>
      _authenticated<PlatformAuditPage>(
        (String token) => apiClient.get(
          '/audit-logs',
          bearerToken: token,
          query: <String, String>{'page': '$page', 'per_page': '$perPage'},
        ),
        (PlatformAdminReply reply) =>
            reply.data is List ? PlatformAuditPage.fromJson(PlatformJson.maps(reply.data), reply.meta) : null,
      );

  PlatformAdminProfile? _profileOf(PlatformAdminReply reply) =>
      reply.data is Map ? PlatformAdminProfile.fromJson(PlatformJson.map(reply.data)) : null;

  Future<PlatformAdminResult<T>> _authenticated<T>(
    Future<PlatformAdminResult<PlatformAdminReply>> Function(String token) call,
    T? Function(PlatformAdminReply reply) parse,
  ) async {
    final String? token = _token;
    if (token == null) return PlatformAdminResult<T>.failure(const PlatformAdminFailure.unauthenticated());

    final PlatformAdminResult<PlatformAdminReply> result = await call(token);

    // Only the session that asked is dropped: an answer that arrives after the
    // admin has signed out and in again must not end the new one.
    if (result.failure?.kind == PlatformAdminFailureKind.unauthenticated && token == _token) {
      await _forget();
    }
    return _shaped(result, parse);
  }

  PlatformAdminResult<T> _shaped<T>(
      PlatformAdminResult<PlatformAdminReply> result, T? Function(PlatformAdminReply reply) parse) {
    final PlatformAdminReply? reply = result.value;
    if (reply == null) return PlatformAdminResult<T>.failure(result.failure!);

    final T? value = parse(reply);
    return value == null
        ? PlatformAdminResult<T>.failure(const PlatformAdminFailure.malformed())
        : PlatformAdminResult<T>.success(value);
  }

  /// Keeps the session an answer opened, here and in the secure storage. An answer with no token is one that
  /// cannot be used, and keeps nothing.
  Future<PlatformAdminFailure?> _open(PlatformAdminSignIn signIn) async {
    if (signIn.token.isEmpty) return const PlatformAdminFailure.malformed();

    _token = signIn.token;
    await tokenStore.write(StoredPlatformSession(token: signIn.token, expiresAt: signIn.expiresAt));
    return null;
  }

  Future<void> _forget() {
    _token = null;
    return tokenStore.clear();
  }
}
