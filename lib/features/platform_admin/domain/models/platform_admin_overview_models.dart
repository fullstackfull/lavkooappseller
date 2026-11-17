import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_json.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_market_models.dart';

/// The windows the app offers, and how one is asked for.
abstract final class PlatformWindows {
  static const List<int> choices = <int>[7, 30, 92];

  /// What the server answers when it is asked for no window at all. The app
  /// reads the window it was actually given from the answer.
  static const int defaultDays = 30;

  /// The first day of a window of [days] ending on [today], written the way the
  /// API reads a date (`YYYY-MM-DD`). Never locale-formatted: in Arabic a
  /// formatted date would come out in other digits.
  static String firstDay({required int days, required DateTime today}) {
    final DateTime first = DateTime(today.year, today.month, today.day - (days - 1));
    final String month = first.month.toString().padLeft(2, '0');
    final String day = first.day.toString().padLeft(2, '0');
    return '${first.year.toString().padLeft(4, '0')}-$month-$day';
  }
}

/// The span of days an overview counted, as the server resolved it.
class PlatformWindowModel {
  /// Calendar days written `YYYY-MM-DD`, in the zone the platform stamps its rows in.
  final String from;
  final String to;
  final int days;

  /// The server cut the window it was asked for to the longest it allows.
  final bool clamped;
  final String? timezone;

  const PlatformWindowModel({
    required this.from,
    required this.to,
    required this.days,
    required this.clamped,
    this.timezone,
  });

  factory PlatformWindowModel.fromJson(Map<String, dynamic> json) => PlatformWindowModel(
        from: PlatformJson.string(json['from']) ?? '',
        to: PlatformJson.string(json['to']) ?? '',
        days: PlatformJson.count(json['days']),
        clamped: PlatformJson.flag(json['clamped']),
        timezone: PlatformJson.string(json['timezone']),
      );
}

/// How the figures were obtained: counted at the moment of the request, or kept.
class PlatformFreshness {
  final String mode;
  final bool cached;

  const PlatformFreshness({this.mode = 'live', this.cached = false});

  factory PlatformFreshness.fromJson(Map<String, dynamic> json) => PlatformFreshness(
        mode: PlatformJson.string(json['mode']) ?? 'live',
        cached: PlatformJson.flag(json['cached']),
      );
}

/// The orders of the window: how many, in which state, and when the newest came.
///
/// `byStatus` keeps the order the server sent: every status the platform knows
/// first, with zero for the ones that have no order, then any other it found.
class PlatformOrderFigures {
  final int total;
  final Map<String, int> byStatus;
  final DateTime? latestAt;

  const PlatformOrderFigures({required this.total, required this.byStatus, this.latestAt});

  factory PlatformOrderFigures.fromJson(Map<String, dynamic> json) => PlatformOrderFigures(
        total: PlatformJson.count(json['total']),
        byStatus: <String, int>{
          for (final MapEntry<String, dynamic> entry in PlatformJson.map(json['by_status']).entries)
            entry.key: PlatformJson.count(entry.value),
        },
        latestAt: PlatformJson.moment(json['latest_at']),
      );
}

/// Why there is no sales figure.
///
/// This is all the app keeps of `sales`. An order stores no currency, so the
/// server reports no money; if it ever does, there is still nothing here that
/// could hold an amount, and the app shows a reason instead of a number.
class PlatformSalesFigure {
  final String? reason;

  const PlatformSalesFigure({this.reason});

  factory PlatformSalesFigure.fromJson(Map<String, dynamic> json) =>
      PlatformSalesFigure(reason: PlatformJson.string(json['reason']));

  @override
  String toString() => 'PlatformSalesFigure(reason: $reason)';
}

/// How many alerts a market has, by how serious they are.
class PlatformAlertCounts {
  final int critical;
  final int warning;
  final int info;

  const PlatformAlertCounts({this.critical = 0, this.warning = 0, this.info = 0});

  factory PlatformAlertCounts.fromJson(Map<String, dynamic> json) => PlatformAlertCounts(
        critical: PlatformJson.count(json['critical']),
        warning: PlatformJson.count(json['warning']),
        info: PlatformJson.count(json['info']),
      );

  int get total => critical + warning + info;
}

/// What the platform reports for one market, or for the orders of no market.
///
/// `pendingFulfilment` and the stock figures are states of the moment; the
/// orders and the refund requests are flows of the window.
class PlatformFigures {
  final PlatformOrderFigures orders;
  final PlatformSalesFigure sales;
  final int pendingFulfilment;
  final int refundRequests;
  final int refundRequestsPending;
  final int stockZero;
  final int stockLow;

  const PlatformFigures({
    required this.orders,
    required this.sales,
    required this.pendingFulfilment,
    required this.refundRequests,
    required this.refundRequestsPending,
    required this.stockZero,
    required this.stockLow,
  });

  factory PlatformFigures.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> returns = PlatformJson.map(json['returns']);
    final Map<String, dynamic> stock = PlatformJson.map(json['stock']);

    return PlatformFigures(
      orders: PlatformOrderFigures.fromJson(PlatformJson.map(json['orders'])),
      sales: PlatformSalesFigure.fromJson(PlatformJson.map(json['sales'])),
      pendingFulfilment: PlatformJson.count(PlatformJson.map(json['pending_fulfilment'])['count']),
      refundRequests: PlatformJson.count(returns['refund_requests']),
      refundRequestsPending: PlatformJson.count(returns['pending']),
      stockZero: PlatformJson.count(stock['zero']),
      stockLow: PlatformJson.count(stock['low']),
    );
  }
}

/// One market's card of the overview.
class PlatformMarketOverview {
  final String market;

  /// The currency the market's storefront is configured with. It is a label of
  /// the market, not the currency of any order.
  final String? storefrontCurrency;
  final bool active;
  final PlatformFigures figures;
  final PlatformAlertCounts alerts;

  const PlatformMarketOverview({
    required this.market,
    required this.active,
    required this.figures,
    required this.alerts,
    this.storefrontCurrency,
  });

  factory PlatformMarketOverview.fromJson(Map<String, dynamic> json) => PlatformMarketOverview(
        market: PlatformJson.string(json['market']) ?? '',
        storefrontCurrency: PlatformJson.string(json['storefront_currency']),
        active: PlatformJson.flag(json['active']),
        figures: PlatformFigures.fromJson(json),
        alerts: PlatformAlertCounts.fromJson(PlatformJson.map(json['alerts'])),
      );
}

/// The orders that belong to no single market: no line, a line whose product is
/// gone, lines of more than one market, or a product of a country that is not a
/// market. They are counted apart and never counted as any market's.
class PlatformUnattributedOverview {
  final PlatformFigures figures;
  final String? reason;

  const PlatformUnattributedOverview({required this.figures, this.reason});

  factory PlatformUnattributedOverview.fromJson(Map<String, dynamic> json) => PlatformUnattributedOverview(
        figures: PlatformFigures.fromJson(json),
        reason: PlatformJson.string(json['reason']),
      );
}

/// The state of the markets the viewer asked about.
class PlatformOverviewModel {
  final PlatformScope scope;

  /// What was asked: `all` or one market's code.
  final String market;
  final DateTime? generatedAt;
  final PlatformWindowModel? window;
  final PlatformFreshness freshness;
  final List<PlatformMarketOverview> markets;

  /// Only the platform owner asking for all markets gets this.
  final PlatformUnattributedOverview? unattributed;

  const PlatformOverviewModel({
    required this.scope,
    required this.market,
    required this.freshness,
    required this.markets,
    this.generatedAt,
    this.window,
    this.unattributed,
  });

  factory PlatformOverviewModel.fromJson(Map<String, dynamic> json) => PlatformOverviewModel(
        scope: PlatformScope.parse(json['scope']),
        market: PlatformJson.string(json['market']) ?? PlatformMarketCode.all,
        generatedAt: PlatformJson.moment(json['generated_at']),
        window: json['window'] is Map ? PlatformWindowModel.fromJson(PlatformJson.map(json['window'])) : null,
        freshness: PlatformFreshness.fromJson(PlatformJson.map(json['freshness'])),
        markets: PlatformJson.maps(json['markets']).map(PlatformMarketOverview.fromJson).toList(),
        unattributed: json['unattributed'] is Map
            ? PlatformUnattributedOverview.fromJson(PlatformJson.map(json['unattributed']))
            : null,
      );

  PlatformMarketOverview? marketOf(String code) {
    for (final PlatformMarketOverview overview in markets) {
      if (overview.market == code) return overview;
    }
    return null;
  }
}
