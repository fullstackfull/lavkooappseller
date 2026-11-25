import 'dart:async';

import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_alert_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_audit_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_market_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_mfa_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_health_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_overview_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_session_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/services/platform_admin_service_interface.dart';

import 'fixtures.dart';

/// What a refusal looks like to the controller, made the way the client makes it.
PlatformAdminFailure refusal(String fixtureName, {DateTime? now}) => PlatformAdminFailure.fromResponse(
      statusCode: fixtureStatus(fixtureName),
      body: fixture(fixtureName),
      retryAfter: fixtureRetryAfter(fixtureName),
      now: now,
    );

/// A refusal; with [now], a wait the API names is counted from that moment and not from the wall clock.
PlatformAdminResult<T> refused<T>(String fixtureName, {DateTime? now}) =>
    PlatformAdminResult<T>.failure(refusal(fixtureName, now: now));

PlatformAdminResult<T> unreachable<T>() => PlatformAdminResult<T>.failure(const PlatformAdminFailure.network());

PlatformAdminProfile ownerProfile() => PlatformAdminProfile.fromJson(fixtureData('me_owner'));

PlatformAdminProfile restrictedProfile() => PlatformAdminProfile.fromJson(fixtureData('me_restricted'));

PlatformAdminSignIn ownerSignIn() => PlatformAdminSignIn.fromJson(fixtureData('login_success'));

/// The answer of the password step that asks for a code.
PlatformAdminSignInStep secondFactorWanted() => PlatformAdminSignInStep.fromJson(fixtureData('login_mfa_required'))!;

/// The answer of the second step, by the name of the fixture that carries it.
PlatformAdminSignIn secondFactorSignIn([String fixtureName = 'mfa_success_totp']) =>
    PlatformAdminSignIn.fromJson(fixtureData(fixtureName));

/// The service behind the controller: scripted, and it remembers what it was asked.
///
/// Every answer is a function so that a test can hold one back and let it go
/// later, which is how a late answer is made.
class FakePlatformAdminService implements PlatformAdminServiceInterface {
  final List<String> calls = <String>[];

  Future<PlatformAdminResult<PlatformAdminSignInStep>> Function() onSignIn =
      () async => PlatformAdminResult<PlatformAdminSignInStep>.success(PlatformAdminSessionOpened(ownerSignIn()));

  /// What each attempt at the second step handed over, in order: the challenge, the way and the code.
  final List<({String challenge, PlatformAdminMfaMethod method, String code})> secondFactorAttempts =
      <({String challenge, PlatformAdminMfaMethod method, String code})>[];

  Future<PlatformAdminResult<PlatformAdminSignIn>> Function() onSignInWithSecondFactor =
      () async => PlatformAdminResult<PlatformAdminSignIn>.success(secondFactorSignIn());

  Future<PlatformAdminResult<PlatformAdminProfile?>> Function() onRestore =
      () async => const PlatformAdminResult<PlatformAdminProfile?>.success(null);

  Future<PlatformAdminResult<PlatformAdminProfile>> Function() onProfile =
      () async => PlatformAdminResult<PlatformAdminProfile>.success(ownerProfile());

  Future<void> Function() onSignOut = () async {};

  Future<PlatformAdminResult<PlatformMarketDirectory>> Function() onMarkets = () async =>
      PlatformAdminResult<PlatformMarketDirectory>.success(
          PlatformMarketDirectory.fromJson(fixtureData('markets_owner')));

  Future<PlatformAdminResult<PlatformOverviewModel>> Function(String market, int? windowDays) onOverview =
      (String market, int? windowDays) async =>
          PlatformAdminResult<PlatformOverviewModel>.success(overviewOf(market, windowDays));

  Future<PlatformAdminResult<PlatformHealthModel>> Function(String market, int? windowDays) onHealth =
      (String market, int? windowDays) async => PlatformAdminResult<PlatformHealthModel>.success(healthOf(market));

  Future<PlatformAdminResult<PlatformAlertPage>> Function(String market, int page, String? severity) onAlerts =
      (String market, int page, String? severity) async =>
          PlatformAdminResult<PlatformAlertPage>.success(alertsOf(market, page, severity));

  Future<PlatformAdminResult<List<PlatformSessionModel>>> Function() onSessions = () async =>
      PlatformAdminResult<List<PlatformSessionModel>>.success(
          fixtureRows('sessions_owner').map(PlatformSessionModel.fromJson).toList());

  Future<PlatformAdminResult<int>> Function(int id) onEndSession =
      (int id) async => PlatformAdminResult<int>.success(id);

  Future<PlatformAdminResult<int>> Function() onEndOtherSessions =
      () async => const PlatformAdminResult<int>.success(2);

  Future<PlatformAdminResult<PlatformAuditPage>> Function(int page) onAuditLogs =
      (int page) async => PlatformAdminResult<PlatformAuditPage>.success(auditOf(page));

  int count(String prefix) => calls.where((String call) => call.startsWith(prefix)).length;

  /// The overview of the real answers that fits what was asked.
  static PlatformOverviewModel overviewOf(String market, int? windowDays) {
    final String fixtureName = switch ((market, windowDays)) {
      ('KW', _) => 'overview_owner_kw',
      (_, 7) => 'overview_owner_window_7',
      _ => 'overview_owner_all',
    };
    return PlatformOverviewModel.fromJson(fixtureData(fixtureName));
  }

  /// Every market's health, or one market's: Kuwait answers with its own, which has no unattributed row.
  static PlatformHealthModel healthOf(String market) =>
      PlatformHealthModel.fromJson(fixtureData(market == 'KW' ? 'health_owner_kw' : 'health_owner_all'));

  /// All markets answer with two pages of three and one, a market with nothing wrong with none.
  static PlatformAlertPage alertsOf(String market, int page, String? severity) {
    final String fixtureName;
    if (market == 'QA') {
      fixtureName = 'alerts_owner_qa_none';
    } else if (page == 2) {
      fixtureName = 'alerts_owner_page_2_of_2';
    } else if (severity == 'critical') {
      fixtureName = 'alerts_owner_critical';
    } else {
      fixtureName = 'alerts_owner_page_1_of_2';
    }
    return PlatformAlertPage.fromJson(fixtureRows(fixtureName), fixtureMeta(fixtureName));
  }

  static PlatformAuditPage auditOf(int page) {
    final String fixtureName = page == 1 ? 'audit_logs_owner_page_1_of_n' : 'audit_logs_owner';
    final List<Map<String, dynamic>> rows = fixtureRows(fixtureName);
    return PlatformAuditPage.fromJson(
      rows,
      <String, dynamic>{...fixtureMeta(fixtureName), 'page': page, 'has_more': page == 1},
    );
  }

  @override
  Future<PlatformAdminResult<PlatformAdminSignInStep>> signIn({
    required String email,
    required String password,
    required String deviceName,
  }) {
    calls.add('signIn $email/$deviceName');
    return onSignIn();
  }

  @override
  Future<PlatformAdminResult<PlatformAdminSignIn>> signInWithSecondFactor({
    required String challenge,
    required PlatformAdminMfaMethod method,
    required String code,
  }) {
    calls.add('signInWithSecondFactor ${method.name}');
    secondFactorAttempts.add((challenge: challenge, method: method, code: code));
    return onSignInWithSecondFactor();
  }

  @override
  Future<PlatformAdminResult<PlatformAdminProfile?>> restore() {
    calls.add('restore');
    return onRestore();
  }

  @override
  Future<PlatformAdminResult<PlatformAdminProfile>> profile() {
    calls.add('profile');
    return onProfile();
  }

  @override
  Future<void> signOut() {
    calls.add('signOut');
    return onSignOut();
  }

  @override
  Future<PlatformAdminResult<PlatformMarketDirectory>> markets() {
    calls.add('markets');
    return onMarkets();
  }

  @override
  Future<PlatformAdminResult<PlatformOverviewModel>> overview({required String market, int? windowDays}) {
    calls.add('overview $market $windowDays');
    return onOverview(market, windowDays);
  }

  @override
  Future<PlatformAdminResult<PlatformHealthModel>> health({required String market, int? windowDays}) {
    calls.add('health $market $windowDays');
    return onHealth(market, windowDays);
  }

  @override
  Future<PlatformAdminResult<PlatformAlertPage>> alerts({required String market, required int page, String? severity}) {
    calls.add('alerts $market p$page $severity');
    return onAlerts(market, page, severity);
  }

  @override
  Future<PlatformAdminResult<List<PlatformSessionModel>>> sessions() {
    calls.add('sessions');
    return onSessions();
  }

  @override
  Future<PlatformAdminResult<int>> endSession(int id) {
    calls.add('endSession $id');
    return onEndSession(id);
  }

  @override
  Future<PlatformAdminResult<int>> endOtherSessions() {
    calls.add('endOtherSessions');
    return onEndOtherSessions();
  }

  @override
  Future<PlatformAdminResult<PlatformAuditPage>> auditLogs({required int page}) {
    calls.add('auditLogs p$page');
    return onAuditLogs(page);
  }
}

/// An answer held back until the test lets it go.
class Gate<T> {
  final Completer<T> _completer = Completer<T>();

  Future<T> get future => _completer.future;

  void open(T value) => _completer.complete(value);
}
