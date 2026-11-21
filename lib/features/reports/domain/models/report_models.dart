// The seller's reports, as the API returns them.
//
// Every figure comes from the same service the vendor panel reads, so a number
// shown here is the number shown there. The models keep that faithful: nothing
// is recomputed on the client that the server already decided.

/// The period a report covers.
class ReportPeriodModel {
  final String dateType;
  final List<String> dateTypes;
  final String? from;
  final String? to;

  /// How the chart is bucketed — hour, weekday, day, month or year. Chosen by
  /// the server from the period's length, so the client never has to guess.
  final String? bucket;

  ReportPeriodModel({
    this.dateType = 'this_year',
    this.dateTypes = const <String>[],
    this.from,
    this.to,
    this.bucket,
  });

  factory ReportPeriodModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ReportPeriodModel();
    return ReportPeriodModel(
      dateType: '${json['date_type'] ?? 'this_year'}',
      dateTypes: json['date_types'] is List
          ? List<String>.from((json['date_types'] as List).map((e) => '$e'))
          : const <String>[],
      from: json['from']?.toString(),
      to: json['to']?.toString(),
      bucket: json['bucket']?.toString(),
    );
  }

  bool get isCustom => dateType == 'custom_date';
}

/// A chart the server drew from the calendar: one bucket per period, present
/// whether or not anything happened in it.
class ReportChartModel {
  final List<String> labels;
  final List<double> values;

  ReportChartModel({this.labels = const <String>[], this.values = const <double>[]});

  factory ReportChartModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ReportChartModel();
    return ReportChartModel(
      labels: json['labels'] is List
          ? List<String>.from((json['labels'] as List).map((e) => '$e'))
          : const <String>[],
      values: json['values'] is List
          ? (json['values'] as List).map((e) => _toDouble(e)).toList()
          : const <double>[],
    );
  }

  /// A flat line is data — it says nothing sold. An empty chart is not.
  bool get hasBars => values.isNotEmpty;

  double get peak => values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);

  /// Labels and values can only be read together, and only as far as both go.
  int get length => labels.length < values.length ? labels.length : values.length;
}

/// One currency's own figures, when the period holds more than one.
///
/// A seller selling in Riyadh and Dubai takes riyals and dirhams in the same
/// period, and the server will not add them: it answers each currency's real
/// figures and says why there is no single total. This is one of those groups,
/// kept as a map so a new figure on the server reaches the screen without a
/// field here — the keys are the server's own (`due`, `settled`, `cash`, …).
class ReportCurrencyFiguresModel {
  final String currencyCode;
  final Map<String, double> figures;

  const ReportCurrencyFiguresModel({this.currencyCode = '', this.figures = const <String, double>{}});

  factory ReportCurrencyFiguresModel.fromJson(Map<String, dynamic> json) {
    final Map<String, double> figures = <String, double>{};

    json.forEach((String key, dynamic value) {
      if (key == 'currency_code' || value == null) return;

      if (value is num) {
        figures[key] = value.toDouble();
        return;
      }

      final double? parsed = double.tryParse('$value');
      if (parsed != null) {
        figures[key] = parsed;
      }
    });

    return ReportCurrencyFiguresModel(
      currencyCode: json['currency_code']?.toString() ?? '',
      figures: figures,
    );
  }

  double? operator [](String name) => figures[name];
}

/// Reads a list of per-currency groups out of an answer, empty when the server
/// gave one combined figure and there is nothing to keep apart.
List<ReportCurrencyFiguresModel> _currencyGroups(dynamic value) => value is List
    ? value.map((e) => ReportCurrencyFiguresModel.fromJson(_map(e))).toList()
    : const <ReportCurrencyFiguresModel>[];

class OrderReportModel {
  final ReportPeriodModel period;
  final int ongoing;
  final int canceled;
  final int delivered;
  final int total;

  /// **Nullable, and null is not zero.** Where the period holds orders in more
  /// than one currency the server refuses the single figure — a sum of riyals
  /// and dirhams is not money — and answers the per-currency figures with a
  /// reason. Reading those nulls as `0` showed `0.00 / 0.00 / 0.00` to a seller
  /// who was owed 1015 across three currencies, and a zero looks authoritative
  /// in a way a blank does not: a seller reads it as "there is nothing owed"
  /// and acts on it. This does **not** need a market grant to happen: the
  /// server refuses as soon as the orders of the period carry two currency
  /// codes, which an installation can reach with no market scopes switched on.
  final double? due;
  final double? settled;

  /// Null for the same reason as the two above, rather than a zeroed breakdown.
  final ReportPaymentsModel? payments;
  final ReportChartModel chart;
  final List<ReportOrderModel> orders;
  final int totalOrderCount;

  /// Why there is no one figure, as a language key, or null when there is one.
  final String? totalsRefusedBecause;

  /// Each currency's own amounts and payment breakdown, and its own settled
  /// series. Both empty while the period is in one currency, which is when the
  /// combined figures above are the answer.
  final List<ReportCurrencyFiguresModel> amountsByCurrency;
  final List<ReportCurrencySeriesModel> chartByCurrency;

  OrderReportModel({
    ReportPeriodModel? period,
    this.ongoing = 0,
    this.canceled = 0,
    this.delivered = 0,
    this.total = 0,
    this.due,
    this.settled,
    this.payments,
    ReportChartModel? chart,
    this.orders = const <ReportOrderModel>[],
    this.totalOrderCount = 0,
    this.totalsRefusedBecause,
    this.amountsByCurrency = const <ReportCurrencyFiguresModel>[],
    this.chartByCurrency = const <ReportCurrencySeriesModel>[],
  })  : period = period ?? ReportPeriodModel(),
        chart = chart ?? ReportChartModel();

  factory OrderReportModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> counts = _map(json['counts']);
    final Map<String, dynamic>? amounts = _mapOrNull(json['amounts']);
    final Map<String, dynamic> orders = _map(json['orders']);

    return OrderReportModel(
      period: ReportPeriodModel.fromJson(_mapOrNull(json['period'])),
      ongoing: _toInt(counts['ongoing']),
      canceled: _toInt(counts['canceled']),
      delivered: _toInt(counts['delivered']),
      total: _toInt(counts['total']),
      due: amounts == null ? null : _toDouble(amounts['due']),
      settled: amounts == null ? null : _toDouble(amounts['settled']),
      payments: json['payments'] == null ? null : ReportPaymentsModel.fromJson(_mapOrNull(json['payments'])),
      chart: ReportChartModel.fromJson(_mapOrNull(json['chart'])),
      totalsRefusedBecause: json['totals_refused_because']?.toString(),
      amountsByCurrency: _currencyGroups(json['amounts_by_currency']),
      chartByCurrency: json['chart_by_currency'] is List
          ? (json['chart_by_currency'] as List).map((e) => ReportCurrencySeriesModel.fromJson(_map(e))).toList()
          : const <ReportCurrencySeriesModel>[],
      orders: orders['orders'] is List
          ? (orders['orders'] as List).map((e) => ReportOrderModel.fromJson(_map(e))).toList()
          : const <ReportOrderModel>[],
      totalOrderCount: _toInt(orders['total_size']),
    );
  }

  /// Whether the server refused to add two currencies. When it did there is no
  /// `due`, `settled`, `payments` or chart series to draw, and the screen shows
  /// the reason and each currency's own figures instead.
  bool get totalsRefused => totalsRefusedBecause != null;

  /// What the seller is owed plus what has settled — the figure the panel
  /// prints above the split. Null when there is no one figure to add.
  double? get turnover => totalsRefused ? null : (due ?? 0) + (settled ?? 0);
}

/// One currency's own settled series, over the labels the combined chart uses.
class ReportCurrencySeriesModel {
  final String currencyCode;
  final List<double> values;

  const ReportCurrencySeriesModel({this.currencyCode = '', this.values = const <double>[]});

  factory ReportCurrencySeriesModel.fromJson(Map<String, dynamic> json) => ReportCurrencySeriesModel(
        currencyCode: json['currency_code']?.toString() ?? '',
        values: json['values'] is List
            ? (json['values'] as List).map((e) => _toDouble(e)).toList()
            : const <double>[],
      );
}

/// What was paid, and by what means. `total` already has returns taken out and
/// order edits folded in, so the client must not re-add the parts.
class ReportPaymentsModel {
  final double cash;
  final double wallet;
  final double digital;
  final double offline;
  final double returned;
  final double total;

  ReportPaymentsModel({
    this.cash = 0,
    this.wallet = 0,
    this.digital = 0,
    this.offline = 0,
    this.returned = 0,
    this.total = 0,
  });

  factory ReportPaymentsModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ReportPaymentsModel();
    return ReportPaymentsModel(
      cash: _toDouble(json['cash']),
      wallet: _toDouble(json['wallet']),
      digital: _toDouble(json['digital']),
      offline: _toDouble(json['offline']),
      returned: _toDouble(json['returned']),
      total: _toDouble(json['total']),
    );
  }

  bool get hasAny => cash != 0 || wallet != 0 || digital != 0 || offline != 0 || returned != 0;
}

class ReportOrderModel {
  final int id;
  final String? orderStatus;
  final String? paymentStatus;
  final String? paymentMethod;
  final double orderAmount;
  final double productDiscount;
  final double couponDiscount;
  final double tax;
  final double shippingCost;
  final double commission;
  final String? createdAt;

  ReportOrderModel({
    this.id = 0,
    this.orderStatus,
    this.paymentStatus,
    this.paymentMethod,
    this.orderAmount = 0,
    this.productDiscount = 0,
    this.couponDiscount = 0,
    this.tax = 0,
    this.shippingCost = 0,
    this.commission = 0,
    this.createdAt,
  });

  factory ReportOrderModel.fromJson(Map<String, dynamic> json) => ReportOrderModel(
        id: _toInt(json['id']),
        orderStatus: json['order_status']?.toString(),
        paymentStatus: json['payment_status']?.toString(),
        paymentMethod: json['payment_method']?.toString(),
        orderAmount: _toDouble(json['order_amount']),
        productDiscount: _toDouble(json['product_discount']),
        couponDiscount: _toDouble(json['discount_amount']),
        tax: _toDouble(json['tax']),
        shippingCost: _toDouble(json['shipping_cost']),
        commission: _toDouble(json['commission']),
        createdAt: json['created_at']?.toString(),
      );
}

class ProductReportModel {
  final ReportPeriodModel period;
  final int active;
  final int pending;
  final int rejected;
  final double soldQuantity;

  /// Nullable for the same reason as the order report's amounts: the server
  /// refuses `sold_amount` and `discount_given` over two currencies. The
  /// **quantity** is never refused — a unit sold in Riyadh and a unit sold in
  /// Dubai are two units — so it stays non-null.
  final double? soldAmount;
  final double? discountGiven;
  final ReportChartModel chart;
  final List<TopProductModel> topProducts;
  final List<ReportProductModel> products;
  final int totalProductCount;

  /// Why there is no one figure, as a language key, or null when there is one.
  final String? totalsRefusedBecause;

  /// What each currency sold, when there is more than one.
  final List<ReportCurrencyFiguresModel> totalsByCurrency;

  ProductReportModel({
    ReportPeriodModel? period,
    this.active = 0,
    this.pending = 0,
    this.rejected = 0,
    this.soldQuantity = 0,
    this.soldAmount,
    this.discountGiven,
    ReportChartModel? chart,
    this.topProducts = const <TopProductModel>[],
    this.products = const <ReportProductModel>[],
    this.totalProductCount = 0,
    this.totalsRefusedBecause,
    this.totalsByCurrency = const <ReportCurrencyFiguresModel>[],
  })  : period = period ?? ReportPeriodModel(),
        chart = chart ?? ReportChartModel();

  factory ProductReportModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> counts = _map(json['counts']);
    final Map<String, dynamic> totals = _map(json['totals']);
    final Map<String, dynamic> products = _map(json['products']);

    return ProductReportModel(
      period: ReportPeriodModel.fromJson(_mapOrNull(json['period'])),
      active: _toInt(counts['active']),
      pending: _toInt(counts['pending']),
      rejected: _toInt(counts['rejected']),
      soldQuantity: _toDouble(totals['sold_quantity']),
      soldAmount: totals['sold_amount'] == null ? null : _toDouble(totals['sold_amount']),
      discountGiven: totals['discount_given'] == null ? null : _toDouble(totals['discount_given']),
      chart: ReportChartModel.fromJson(_mapOrNull(json['chart'])),
      totalsRefusedBecause: json['totals_refused_because']?.toString(),
      totalsByCurrency: _currencyGroups(json['totals_by_currency']),
      topProducts: json['top_products'] is List
          ? (json['top_products'] as List).map((e) => TopProductModel.fromJson(_map(e))).toList()
          : const <TopProductModel>[],
      products: products['products'] is List
          ? (products['products'] as List).map((e) => ReportProductModel.fromJson(_map(e))).toList()
          : const <ReportProductModel>[],
      totalProductCount: _toInt(products['total_size']),
    );
  }

  int get listedTotal => active + pending + rejected;

  /// Whether the server refused to add two currencies' money figures.
  bool get totalsRefused => totalsRefusedBecause != null;
}

class TopProductModel {
  final int productId;
  final String? name;
  final String? thumbnail;
  final double totalAmount;
  final double totalQuantity;

  TopProductModel({
    this.productId = 0,
    this.name,
    this.thumbnail,
    this.totalAmount = 0,
    this.totalQuantity = 0,
  });

  factory TopProductModel.fromJson(Map<String, dynamic> json) => TopProductModel(
        productId: _toInt(json['product_id']),
        name: json['name']?.toString(),
        thumbnail: json['thumbnail']?.toString(),
        totalAmount: _toDouble(json['total_amount']),
        totalQuantity: _toDouble(json['total_quantity']),
      );
}

class ReportProductModel {
  final int id;
  final String? name;
  final String? thumbnail;
  final double unitPrice;
  final int currentStock;
  final int requestStatus;
  final double soldQuantity;
  final double soldAmount;

  ReportProductModel({
    this.id = 0,
    this.name,
    this.thumbnail,
    this.unitPrice = 0,
    this.currentStock = 0,
    this.requestStatus = 0,
    this.soldQuantity = 0,
    this.soldAmount = 0,
  });

  factory ReportProductModel.fromJson(Map<String, dynamic> json) => ReportProductModel(
        id: _toInt(json['id']),
        name: json['name']?.toString(),
        thumbnail: json['thumbnail']?.toString(),
        unitPrice: _toDouble(json['unit_price']),
        currentStock: _toInt(json['current_stock']),
        requestStatus: _toInt(json['request_status']),
        soldQuantity: _toDouble(json['sold_quantity']),
        soldAmount: _toDouble(json['sold_amount']),
      );
}

class StockReportModel {
  final int stockLimit;
  final List<StockCategoryModel> categories;
  final List<StockProductModel> products;
  final int totalSize;

  StockReportModel({
    this.stockLimit = 0,
    this.categories = const <StockCategoryModel>[],
    this.products = const <StockProductModel>[],
    this.totalSize = 0,
  });

  factory StockReportModel.fromJson(Map<String, dynamic> json) => StockReportModel(
        stockLimit: _toInt(json['stock_limit']),
        categories: json['categories'] is List
            ? (json['categories'] as List).map((e) => StockCategoryModel.fromJson(_map(e))).toList()
            : const <StockCategoryModel>[],
        products: json['products'] is List
            ? (json['products'] as List).map((e) => StockProductModel.fromJson(_map(e))).toList()
            : const <StockProductModel>[],
        totalSize: _toInt(json['total_size']),
      );

  int get lowStockCount => products.where((product) => product.isLowStock).length;
}

class StockCategoryModel {
  final int id;
  final String? name;

  StockCategoryModel({this.id = 0, this.name});

  factory StockCategoryModel.fromJson(Map<String, dynamic> json) =>
      StockCategoryModel(id: _toInt(json['id']), name: json['name']?.toString());
}

class StockProductModel {
  final int id;
  final String? name;
  final String? thumbnail;
  final double unitPrice;
  final int currentStock;

  /// The server decides this against the seller's own threshold, or the
  /// platform default when they have not set one. The client must not
  /// second-guess it with a hard-coded number.
  final bool isLowStock;

  StockProductModel({
    this.id = 0,
    this.name,
    this.thumbnail,
    this.unitPrice = 0,
    this.currentStock = 0,
    this.isLowStock = false,
  });

  factory StockProductModel.fromJson(Map<String, dynamic> json) => StockProductModel(
        id: _toInt(json['id']),
        name: json['name']?.toString(),
        thumbnail: json['thumbnail']?.toString(),
        unitPrice: _toDouble(json['unit_price']),
        currentStock: _toInt(json['current_stock']),
        isLowStock: json['is_low_stock'] == true,
      );
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

Map<String, dynamic>? _mapOrNull(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

int _toInt(dynamic value) =>
    value is int ? value : (value is num ? value.toInt() : int.tryParse('$value') ?? 0);

double _toDouble(dynamic value) =>
    value is double ? value : (value is num ? value.toDouble() : double.tryParse('$value') ?? 0);
