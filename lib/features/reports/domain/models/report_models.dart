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

class OrderReportModel {
  final ReportPeriodModel period;
  final int ongoing;
  final int canceled;
  final int delivered;
  final int total;
  final double due;
  final double settled;
  final ReportPaymentsModel payments;
  final ReportChartModel chart;
  final List<ReportOrderModel> orders;
  final int totalOrderCount;

  OrderReportModel({
    ReportPeriodModel? period,
    this.ongoing = 0,
    this.canceled = 0,
    this.delivered = 0,
    this.total = 0,
    this.due = 0,
    this.settled = 0,
    ReportPaymentsModel? payments,
    ReportChartModel? chart,
    this.orders = const <ReportOrderModel>[],
    this.totalOrderCount = 0,
  })  : period = period ?? ReportPeriodModel(),
        payments = payments ?? ReportPaymentsModel(),
        chart = chart ?? ReportChartModel();

  factory OrderReportModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> counts = _map(json['counts']);
    final Map<String, dynamic> amounts = _map(json['amounts']);
    final Map<String, dynamic> orders = _map(json['orders']);

    return OrderReportModel(
      period: ReportPeriodModel.fromJson(_mapOrNull(json['period'])),
      ongoing: _toInt(counts['ongoing']),
      canceled: _toInt(counts['canceled']),
      delivered: _toInt(counts['delivered']),
      total: _toInt(counts['total']),
      due: _toDouble(amounts['due']),
      settled: _toDouble(amounts['settled']),
      payments: ReportPaymentsModel.fromJson(_mapOrNull(json['payments'])),
      chart: ReportChartModel.fromJson(_mapOrNull(json['chart'])),
      orders: orders['orders'] is List
          ? (orders['orders'] as List).map((e) => ReportOrderModel.fromJson(_map(e))).toList()
          : const <ReportOrderModel>[],
      totalOrderCount: _toInt(orders['total_size']),
    );
  }

  /// What the seller is owed plus what has settled — the figure the panel
  /// prints above the split.
  double get turnover => due + settled;
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
  final double soldAmount;
  final double discountGiven;
  final ReportChartModel chart;
  final List<TopProductModel> topProducts;
  final List<ReportProductModel> products;
  final int totalProductCount;

  ProductReportModel({
    ReportPeriodModel? period,
    this.active = 0,
    this.pending = 0,
    this.rejected = 0,
    this.soldQuantity = 0,
    this.soldAmount = 0,
    this.discountGiven = 0,
    ReportChartModel? chart,
    this.topProducts = const <TopProductModel>[],
    this.products = const <ReportProductModel>[],
    this.totalProductCount = 0,
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
      soldAmount: _toDouble(totals['sold_amount']),
      discountGiven: _toDouble(totals['discount_given']),
      chart: ReportChartModel.fromJson(_mapOrNull(json['chart'])),
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
