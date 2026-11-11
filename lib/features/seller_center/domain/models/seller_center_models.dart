/// The seller-center overview: verification + performance + finance + SLA,
/// exactly as `GET /api/v3/seller/seller-center/overview` composes it.
class SellerCenterOverviewModel {
  final String? verificationStatus;
  final bool kycRequiredForPayout;
  final ScorecardModel? performance;
  final SellerFinanceModel? finance;
  final int openSlaBreachCount;

  SellerCenterOverviewModel({
    this.verificationStatus,
    this.kycRequiredForPayout = false,
    this.performance,
    this.finance,
    this.openSlaBreachCount = 0,
  });

  factory SellerCenterOverviewModel.fromJson(Map<String, dynamic> json) {
    return SellerCenterOverviewModel(
      verificationStatus: json['verification']?['status'],
      kycRequiredForPayout: json['verification']?['required_for_payout'] == true,
      performance: json['performance'] != null ? ScorecardModel.fromJson(json['performance']) : null,
      finance: json['finance'] != null ? SellerFinanceModel.fromJson(json['finance']) : null,
      openSlaBreachCount: int.tryParse('${json['sla']?['open_breach_count']}') ?? 0,
    );
  }
}

class SellerFinanceModel {
  final double available;
  final double pending;
  final double balance;
  final double withdrawable;
  final String? recentPayoutStatus;
  final String? recentPayoutReference;

  SellerFinanceModel({
    this.available = 0,
    this.pending = 0,
    this.balance = 0,
    this.withdrawable = 0,
    this.recentPayoutStatus,
    this.recentPayoutReference,
  });

  factory SellerFinanceModel.fromJson(Map<String, dynamic> json) {
    return SellerFinanceModel(
      available: _toDouble(json['available']),
      pending: _toDouble(json['pending']),
      balance: _toDouble(json['balance']),
      withdrawable: _toDouble(json['withdrawable']),
      recentPayoutStatus: json['recent_payout_status'],
      recentPayoutReference: json['recent_payout_reference'],
    );
  }
}

/// The performance scorecard with its derived health tier
/// (new / good / watch / at_risk), computed server-side.
class ScorecardModel {
  final int ordersTotal;
  final int delivered;
  final int canceled;
  final int returned;
  final int failed;
  final double fulfillmentRate;
  final double cancellationRate;
  final double returnRate;
  final int itemsTotal;
  final int itemsRefunded;
  final double refundRate;
  final double? avgRating;
  final int reviewCount;
  final int moderationStrikes;
  final String? kycStatus;
  final String tier;

  /// The marketplace's own ceilings, keyed as the server names them.
  ///
  /// The app used to colour these rates against numbers written into the screen
  /// — 5% amber, 15% red — while the marketplace's real limits lived in SLA
  /// policy and were settable. A market that lowered its cancellation ceiling to
  /// 8% had a phone still showing 10% as comfortable, a web panel calling it a
  /// breach, and the platform opening one. Three answers to one question.
  final Map<String, double> thresholds;

  /// Lines this shop is over right now, derived from these very metrics.
  final List<SlaBreachModel> overTheLine;

  /// Breaches the platform has recorded and not yet cleared.
  final List<SlaBreachModel> openBreaches;

  /// How long a seller has to get an order moving. Null when not configured.
  final int? processingWindowHours;

  ScorecardModel({
    this.ordersTotal = 0,
    this.delivered = 0,
    this.canceled = 0,
    this.returned = 0,
    this.failed = 0,
    this.fulfillmentRate = 0,
    this.cancellationRate = 0,
    this.returnRate = 0,
    this.itemsTotal = 0,
    this.itemsRefunded = 0,
    this.refundRate = 0,
    this.avgRating,
    this.reviewCount = 0,
    this.moderationStrikes = 0,
    this.kycStatus,
    this.tier = 'new',
    this.thresholds = const <String, double>{},
    this.overTheLine = const <SlaBreachModel>[],
    this.openBreaches = const <SlaBreachModel>[],
    this.processingWindowHours,
  });

  /// The ceiling for one rate, or null when the marketplace has not published one.
  ///
  /// Null rather than a fallback constant on purpose: a guessed ceiling is the
  /// bug this field exists to remove, and a rate with no published limit is
  /// shown plainly rather than judged against a number nobody set.
  double? ceilingFor(String metric) => thresholds[metric];

  bool isOverTheLine(String metric) =>
      overTheLine.any((SlaBreachModel breach) => breach.metric == metric);

  factory ScorecardModel.fromJson(Map<String, dynamic> json) {
    return ScorecardModel(
      ordersTotal: _toInt(json['orders_total']),
      delivered: _toInt(json['delivered']),
      canceled: _toInt(json['canceled']),
      returned: _toInt(json['returned']),
      failed: _toInt(json['failed']),
      fulfillmentRate: _toDouble(json['fulfillment_rate']),
      cancellationRate: _toDouble(json['cancellation_rate']),
      returnRate: _toDouble(json['return_rate']),
      itemsTotal: _toInt(json['items_total']),
      itemsRefunded: _toInt(json['items_refunded']),
      refundRate: _toDouble(json['refund_rate']),
      avgRating: json['avg_rating'] != null ? double.tryParse('${json['avg_rating']}') : null,
      reviewCount: _toInt(json['review_count']),
      moderationStrikes: _toInt(json['moderation_strikes']),
      kycStatus: json['kyc_status'],
      tier: json['tier'] ?? 'new',
      thresholds: _toThresholds(json['thresholds']),
      overTheLine: SlaBreachModel.listFrom(json['over_the_line']),
      openBreaches: SlaBreachModel.listFrom(json['open_breaches']),
      processingWindowHours: json['processing_window_hours'] == null
          ? null
          : int.tryParse('${json['processing_window_hours']}'),
    );
  }
}

/// One line crossed: what was measured, and what it was measured against.
///
/// The threshold travels with the breach rather than being looked up when it is
/// drawn. A marketplace that raises its ceiling next month has not un-breached
/// last month, and a row that re-read the current limit would say it had.
class SlaBreachModel {
  final int? id;
  final String metric;
  final double actualValue;
  final double threshold;
  final String? status;
  final DateTime? openedAt;
  final DateTime? clearedAt;

  const SlaBreachModel({
    this.id,
    required this.metric,
    this.actualValue = 0,
    this.threshold = 0,
    this.status,
    this.openedAt,
    this.clearedAt,
  });

  bool get isOpen => clearedAt == null;

  factory SlaBreachModel.fromJson(Map<String, dynamic> json) {
    return SlaBreachModel(
      id: json['id'] == null ? null : int.tryParse('${json['id']}'),
      metric: '${json['metric'] ?? ''}',
      actualValue: _toDouble(json['actual_value']),
      threshold: _toDouble(json['threshold']),
      status: json['status'],
      openedAt: DateTime.tryParse('${json['opened_at'] ?? json['created_at'] ?? ''}'),
      clearedAt: DateTime.tryParse('${json['cleared_at'] ?? ''}'),
    );
  }

  static List<SlaBreachModel> listFrom(dynamic value) {
    if (value is! List) {
      return const <SlaBreachModel>[];
    }

    return value
        .whereType<Map<String, dynamic>>()
        .map(SlaBreachModel.fromJson)
        .toList(growable: false);
  }
}

Map<String, double> _toThresholds(dynamic value) {
  if (value is! Map) {
    return const <String, double>{};
  }

  final Map<String, double> parsed = <String, double>{};
  value.forEach((dynamic key, dynamic threshold) {
    final double? number = double.tryParse('$threshold');
    if (number != null) {
      parsed['$key'] = number;
    }
  });

  return parsed;
}

double _toDouble(dynamic value) => double.tryParse('$value') ?? 0;

int _toInt(dynamic value) => int.tryParse('$value') ?? 0;
