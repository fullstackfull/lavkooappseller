import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_json.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_market_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_overview_models.dart';

/// Whether a market's machinery is working: the payment attempts that never came
/// back, and the integrations that have stopped syncing (L-09).
///
/// Counts and timestamps, and nothing else. The server sends no amount, no
/// customer, no gateway reference and no credential, so there is nothing here to
/// render that could not be read over somebody's shoulder.
///
/// Every figure arrives with a sentence from the server saying what it MEANS
/// (`means`), because a stuck payment attempt is not a failed one -- a shopper
/// who closed the tab leaves exactly the same row -- and because a channel
/// resource and a carrier capability are called "failing" by different tests.
/// The app shows that sentence rather than writing its own, so a change of
/// definition on the server cannot leave a stale explanation on the screen.
class PlatformPaymentHealth {
  /// Attempts started, never confirmed, and older than the server's grace period.
  final int stuckAttempts;

  /// Cost reconciliations nobody has settled. A BACKLOG and not a window: one
  /// from last month is still money the platform cannot account for, so this
  /// figure does not fall when the window moves.
  final int reconciliationBreaks;

  const PlatformPaymentHealth({this.stuckAttempts = 0, this.reconciliationBreaks = 0});

  factory PlatformPaymentHealth.fromJson(Map<String, dynamic> json) => PlatformPaymentHealth(
        stuckAttempts: PlatformJson.count(json['stuck_attempts']),
        reconciliationBreaks: PlatformJson.count(json['reconciliation_breaks']),
      );

  bool get hasTrouble => stuckAttempts > 0 || reconciliationBreaks > 0;
}

/// A market's open issues: the shops that are out of policy, and the approvals
/// nobody has decided (L-09).
///
/// Both are BACKLOGS and not windows, which is what the server's sentence under
/// each one says: neither stops being true because time passed, so neither falls
/// when the window moves.
///
/// Staff issues and escalations are deliberately NOT here. The server keeps no
/// record of either, so it sends neither -- a zero would read as "none open",
/// which is a different and untrue statement -- and this class has no field for
/// a figure the server does not send.
class PlatformIssueHealth {
  /// Shop service-level breaches nobody has cleared.
  final int openShopIssues;

  /// Approval requests nobody has decided.
  final int pendingApprovals;

  const PlatformIssueHealth({this.openShopIssues = 0, this.pendingApprovals = 0});

  factory PlatformIssueHealth.fromJson(Map<String, dynamic> json) => PlatformIssueHealth(
        openShopIssues: PlatformJson.count(json['open_shop_issues']),
        pendingApprovals: PlatformJson.count(json['pending_approvals']),
      );

  bool get hasTrouble => openShopIssues > 0 || pendingApprovals > 0;
}

/// A market's sales-channel accounts and how their syncs are doing.
class PlatformChannelHealth {
  final int accounts;
  final int failingResources;
  final int lateResources;
  final DateTime? lastSuccessAt;

  const PlatformChannelHealth({
    this.accounts = 0,
    this.failingResources = 0,
    this.lateResources = 0,
    this.lastSuccessAt,
  });

  factory PlatformChannelHealth.fromJson(Map<String, dynamic> json) => PlatformChannelHealth(
        accounts: PlatformJson.count(json['accounts']),
        failingResources: PlatformJson.count(json['failing_resources']),
        lateResources: PlatformJson.count(json['late_resources']),
        lastSuccessAt: PlatformJson.moment(json['last_success_at']),
      );

  bool get hasTrouble => failingResources > 0 || lateResources > 0;
}

/// A market's carrier connections and how their syncs are doing.
///
/// Kept apart from the channels on purpose: the two are counted from different
/// tables by different tests, so adding them together would produce a number
/// that means nothing.
class PlatformCarrierHealth {
  final int connections;
  final int failingCapabilities;
  final int lateCapabilities;
  final DateTime? lastSuccessAt;

  const PlatformCarrierHealth({
    this.connections = 0,
    this.failingCapabilities = 0,
    this.lateCapabilities = 0,
    this.lastSuccessAt,
  });

  factory PlatformCarrierHealth.fromJson(Map<String, dynamic> json) => PlatformCarrierHealth(
        connections: PlatformJson.count(json['connections']),
        failingCapabilities: PlatformJson.count(json['failing_capabilities']),
        lateCapabilities: PlatformJson.count(json['late_capabilities']),
        lastSuccessAt: PlatformJson.moment(json['last_success_at']),
      );

  bool get hasTrouble => failingCapabilities > 0 || lateCapabilities > 0;
}

/// A market's accounting queue: what is waiting, what has stopped, what is
/// overdue, and when an entry last reached the books (L-09).
///
/// Three figures and three different questions, never added together. `queued`
/// is work the queue can still do by itself and is NOT a fault; `needsAPerson`
/// is what it has stopped on and is the figure to act on; `overdue` is queued
/// work whose turn has passed, which is how a stopped worker looks from here.
class PlatformBooksHealth {
  /// Entries the queue can still post by itself. Not a fault.
  final int queuedPostings;

  /// Entries the queue has stopped trying on: a decision is owed, or it gave up.
  final int postingsNeedingAPerson;

  /// Queued entries whose turn has passed and that nothing has worked.
  final int overduePostings;

  /// The latest entry that reached the books, whenever it was.
  final DateTime? lastPostedAt;

  const PlatformBooksHealth({
    this.queuedPostings = 0,
    this.postingsNeedingAPerson = 0,
    this.overduePostings = 0,
    this.lastPostedAt,
  });

  factory PlatformBooksHealth.fromJson(Map<String, dynamic> json) => PlatformBooksHealth(
        queuedPostings: PlatformJson.count(json['queued_postings']),
        postingsNeedingAPerson: PlatformJson.count(json['postings_needing_a_person']),
        overduePostings: PlatformJson.count(json['overdue_postings']),
        lastPostedAt: PlatformJson.moment(json['last_posted_at']),
      );

  /// A queued entry is not trouble. Only what has stopped, or is overdue, is.
  bool get hasTrouble => postingsNeedingAPerson > 0 || overduePostings > 0;
}

/// One market's health, or the rows whose market the platform does not record.
class PlatformMarketHealth {
  /// Null for the unattributed row.
  final String? market;
  final String? legalEntity;
  final PlatformPaymentHealth payments;
  final PlatformChannelHealth channels;
  final PlatformCarrierHealth carriers;
  final PlatformBooksHealth books;
  final PlatformIssueHealth issues;

  /// Why these rows are apart, which the server sends only for the unattributed row.
  final String? reason;

  const PlatformMarketHealth({
    required this.payments,
    required this.channels,
    required this.carriers,
    this.books = const PlatformBooksHealth(),
    this.issues = const PlatformIssueHealth(),
    this.market,
    this.legalEntity,
    this.reason,
  });

  factory PlatformMarketHealth.fromJson(Map<String, dynamic> json) => PlatformMarketHealth(
        market: PlatformJson.string(json['market']),
        legalEntity: PlatformJson.string(json['legal_entity']),
        payments: PlatformPaymentHealth.fromJson(PlatformJson.map(json['payments'])),
        channels: PlatformChannelHealth.fromJson(PlatformJson.map(PlatformJson.map(json['integrations'])['channels'])),
        carriers: PlatformCarrierHealth.fromJson(PlatformJson.map(PlatformJson.map(json['integrations'])['carriers'])),
        books: PlatformBooksHealth.fromJson(PlatformJson.map(PlatformJson.map(json['integrations'])['books'])),
        issues: PlatformIssueHealth.fromJson(PlatformJson.map(json['issues'])),
        reason: PlatformJson.string(json['reason']),
      );

  bool get isUnattributed => market == null;

  /// Whether anything on this row is worth a person's attention right now.
  ///
  /// Every group is asked, the issues included: a market whose shops are out of
  /// policy and whose payments are fine was drawn as though nothing were on it.
  bool get needsAttention =>
      payments.hasTrouble || channels.hasTrouble || carriers.hasTrouble || books.hasTrouble || issues.hasTrouble;
}

/// The whole answer of `GET /health`.
class PlatformHealthModel {
  final PlatformScope scope;

  /// What was asked: `all` or one market's code.
  final String market;
  final DateTime? generatedAt;
  final PlatformWindowModel? window;
  final PlatformFreshness freshness;
  final List<PlatformMarketHealth> markets;

  /// Only the platform owner asking for all markets gets this.
  final PlatformMarketHealth? unattributed;

  /// What each figure means, in the server's own words, keyed by its path
  /// (`payments.stuck_attempts`). The app never writes these sentences itself.
  final Map<String, String> means;

  const PlatformHealthModel({
    required this.scope,
    required this.market,
    required this.freshness,
    required this.markets,
    this.means = const <String, String>{},
    this.generatedAt,
    this.window,
    this.unattributed,
  });

  factory PlatformHealthModel.fromJson(Map<String, dynamic> json) => PlatformHealthModel(
        scope: PlatformScope.parse(json['scope']),
        market: PlatformJson.string(json['market']) ?? PlatformMarketCode.all,
        generatedAt: PlatformJson.moment(json['generated_at']),
        window: json['window'] is Map ? PlatformWindowModel.fromJson(PlatformJson.map(json['window'])) : null,
        freshness: PlatformFreshness.fromJson(PlatformJson.map(json['freshness'])),
        markets: PlatformJson.maps(json['markets']).map(PlatformMarketHealth.fromJson).toList(),
        unattributed:
            json['unattributed'] is Map ? PlatformMarketHealth.fromJson(PlatformJson.map(json['unattributed'])) : null,
        means: _meansOf(json['means']),
      );

  PlatformMarketHealth? marketOf(String code) {
    for (final PlatformMarketHealth health in markets) {
      if (health.market == code) return health;
    }
    return null;
  }

  /// Every row the screen draws: the markets, then the unattributed one if it came.
  List<PlatformMarketHealth> get rows => <PlatformMarketHealth>[
        ...markets,
        if (unattributed != null) unattributed!,
      ];

  /// The sentence the server sent for this figure, or null when it sent none.
  String? meaningOf(String path) => means[path];

  static Map<String, String> _meansOf(Object? value) {
    final Map<String, String> means = <String, String>{};
    PlatformJson.map(value).forEach((String key, Object? sentence) {
      if (sentence is String && sentence.isNotEmpty) means[key] = sentence;
    });
    return means;
  }
}
