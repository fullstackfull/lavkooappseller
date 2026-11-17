import 'package:flutter/foundation.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_alert_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_audit_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_market_models.dart';
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
  signedIn,
}

typedef _OverviewKey = ({String market, int? windowDays});
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
/// when the session ends or is refused, when the viewer's scope changes, and when
/// the app has been in the background for longer than [backgroundGrace]. An
/// answer that was still on its way when that happened is dropped when it
/// arrives: [_marketEpoch] and [_sessionEpoch] say which answers still belong.
class PlatformAdminController with ChangeNotifier {
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

  PlatformAdminFailure? _signInFailure;
  PlatformAdminFailure? get signInFailure => _signInFailure;

  PlatformAdminFailure? _restoreFailure;
  PlatformAdminFailure? get restoreFailure => _restoreFailure;

  /// A session that was open has been ended by the server, or has run out.
  bool _sessionEnded = false;
  bool get sessionEnded => _sessionEnded;

  String _market = PlatformMarketCode.all;
  String get market => _market;

  /// How many days the overview counts, or null for the window the server chooses.
  int? _windowDays;
  int? get windowDays => _windowDays;

  PlatformMarketDirectory? _directory;
  List<PlatformMarketModel> get markets => _directory?.markets ?? const <PlatformMarketModel>[];
  PlatformMarketModel? marketInfo(String code) => _directory?.marketOf(code);

  final Map<_OverviewKey, PlatformOverviewModel> _overviews = <_OverviewKey, PlatformOverviewModel>{};
  _OverviewKey? _loadingOverview;
  PlatformAdminFailure? _overviewFailure;

  _OverviewKey get _overviewKey => (market: _market, windowDays: _windowDays);
  PlatformOverviewModel? get overview => _overviews[_overviewKey];
  bool get isLoadingOverview => _loadingOverview == _overviewKey;
  PlatformAdminFailure? get overviewFailure => _overviewFailure;

  /// Whether the overview can be drawn: the market the viewer asked about and the
  /// facts about every market are both here.
  bool get hasOverview => overview != null && _directory != null;

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
  PlatformAdminFailure? _sessionsFailure;

  List<PlatformSessionModel>? get sessions => _sessions;
  bool get isLoadingSessions => _loadingSessions;
  int? get endingSessionId => _endingSessionId;
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

  /// True when the admin is signed in. On failure [signInFailure] says why.
  Future<bool> signIn({required String email, required String password, required String deviceName}) async {
    if (_stage == PlatformAdminStage.signingIn) return false;

    _stage = PlatformAdminStage.signingIn;
    _signInFailure = null;
    _sessionEnded = false;
    notifyListeners();

    final PlatformAdminResult<PlatformAdminSignIn> result = await platformAdminServiceInterface.signIn(
      email: email,
      password: password,
      deviceName: deviceName,
    );
    final PlatformAdminSignIn? signIn = result.value;

    if (signIn == null) {
      _signInFailure = result.failure;
      _stage = PlatformAdminStage.signedOut;
      notifyListeners();
      return false;
    }

    _forgetEverything();
    _applyProfile(signIn.profile);
    _stage = PlatformAdminStage.signedIn;
    notifyListeners();
    return true;
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
    notifyListeners();
  }

  void selectAlertSeverity(String? severity) {
    if (severity == _alertSeverity) return;

    _alertSeverity = severity;
    _alertsFailure = null;
    notifyListeners();
  }

  /// Whether an alert can be opened: it links to a market this viewer may see.
  bool canOpen(PlatformAlertModel alert) {
    final PlatformDeepLink? link = alert.link;
    return link != null && (_profile?.canSee(link.market) ?? false);
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

    final bool needsDirectory = force || _directory == null;
    final Future<PlatformAdminResult<PlatformMarketDirectory>>? directoryCall =
        needsDirectory ? platformAdminServiceInterface.markets() : null;
    final PlatformAdminResult<PlatformOverviewModel> overviewResult = await platformAdminServiceInterface.overview(
      market: key.market,
      windowDays: key.windowDays,
    );
    final PlatformAdminResult<PlatformMarketDirectory>? directoryResult = await directoryCall;

    if (session != _sessionEpoch || market != _marketEpoch) return;

    if (_loadingOverview == key) _loadingOverview = null;
    final PlatformAdminFailure? failure = overviewResult.failure ?? directoryResult?.failure;

    if (failure?.kind == PlatformAdminFailureKind.unauthenticated) {
      _endSession();
      return;
    }
    if (overviewResult.value != null) _overviews[key] = overviewResult.value!;
    if (directoryResult?.value != null) _directory = directoryResult!.value;
    _overviewFailure = failure;
    notifyListeners();
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

    final PlatformAdminResult<PlatformAlertPage> result = await platformAdminServiceInterface.alerts(
      market: key.market,
      page: 1,
      severity: key.severity,
    );

    if (session != _sessionEpoch || market != _marketEpoch) return;

    if (_loadingAlerts == key) _loadingAlerts = null;
    if (_endedBy(result.failure)) return;

    final PlatformAlertPage? page = result.value;
    if (page != null) {
      _alerts[key] = _AlertList(items: page.alerts, lastPage: page.page, total: page.total, hasMore: page.hasMore);
    }
    _alertsFailure = result.failure;
    notifyListeners();
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
  }

  /// Null when the session was ended; otherwise why it was not. A session that was
  /// already over is gone from the list as well, so it is read again either way.
  Future<PlatformAdminFailure?> endSession(int id) async {
    if (_stage != PlatformAdminStage.signedIn || _endingSessionId != null) return null;

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
    return failure;
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

  void _applyProfile(PlatformAdminProfile profile) {
    final PlatformAdminProfile? previous = _profile;
    _profile = profile;

    final bool scopeChanged =
        previous != null && (previous.scope != profile.scope || !listEquals(previous.markets, profile.markets));
    if (!scopeChanged) return;

    _forgetResponses();
    if (!profile.canSee(_market)) _market = PlatformMarketCode.all;
  }

  /// What was counted for the market the viewer was looking at.
  void _forgetMarketData() {
    _marketEpoch++;
    _overviews.clear();
    _loadingOverview = null;
    _overviewFailure = null;
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
    _sessions = null;
    _loadingSessions = false;
    _endingSessionId = null;
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
  }
}
