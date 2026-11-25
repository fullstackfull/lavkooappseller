import 'package:flutter/foundation.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_alert_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_audit_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_capability_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_market_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_mfa_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_health_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_overview_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_session_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/services/platform_admin_service_interface.dart';

enum PlatformAdminStage {
  /// Looking for the session a previous launch left, and asking who it belongs to.
  restoring,

  /// The session was there but could not be checked: no connection, or the API is not ready.
  restoreFailed,

  signedOut,
  signingIn,

  /// The password was accepted and no session exists yet: a code is wanted. What the API gave for it is held
  /// by the controller, in memory, until the code opens a session or the step is left.
  secondFactor,
  signedIn,
}

typedef _OverviewKey = ({String market, int? windowDays});
typedef _HealthKey = ({String market, int? windowDays});
typedef _AlertsKey = ({String market, String? severity});

class _AlertList {
  final List<PlatformAlertModel> items;
  final int lastPage;
  final int total;
  final bool hasMore;

  const _AlertList({required this.items, required this.lastPage, required this.total, required this.hasMore});
}

/// The platform admin principal: who is signed in, and the state of every screen
/// of the shell.
///
/// One controller for one principal, created when the shell is opened and gone
/// when it is left. Everything it holds is in memory, keyed by what was asked,
/// and none of it is ever written down.
///
/// What is held is thrown away, and not merely hidden, when the market changes,
/// when the session ends or is refused, when the viewer's scope or the parts of the
/// API the grant includes change, and when
/// the app has been in the background for longer than [backgroundGrace]. An
/// answer that was still on its way when that happened is dropped when it
/// arrives: [_marketEpoch] and [_sessionEpoch] say which answers still belong.
///
/// The second step of the sign-in is held here too. The challenge the API gives for it, and the code
/// an admin types, are secrets that are good for nothing else: they are kept in memory only, are never
/// handed to a screen, and are gone the moment the step ends, however it ends.
class PlatformAdminController with ChangeNotifier {
  /// With this many recovery codes left or fewer, the admin is told to ask for new ones.
  static const int recoveryCodesWarnedAt = 2;

  final PlatformAdminServiceInterface platformAdminServiceInterface;
  final Duration backgroundGrace;
  final DateTime Function() _now;

  PlatformAdminController({
    required this.platformAdminServiceInterface,
    this.backgroundGrace = const Duration(minutes: 5),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  bool _disposed = false;

  /// Bumped when the markets a viewer looks at change: answers of an earlier one are stale.
  int _marketEpoch = 0;

  /// Bumped when everything held is thrown away: answers of an earlier one are stale.
  int _sessionEpoch = 0;

  PlatformAdminStage _stage = PlatformAdminStage.restoring;
  PlatformAdminStage get stage => _stage;

  PlatformAdminProfile? _profile;
  PlatformAdminProfile? get profile => _profile;
  bool get isRestricted => _profile?.isRestricted ?? true;

  /// Whether the grant includes this part of the API, as the server last said. Nothing is included for nobody.
  bool can(PlatformCapability capability) => _profile?.can(capability) ?? false;

  /// Counts the times what the viewer may see or do changed, so that a screen can tell that what it holds was thrown away.
  int _accessEpoch = 0;
  int get accessEpoch => _accessEpoch;
  bool _refreshingProfile = false;

  PlatformAdminFailure? _signInFailure;
  PlatformAdminFailure? get signInFailure => _signInFailure;

  PlatformAdminFailure? _restoreFailure;
  PlatformAdminFailure? get restoreFailure => _restoreFailure;

  /// A session that was open has been ended by the server, or has run out.
  bool _sessionEnded = false;
  bool get sessionEnded => _sessionEnded;

  PlatformAdminMfaChallenge? _challenge;
  int _triesLeft = PlatformAdminMfaChallenge.maxTries;
  bool _verifyingSecondFactor = false;
  PlatformAdminFailure? _secondFactorFailure;
  DateTime? _secondFactorWaitEndsAt;
  PlatformAdminSecondFactorEnd? _secondFactorEnd;

  /// The ways the API takes a code for the second step that is open. None when none is.
  Set<PlatformAdminMfaMethod> get secondFactorMethods => _challenge?.methods ?? const <PlatformAdminMfaMethod>{};

  /// How many wrong codes the second step still takes, counted here from the refusals the API gave.
  int get secondFactorTriesLeft => _triesLeft;
  bool get isVerifyingSecondFactor => _verifyingSecondFactor;

  /// Why the last code did not open a session. A refusal says nothing of why, so nor does this.
  PlatformAdminFailure? get secondFactorFailure => _secondFactorFailure;

  /// Why the second step was left without a session, until the next sign-in starts.
  PlatformAdminSecondFactorEnd? get secondFactorEnd => _secondFactorEnd;

  /// How long the API asked the second step to wait. Null when it did not, or when the wait is over.
  Duration? get secondFactorWait {
    final DateTime? end = _secondFactorWaitEndsAt;
    if (end == null) return null;

    final Duration left = end.difference(_now());
    return left > Duration.zero ? left : null;
  }

  /// How long until the second step has to look again by itself: the wait ends, or the challenge does.
  Duration? get secondFactorNextCheck {
    final DateTime? challengeEnd = _challenge?.expiresAt;
    final Duration? untilChallengeEnds = challengeEnd?.difference(_now());
    final Duration? wait = secondFactorWait;

    final List<Duration> pending = <Duration>[
      if (wait != null) wait,
      if (untilChallengeEnds != null && untilChallengeEnds > Duration.zero) untilChallengeEnds,
    ];
    return pending.isEmpty ? null : pending.reduce((Duration left, Duration right) => left < right ? left : right);
  }

  int? _recoveryCodesLeft;
  bool _recoveryWarningDismissed = false;

  /// How many recovery codes are left, once that is few enough to say so and the admin has not put the warning away.
  int? get recoveryCodesWarning {
    final int? left = _recoveryCodesLeft;
    return left != null && left <= recoveryCodesWarnedAt && !_recoveryWarningDismissed ? left : null;
  }

  String _market = PlatformMarketCode.all;
  String get market => _market;

  /// How many days the overview counts, or null for the window the server chooses.
  int? _windowDays;
  int? get windowDays => _windowDays;

  PlatformMarketDirectory? _directory;

  /// The server refused the directory of markets for a part the grant leaves out, which the list the app holds did not say.
  bool _directoryRefused = false;
  List<PlatformMarketModel> get markets => _directory?.markets ?? const <PlatformMarketModel>[];
  PlatformMarketModel? marketInfo(String code) => _directory?.marketOf(code);

  /// There is no directory to wait for: the grant does not include it, or the server has just refused it.
  bool get _directoryUnavailable => !can(PlatformCapability.markets) || _directoryRefused;

  /// The markets the viewer can choose between: those the directory lists, or, where the grant does not include
  /// the directory, those the grant names.
  List<String> get marketCodes {
    final PlatformMarketDirectory? directory = _directory;
    if (directory != null) return directory.codes;

    return _directoryUnavailable ? _profile?.markets ?? const <String>[] : const <String>[];
  }

  final Map<_OverviewKey, PlatformOverviewModel> _overviews = <_OverviewKey, PlatformOverviewModel>{};
  _OverviewKey? _loadingOverview;
  PlatformAdminFailure? _overviewFailure;

  _OverviewKey get _overviewKey => (market: _market, windowDays: _windowDays);
  PlatformOverviewModel? get overview => _overviews[_overviewKey];
  bool get isLoadingOverview => _loadingOverview == _overviewKey;
  PlatformAdminFailure? get overviewFailure => _overviewFailure;

  /// Whether the overview can be drawn: the market the viewer asked about and the
  /// facts about every market are both here, or the facts are not to be had.
  bool get hasOverview => overview != null && (_directory != null || _directoryUnavailable);

  final Map<_HealthKey, PlatformHealthModel> _health = <_HealthKey, PlatformHealthModel>{};

  _HealthKey? _loadingHealth;

  PlatformAdminFailure? _healthFailure;

  _HealthKey get _healthKey => (market: _market, windowDays: _windowDays);
  PlatformHealthModel? get health => _health[_healthKey];
  bool get isLoadingHealth => _loadingHealth == _healthKey;
  PlatformAdminFailure? get healthFailure => _healthFailure;
  bool get hasHealth => health != null;

  final Map<_AlertsKey, _AlertList> _alerts = <_AlertsKey, _AlertList>{};
  String? _alertSeverity;
  _AlertsKey? _loadingAlerts;
  bool _loadingMoreAlerts = false;
  PlatformAdminFailure? _alertsFailure;

  _AlertsKey get _alertsKey => (market: _market, severity: _alertSeverity);
  String? get alertSeverity => _alertSeverity;
  List<PlatformAlertModel> get alerts => _alerts[_alertsKey]?.items ?? const <PlatformAlertModel>[];
  bool get hasAlertList => _alerts.containsKey(_alertsKey);
  int get alertsTotal => _alerts[_alertsKey]?.total ?? 0;
  bool get alertsHaveMore => _alerts[_alertsKey]?.hasMore ?? false;
  bool get isLoadingAlerts => _loadingAlerts == _alertsKey;
  bool get isLoadingMoreAlerts => _loadingMoreAlerts;
  PlatformAdminFailure? get alertsFailure => _alertsFailure;

  List<PlatformSessionModel>? _sessions;
  bool _loadingSessions = false;
  int? _endingSessionId;
  bool _endingOtherSessions = false;
  PlatformAdminFailure? _sessionsFailure;

  List<PlatformSessionModel>? get sessions => _sessions;
  bool get isLoadingSessions => _loadingSessions;
  int? get endingSessionId => _endingSessionId;
  bool get isEndingOtherSessions => _endingOtherSessions;
  PlatformAdminFailure? get sessionsFailure => _sessionsFailure;

  List<PlatformAuditLine>? _auditLines;
  int _auditPage = 0;
  bool _auditHasMore = false;
  bool _loadingAudit = false;
  bool _loadingMoreAudit = false;
  PlatformAdminFailure? _auditFailure;

  List<PlatformAuditLine>? get auditLines => _auditLines;
  bool get auditHasMore => _auditHasMore;
  bool get isLoadingAudit => _loadingAudit;
  bool get isLoadingMoreAudit => _loadingMoreAudit;
  PlatformAdminFailure? get auditFailure => _auditFailure;

  DateTime? _backgroundedAt;

  Future<void> restoreSession() async {
    _stage = PlatformAdminStage.restoring;
    _restoreFailure = null;
    notifyListeners();

    final PlatformAdminResult<PlatformAdminProfile?> result = await platformAdminServiceInterface.restore();
    final PlatformAdminFailure? failure = result.failure;
    final PlatformAdminProfile? restored = result.value;

    if (failure == null && restored != null) {
      _applyProfile(restored);
      _stage = PlatformAdminStage.signedIn;
    } else if (failure == null) {
      _stage = PlatformAdminStage.signedOut;
    } else if (failure.kind == PlatformAdminFailureKind.unauthenticated) {
      _sessionEnded = true;
      _stage = PlatformAdminStage.signedOut;
    } else {
      _restoreFailure = failure;
      _stage = PlatformAdminStage.restoreFailed;
    }
    notifyListeners();
  }

  /// True when the admin is signed in. On failure [signInFailure] says why. A good password that is not
  /// enough on its own is neither: the stage is then [PlatformAdminStage.secondFactor].
  Future<bool> signIn({required String email, required String password, required String deviceName}) async {
    if (_stage == PlatformAdminStage.signingIn) return false;

    _stage = PlatformAdminStage.signingIn;
    _signInFailure = null;
    _sessionEnded = false;
    _secondFactorEnd = null;
    notifyListeners();

    final PlatformAdminResult<PlatformAdminSignInStep> result = await platformAdminServiceInterface.signIn(
      email: email,
      password: password,
      deviceName: deviceName,
    );

    switch (result.value) {
      case PlatformAdminSessionOpened(:final PlatformAdminSignIn signIn):
        return _enter(signIn);
      case PlatformAdminSecondFactorWanted(:final PlatformAdminMfaChallenge challenge):
        _resetSecondFactor();
        _challenge = challenge.isOver(_now()) ? challenge.withoutEnd() : challenge;
        _stage = PlatformAdminStage.secondFactor;
        notifyListeners();
        return false;
      case null:
        _signInFailure = result.failure;
        _stage = PlatformAdminStage.signedOut;
        notifyListeners();
        return false;
    }
  }

  /// True when the code opened a session. Otherwise [secondFactorFailure] says that it did not, or the second step is
  /// over and [secondFactorEnd] says why: its challenge ran out, or every try it allows was used.
  ///
  /// A code the API refuses uses one try of the challenge, which the API counts too; five of them and the admin
  /// starts again from the password. A call that never got an answer, and one the API throttled, use none.
  Future<bool> verifySecondFactor({required PlatformAdminMfaMethod method, required String code}) async {
    final PlatformAdminMfaChallenge? challenge = _challenge;
    if (_stage != PlatformAdminStage.secondFactor || challenge == null || _verifyingSecondFactor) return false;
    if (secondFactorWait != null) return false;

    if (challenge.isOver(_now())) {
      _endSecondFactor(PlatformAdminSecondFactorEnd.expired);
      return false;
    }

    _verifyingSecondFactor = true;
    _secondFactorFailure = null;
    notifyListeners();

    final PlatformAdminResult<PlatformAdminSignIn> result = await platformAdminServiceInterface.signInWithSecondFactor(
      challenge: challenge.value,
      method: method,
      code: code,
    );
    if (_disposed) return false;

    final PlatformAdminSignIn? signIn = result.value;
    if (signIn != null) return _enter(signIn);

    final PlatformAdminFailure failure = result.failure!;
    _verifyingSecondFactor = false;

    if (failure.kind == PlatformAdminFailureKind.unauthenticated) {
      _triesLeft--;
      if (_triesLeft <= 0) {
        _endSecondFactor(PlatformAdminSecondFactorEnd.triesUsed);
        return false;
      }
    }

    _secondFactorFailure = failure;
    _secondFactorWaitEndsAt = failure.kind == PlatformAdminFailureKind.throttled ? failure.retryAt : null;
    notifyListeners();
    return false;
  }

  /// Back to the password, from the second step. A new password step asks for a new challenge. It is not
  /// possible while a code is on its way: the answer would open a session nobody is looking at.
  void cancelSecondFactor() {
    if (_stage != PlatformAdminStage.secondFactor || _verifyingSecondFactor) return;

    _resetSecondFactor();
    _stage = PlatformAdminStage.signedOut;
    notifyListeners();
  }

  /// Ends the second step if its challenge has run out, which the API would only say no to.
  void expireSecondFactorIfOver() {
    final PlatformAdminMfaChallenge? challenge = _challenge;
    if (_stage != PlatformAdminStage.secondFactor || _verifyingSecondFactor || challenge == null) return;

    if (challenge.isOver(_now())) _endSecondFactor(PlatformAdminSecondFactorEnd.expired);
  }

  void dismissRecoveryWarning() {
    if (_recoveryWarningDismissed) return;

    _recoveryWarningDismissed = true;
    notifyListeners();
  }

  /// Over on this phone at once, whatever the server says; the server is told afterwards.
  Future<void> signOut() async {
    _forgetEverything();
    _sessionEnded = false;
    _stage = PlatformAdminStage.signedOut;
    notifyListeners();

    await platformAdminServiceInterface.signOut();
  }

  /// Only a market the server listed for this viewer can be chosen, and the one
  /// that was chosen before is forgotten, so that nothing of it can be shown under the new one.
  void selectMarket(String market) {
    final String next =
        market.toLowerCase() == PlatformMarketCode.all ? PlatformMarketCode.all : PlatformMarketCode.normalize(market);
    if (next == _market || !(_profile?.canSee(next) ?? false)) return;

    _market = next;
    _forgetMarketData();
    notifyListeners();
  }

  void selectWindow(int? days) {
    if (days == _windowDays) return;

    _windowDays = days;
    _overviewFailure = null;
    _healthFailure = null;
    notifyListeners();
  }

  void selectAlertSeverity(String? severity) {
    if (severity == _alertSeverity) return;

    _alertSeverity = severity;
    _alertsFailure = null;
    notifyListeners();
  }

  /// Whether a market can be opened: the server lists it for this viewer.
  bool canOpenMarket(String market) => _profile?.canSee(PlatformMarketCode.normalize(market)) ?? false;

  /// Whether an alert can be opened: it links to a market this viewer may see.
  bool canOpen(PlatformAlertModel alert) {
    final PlatformDeepLink? link = alert.link;
    return link != null && canOpenMarket(link.market);
  }

  /// Reads the health of the market in view, and keeps it per market and window
  /// so that moving between markets does not show one market's figures under
  /// another's name while the next answer is on its way.
  Future<void> loadHealth({bool force = false}) async {
    if (_stage != PlatformAdminStage.signedIn) return;

    final _HealthKey key = _healthKey;
    if (_loadingHealth == key || (!force && _health.containsKey(key))) return;

    final int session = _sessionEpoch;
    final int market = _marketEpoch;
    _loadingHealth = key;
    _healthFailure = null;
    notifyListeners();

    final PlatformAdminResult<PlatformHealthModel> result = await platformAdminServiceInterface.health(
      market: key.market,
      windowDays: key.windowDays,
    );

    if (session != _sessionEpoch || market != _marketEpoch) return;

    if (_loadingHealth == key) _loadingHealth = null;

    if (result.failure?.kind == PlatformAdminFailureKind.unauthenticated) {
      _endSession();
      return;
    }

    if (result.value != null) _health[key] = result.value!;
    _healthFailure = result.failure;
    notifyListeners();
  }

  Future<void> loadOverview({bool force = false}) async {
    if (_stage != PlatformAdminStage.signedIn) return;

    final _OverviewKey key = _overviewKey;
    if (_loadingOverview == key || (!force && hasOverview)) return;

    final int session = _sessionEpoch;
    final int market = _marketEpoch;
    _loadingOverview = key;
    _overviewFailure = null;
    notifyListeners();

    if (force) _directoryRefused = false;
    final bool needsDirectory = !_directoryUnavailable && (force || _directory == null);
    final Future<PlatformAdminResult<PlatformMarketDirectory>>? directoryCall =
        needsDirectory ? platformAdminServiceInterface.markets() : null;
    final PlatformAdminResult<PlatformOverviewModel> overviewResult = await platformAdminServiceInterface.overview(
      market: key.market,
      windowDays: key.windowDays,
    );
    final PlatformAdminResult<PlatformMarketDirectory>? directoryResult = await directoryCall;

    if (session != _sessionEpoch || market != _marketEpoch) return;

    if (_loadingOverview == key) _loadingOverview = null;
    final PlatformAdminFailure? directoryFailure = directoryResult?.failure;
    final bool directoryRefused = directoryFailure?.kind == PlatformAdminFailureKind.capabilityNotAllowed;
    final PlatformAdminFailure? failure = overviewResult.failure ?? (directoryRefused ? null : directoryFailure);

    if (failure?.kind == PlatformAdminFailureKind.unauthenticated) {
      _endSession();
      return;
    }
    if (overviewResult.value != null) _overviews[key] = overviewResult.value!;
    if (directoryResult?.value != null) _directory = directoryResult!.value;
    if (directoryRefused) _directoryRefused = true;
    _overviewFailure = failure;
    notifyListeners();

    await _readAgainIfRefused(<PlatformAdminFailure?>[overviewResult.failure, directoryFailure]);
  }

  Future<void> loadAlerts({bool force = false}) async {
    if (_stage != PlatformAdminStage.signedIn) return;

    final _AlertsKey key = _alertsKey;
    if (_loadingAlerts == key || (!force && _alerts.containsKey(key))) return;

    final int session = _sessionEpoch;
    final int market = _marketEpoch;
    _loadingAlerts = key;
    _alertsFailure = null;
    notifyListeners();

    // The market chips of this screen are the overview's, so the markets are asked for here when the overview has not.
    final Future<PlatformAdminResult<PlatformMarketDirectory>>? directoryCall =
        _directory == null && !_directoryUnavailable ? platformAdminServiceInterface.markets() : null;
    final PlatformAdminResult<PlatformAlertPage> result = await platformAdminServiceInterface.alerts(
      market: key.market,
      page: 1,
      severity: key.severity,
    );
    final PlatformAdminResult<PlatformMarketDirectory>? directoryResult = await directoryCall;

    if (session != _sessionEpoch || market != _marketEpoch) return;

    if (_loadingAlerts == key) _loadingAlerts = null;
    if (_endedBy(result.failure) || _endedBy(directoryResult?.failure)) return;

    if (directoryResult?.value != null) _directory = directoryResult!.value;
    if (directoryResult?.failure?.kind == PlatformAdminFailureKind.capabilityNotAllowed) _directoryRefused = true;
    final PlatformAlertPage? page = result.value;
    if (page != null) {
      _alerts[key] = _AlertList(items: page.alerts, lastPage: page.page, total: page.total, hasMore: page.hasMore);
    }
    _alertsFailure = result.failure;
    notifyListeners();

    await _readAgainIfRefused(<PlatformAdminFailure?>[result.failure, directoryResult?.failure]);
  }

  Future<void> loadMoreAlerts() async {
    final _AlertsKey key = _alertsKey;
    final _AlertList? list = _alerts[key];
    if (list == null || !list.hasMore || _loadingMoreAlerts) return;

    final int session = _sessionEpoch;
    final int market = _marketEpoch;
    _loadingMoreAlerts = true;
    notifyListeners();

    final PlatformAdminResult<PlatformAlertPage> result = await platformAdminServiceInterface.alerts(
      market: key.market,
      page: list.lastPage + 1,
      severity: key.severity,
    );

    if (session != _sessionEpoch || market != _marketEpoch) return;

    _loadingMoreAlerts = false;
    if (_endedBy(result.failure)) return;

    // A list that was read again while this page was on its way is not the list this page continues.
    final PlatformAlertPage? page = result.value;
    if (page != null && identical(_alerts[key], list)) {
      _alerts[key] = _AlertList(
        items: <PlatformAlertModel>[...list.items, ...page.alerts],
        lastPage: page.page,
        total: page.total,
        hasMore: page.hasMore,
      );
    }
    _alertsFailure = result.failure;
    notifyListeners();

    await _readAgainIfRefused(<PlatformAdminFailure?>[result.failure]);
  }

  Future<void> loadSessions({bool force = false}) async {
    if (_stage != PlatformAdminStage.signedIn || _loadingSessions || (!force && _sessions != null)) return;

    final int session = _sessionEpoch;
    _loadingSessions = true;
    _sessionsFailure = null;
    notifyListeners();

    final PlatformAdminResult<List<PlatformSessionModel>> result = await platformAdminServiceInterface.sessions();

    if (session != _sessionEpoch) return;

    _loadingSessions = false;
    if (_endedBy(result.failure)) return;

    _sessions = result.value ?? _sessions;
    _sessionsFailure = result.failure;
    notifyListeners();

    await _readAgainIfRefused(<PlatformAdminFailure?>[result.failure]);
  }

  /// Null when the session was ended; otherwise why it was not. A session that was
  /// already over is gone from the list as well, so it is read again either way.
  Future<PlatformAdminFailure?> endSession(int id) async {
    if (_stage != PlatformAdminStage.signedIn || _endingSessionId != null || _endingOtherSessions) return null;

    final int session = _sessionEpoch;
    _endingSessionId = id;
    notifyListeners();

    final PlatformAdminResult<int> result = await platformAdminServiceInterface.endSession(id);

    if (session != _sessionEpoch) return result.failure;

    _endingSessionId = null;
    if (_endedBy(result.failure)) return result.failure;

    final PlatformAdminFailure? failure = result.failure;
    final bool gone = failure == null || failure.kind == PlatformAdminFailureKind.sessionNotFound;
    notifyListeners();

    if (gone) await loadSessions(force: true);
    await _readAgainIfRefused(<PlatformAdminFailure?>[failure]);
    return failure;
  }

  /// How many sessions were ended, or why none was. Null when nothing was asked: no one is signed in, or another session is being ended.
  /// The list is read again, because what was ended is no longer in it.
  Future<PlatformAdminResult<int>?> endOtherSessions() async {
    if (_stage != PlatformAdminStage.signedIn || _endingSessionId != null || _endingOtherSessions) return null;

    final int session = _sessionEpoch;
    _endingOtherSessions = true;
    notifyListeners();

    final PlatformAdminResult<int> result = await platformAdminServiceInterface.endOtherSessions();

    if (session != _sessionEpoch) return result;

    _endingOtherSessions = false;
    if (_endedBy(result.failure)) return result;

    notifyListeners();
    if (result.isSuccess) await loadSessions(force: true);
    await _readAgainIfRefused(<PlatformAdminFailure?>[result.failure]);
    return result;
  }

  Future<void> loadAuditLog({bool force = false}) async {
    if (_stage != PlatformAdminStage.signedIn || _loadingAudit || (!force && _auditLines != null)) return;

    final int session = _sessionEpoch;
    _loadingAudit = true;
    _auditFailure = null;
    notifyListeners();

    final PlatformAdminResult<PlatformAuditPage> result = await platformAdminServiceInterface.auditLogs(page: 1);

    if (session != _sessionEpoch) return;

    _loadingAudit = false;
    if (_endedBy(result.failure)) return;

    final PlatformAuditPage? page = result.value;
    if (page != null) {
      _auditLines = page.lines;
      _auditPage = page.page;
      _auditHasMore = page.hasMore;
    }
    _auditFailure = result.failure;
    notifyListeners();

    await _readAgainIfRefused(<PlatformAdminFailure?>[result.failure]);
  }

  Future<void> loadMoreAuditLog() async {
    final List<PlatformAuditLine>? lines = _auditLines;
    if (lines == null || !_auditHasMore || _loadingMoreAudit) return;

    final int session = _sessionEpoch;
    _loadingMoreAudit = true;
    notifyListeners();

    final PlatformAdminResult<PlatformAuditPage> result =
        await platformAdminServiceInterface.auditLogs(page: _auditPage + 1);

    if (session != _sessionEpoch) return;

    _loadingMoreAudit = false;
    if (_endedBy(result.failure)) return;

    final PlatformAuditPage? page = result.value;
    if (page != null && identical(_auditLines, lines)) {
      _auditLines = <PlatformAuditLine>[...lines, ...page.lines];
      _auditPage = page.page;
      _auditHasMore = page.hasMore;
    }
    _auditFailure = result.failure;
    notifyListeners();

    await _readAgainIfRefused(<PlatformAdminFailure?>[result.failure]);
  }

  /// Reads who the admin is and what they may do again, which the app does when the server says that a part it offered is not included
  /// in the grant: the list it holds is out of date. What was held for what is no longer included is thrown away with the rest.
  Future<void> refreshProfile() async {
    if (_stage != PlatformAdminStage.signedIn || _refreshingProfile) return;

    final int session = _sessionEpoch;
    _refreshingProfile = true;
    final PlatformAdminResult<PlatformAdminProfile> result = await platformAdminServiceInterface.profile();

    if (session != _sessionEpoch) return;

    _refreshingProfile = false;
    if (_endedBy(result.failure)) return;

    final PlatformAdminProfile? current = result.value;
    if (current != null) _applyProfile(current);
    notifyListeners();
  }

  void onAppBackgrounded() {
    if (_stage == PlatformAdminStage.signedIn) _backgroundedAt ??= _now();
  }

  /// True when the app was away long enough that what it held has been thrown
  /// away, and the screen in front has to ask again.
  Future<bool> onAppResumed() async {
    final DateTime? since = _backgroundedAt;
    _backgroundedAt = null;

    final bool awayLongEnough = since != null && _now().difference(since) >= backgroundGrace;
    if (_stage != PlatformAdminStage.signedIn || !awayLongEnough) return false;

    final int session = _sessionEpoch;
    _forgetResponses();
    notifyListeners();

    final PlatformAdminResult<PlatformAdminProfile> result = await platformAdminServiceInterface.profile();

    if (session + 1 != _sessionEpoch) return false;
    if (_endedBy(result.failure)) return false;

    final PlatformAdminProfile? current = result.value;
    if (current != null) _applyProfile(current);
    notifyListeners();
    return true;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _forgetEverything();
    super.dispose();
  }

  /// A session is open. The answer that opened it says who signed in and nothing of what they may do: that is read
  /// from the API now, before anything is shown, so that the shell offers only what the grant includes.
  Future<bool> _enter(PlatformAdminSignIn signIn) async {
    final PlatformAdminResult<PlatformAdminProfile> result = await platformAdminServiceInterface.profile();
    if (_disposed) return false;
    if (_endedBy(result.failure)) return false;

    _forgetEverything();
    final PlatformAdminProfile? profile = result.value;

    if (profile == null) {
      // The session is open and could not be checked: the shell asks again, from the session it has kept.
      _restoreFailure = result.failure;
      _stage = PlatformAdminStage.restoreFailed;
      notifyListeners();
      return false;
    }

    _applyProfile(profile);
    _recoveryCodesLeft = signIn.recoveryCodesLeft;
    _stage = PlatformAdminStage.signedIn;
    notifyListeners();
    return true;
  }

  void _endSecondFactor(PlatformAdminSecondFactorEnd end) {
    _resetSecondFactor();
    _secondFactorEnd = end;
    _stage = PlatformAdminStage.signedOut;
    notifyListeners();
  }

  /// Everything of the second step, the challenge first: nothing of it outlives the step.
  void _resetSecondFactor() {
    _challenge = null;
    _triesLeft = PlatformAdminMfaChallenge.maxTries;
    _verifyingSecondFactor = false;
    _secondFactorFailure = null;
    _secondFactorWaitEndsAt = null;
  }

  /// Ends the session of this app after the server has refused it, and says so. The
  /// token was dropped by the repository that met the refusal.
  bool _endedBy(PlatformAdminFailure? failure) {
    if (failure?.kind != PlatformAdminFailureKind.unauthenticated) return false;

    _endSession();
    return true;
  }

  void _endSession() {
    _forgetEverything();
    _sessionEnded = true;
    _stage = PlatformAdminStage.signedOut;
    notifyListeners();
  }

  /// A refusal for a part of the API the grant leaves out, once, however many calls met it together.
  Future<void> _readAgainIfRefused(Iterable<PlatformAdminFailure?> failures) async {
    final bool refused =
        failures.any((PlatformAdminFailure? failure) => failure?.kind == PlatformAdminFailureKind.capabilityNotAllowed);
    if (refused) await refreshProfile();
  }

  void _applyProfile(PlatformAdminProfile profile) {
    final PlatformAdminProfile? previous = _profile;
    _profile = profile;

    final bool accessChanged = previous != null &&
        (previous.scope != profile.scope ||
            !listEquals(previous.markets, profile.markets) ||
            !setEquals(previous.capabilities, profile.capabilities));
    if (!accessChanged) return;

    _accessEpoch++;
    _forgetResponses();
    if (!profile.canSee(_market)) _market = PlatformMarketCode.all;
  }

  /// What was counted for the market the viewer was looking at.
  void _forgetMarketData() {
    _marketEpoch++;
    _overviews.clear();
    _health.clear();
    _loadingOverview = null;
    _loadingHealth = null;
    _overviewFailure = null;
    _healthFailure = null;
    _alerts.clear();
    _loadingAlerts = null;
    _loadingMoreAlerts = false;
    _alertsFailure = null;
  }

  /// Every answer the server has given, and everything about asking for them again.
  void _forgetResponses() {
    _sessionEpoch++;
    _forgetMarketData();
    _directory = null;
    _directoryRefused = false;
    _refreshingProfile = false;
    _sessions = null;
    _loadingSessions = false;
    _endingSessionId = null;
    _endingOtherSessions = false;
    _sessionsFailure = null;
    _auditLines = null;
    _auditPage = 0;
    _auditHasMore = false;
    _loadingAudit = false;
    _loadingMoreAudit = false;
    _auditFailure = null;
  }

  /// Every answer, and who it was for, and what the viewer had chosen.
  void _forgetEverything() {
    _forgetResponses();
    _profile = null;
    _market = PlatformMarketCode.all;
    _windowDays = null;
    _alertSeverity = null;
    _backgroundedAt = null;
    _signInFailure = null;
    _restoreFailure = null;
    _resetSecondFactor();
    _secondFactorEnd = null;
    _recoveryCodesLeft = null;
    _recoveryWarningDismissed = false;
  }
}
