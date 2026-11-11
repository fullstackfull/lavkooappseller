/// A seller's storefront analytics for one window, as
/// `GET /api/v3/seller/seller-center/analytics` returns it.
class SellerAnalyticsModel {
  final String range;
  final String rangeLabel;
  final List<String> ranges;
  final String? from;
  final String? to;

  /// 'ok', 'not_installed' when the analytics tables are absent, or a reason
  /// the window came back empty ('rollup_never_ran', 'no_traffic', ...).
  final String state;
  final AnalyticsSummaryModel? summary;
  final List<AnalyticsProductModel> products;

  SellerAnalyticsModel({
    this.range = '30d',
    this.rangeLabel = 'last_30_days',
    this.ranges = const [],
    this.from,
    this.to,
    this.state = 'not_installed',
    this.summary,
    this.products = const [],
  });

  bool get hasData => state == 'ok';

  factory SellerAnalyticsModel.fromJson(Map<String, dynamic> json) {
    return SellerAnalyticsModel(
      range: json['range'] ?? '30d',
      rangeLabel: json['range_label'] ?? 'last_30_days',
      ranges: json['ranges'] != null
          ? List<String>.from(json['ranges'].map((range) => '$range'))
          : const [],
      from: json['from'],
      to: json['to'],
      state: json['state'] ?? 'not_installed',
      summary: json['summary'] != null ? AnalyticsSummaryModel.fromJson(json['summary']) : null,
      products: json['products'] != null
          ? List<AnalyticsProductModel>.from(
              json['products'].map((product) => AnalyticsProductModel.fromJson(product)))
          : const [],
    );
  }
}

class AnalyticsSummaryModel {
  final int visitors;
  final int sessions;
  final int productViews;
  final int cartAdds;
  final int orders;
  final double revenue;

  AnalyticsSummaryModel({
    this.visitors = 0,
    this.sessions = 0,
    this.productViews = 0,
    this.cartAdds = 0,
    this.orders = 0,
    this.revenue = 0,
  });

  factory AnalyticsSummaryModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsSummaryModel(
      visitors: _toInt(json['visitors']),
      sessions: _toInt(json['sessions']),
      productViews: _toInt(json['product_views']),
      cartAdds: _toInt(json['cart_adds']),
      orders: _toInt(json['orders']),
      revenue: double.tryParse('${json['revenue']}') ?? 0,
    );
  }

  /// Views that turned into a cart add — the number that tells a seller whether
  /// a product page is doing its job.
  double get cartAddRate => productViews > 0 ? cartAdds / productViews : 0;
}

class AnalyticsProductModel {
  final int? productId;
  final String? name;
  final int events;
  final int visitors;
  final int views;
  final int cartAdds;

  AnalyticsProductModel({
    this.productId,
    this.name,
    this.events = 0,
    this.visitors = 0,
    this.views = 0,
    this.cartAdds = 0,
  });

  factory AnalyticsProductModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsProductModel(
      productId: int.tryParse('${json['product_id']}'),
      name: json['name'],
      events: _toInt(json['events']),
      visitors: _toInt(json['visitors']),
      views: _toInt(json['views']),
      cartAdds: _toInt(json['cart_adds']),
    );
  }
}

/// Counts of what is waiting for the seller right now.
class SellerActivitiesModel {
  final int newOrderCount;
  final int restockProductCount;
  final int restockRequestCount;

  SellerActivitiesModel({
    this.newOrderCount = 0,
    this.restockProductCount = 0,
    this.restockRequestCount = 0,
  });

  bool get hasAny => newOrderCount > 0 || restockProductCount > 0;

  factory SellerActivitiesModel.fromJson(Map<String, dynamic> json) {
    return SellerActivitiesModel(
      newOrderCount: _toInt(json['new_order_count']),
      restockProductCount: _toInt(json['restock_product_count']),
      restockRequestCount: _toInt(json['restock_request_count']),
    );
  }
}

int _toInt(dynamic value) => int.tryParse('$value') ?? 0;
