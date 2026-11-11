/// What one order is worth to the seller, and how it got here.
///
/// `sellerReceives` is deliberately nullable. The server answers with the record
/// that will actually pay the seller, and where no earning has been booked yet
/// it says so instead of estimating — a figure a seller reads as "what I will be
/// paid" may only come from the thing that pays them.
class OrderBreakdownModel {
  final int orderId;
  final OrderFeesModel? fees;
  final List<OrderTimelineEventModel> timeline;
  final OrderSlaModel? sla;

  const OrderBreakdownModel({
    required this.orderId,
    this.fees,
    this.timeline = const <OrderTimelineEventModel>[],
    this.sla,
  });

  factory OrderBreakdownModel.fromJson(Map<String, dynamic> json) => OrderBreakdownModel(
        orderId: _int(json['order_id']) ?? 0,
        fees: json['fees'] is Map ? OrderFeesModel.fromJson(Map<String, dynamic>.from(json['fees'] as Map)) : null,
        timeline: json['timeline'] is List
            ? (json['timeline'] as List)
                .whereType<Map>()
                .map((row) => OrderTimelineEventModel.fromJson(Map<String, dynamic>.from(row)))
                .toList()
            : const <OrderTimelineEventModel>[],
        sla: json['sla'] is Map ? OrderSlaModel.fromJson(Map<String, dynamic>.from(json['sla'] as Map)) : null,
      );

  static int? _int(dynamic value) => value is int ? value : int.tryParse(value?.toString() ?? '');

  static double? _double(dynamic value) =>
      value == null ? null : (value is num ? value.toDouble() : double.tryParse(value.toString()));
}

class OrderFeesModel {
  /// `commission_ledger`, `order_transaction` or `not_recorded`. The last one is
  /// a real state, not an error.
  final String source;
  final bool isSettled;
  final String? currency;

  final int itemCount;
  final int quantity;
  final double itemsPrice;
  final double itemsDiscount;
  final double itemsTax;

  final double? commissionableAmount;
  final double? commissionAmount;
  final double? reversedAmount;
  final double? sellerReceives;
  final List<OrderCommissionRuleModel> rules;

  final double? shippingCost;
  final String? shippingBorneBy;
  final bool isShippingFree;

  final double? orderTotal;
  final String? paymentMethod;
  final String? paymentStatus;

  final List<OrderLedgerEntryModel> ledger;

  const OrderFeesModel({
    required this.source,
    required this.isSettled,
    this.currency,
    this.itemCount = 0,
    this.quantity = 0,
    this.itemsPrice = 0,
    this.itemsDiscount = 0,
    this.itemsTax = 0,
    this.commissionableAmount,
    this.commissionAmount,
    this.reversedAmount,
    this.sellerReceives,
    this.rules = const <OrderCommissionRuleModel>[],
    this.shippingCost,
    this.shippingBorneBy,
    this.isShippingFree = false,
    this.orderTotal,
    this.paymentMethod,
    this.paymentStatus,
    this.ledger = const <OrderLedgerEntryModel>[],
  });

  factory OrderFeesModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> items =
        json['items'] is Map ? Map<String, dynamic>.from(json['items'] as Map) : <String, dynamic>{};
    final Map<String, dynamic> shipping =
        json['shipping'] is Map ? Map<String, dynamic>.from(json['shipping'] as Map) : <String, dynamic>{};

    return OrderFeesModel(
      source: json['source']?.toString() ?? 'not_recorded',
      isSettled: json['is_settled'] == true,
      currency: json['currency']?.toString(),
      itemCount: OrderBreakdownModel._int(items['count']) ?? 0,
      quantity: OrderBreakdownModel._int(items['quantity']) ?? 0,
      itemsPrice: OrderBreakdownModel._double(items['price']) ?? 0,
      itemsDiscount: OrderBreakdownModel._double(items['discount']) ?? 0,
      itemsTax: OrderBreakdownModel._double(items['tax']) ?? 0,
      commissionableAmount: OrderBreakdownModel._double(json['commissionable_amount']),
      commissionAmount: OrderBreakdownModel._double(json['commission_amount']),
      reversedAmount: OrderBreakdownModel._double(json['reversed_amount']),
      sellerReceives: OrderBreakdownModel._double(json['seller_receives']),
      rules: json['commission_rules'] is List
          ? (json['commission_rules'] as List)
              .whereType<Map>()
              .map((row) => OrderCommissionRuleModel.fromJson(Map<String, dynamic>.from(row)))
              .toList()
          : const <OrderCommissionRuleModel>[],
      shippingCost: OrderBreakdownModel._double(shipping['cost']),
      shippingBorneBy: shipping['borne_by']?.toString(),
      isShippingFree: shipping['is_free'] == true,
      orderTotal: OrderBreakdownModel._double(json['order_total']),
      paymentMethod: json['payment_method']?.toString(),
      paymentStatus: json['payment_status']?.toString(),
      ledger: json['ledger'] is List
          ? (json['ledger'] as List)
              .whereType<Map>()
              .map((row) => OrderLedgerEntryModel.fromJson(Map<String, dynamic>.from(row)))
              .toList()
          : const <OrderLedgerEntryModel>[],
    );
  }
}

/// The rule that charged, so a seller can see why rather than only how much.
class OrderCommissionRuleModel {
  final String? label;
  final String? scope;
  final String? rateType;
  final double? percentage;
  final double? fixedAmount;
  final double? commissionableAmount;
  final double? commissionAmount;

  const OrderCommissionRuleModel({
    this.label,
    this.scope,
    this.rateType,
    this.percentage,
    this.fixedAmount,
    this.commissionableAmount,
    this.commissionAmount,
  });

  factory OrderCommissionRuleModel.fromJson(Map<String, dynamic> json) => OrderCommissionRuleModel(
        label: json['label']?.toString(),
        scope: json['scope']?.toString(),
        rateType: json['rate_type']?.toString(),
        percentage: OrderBreakdownModel._double(json['percentage']),
        fixedAmount: OrderBreakdownModel._double(json['fixed_amount']),
        commissionableAmount: OrderBreakdownModel._double(json['commissionable_amount']),
        commissionAmount: OrderBreakdownModel._double(json['commission_amount']),
      );
}

/// One ledger line this order produced. `availableAt` is when a pending earning
/// becomes withdrawable — the most asked question about a seller's balance, and
/// one the app has never been able to answer per order.
class OrderLedgerEntryModel {
  final String entryType;
  final double credit;
  final double debit;
  final String? status;
  final String? availableAt;
  final String? description;

  const OrderLedgerEntryModel({
    required this.entryType,
    this.credit = 0,
    this.debit = 0,
    this.status,
    this.availableAt,
    this.description,
  });

  factory OrderLedgerEntryModel.fromJson(Map<String, dynamic> json) => OrderLedgerEntryModel(
        entryType: json['entry_type']?.toString() ?? '',
        credit: OrderBreakdownModel._double(json['credit']) ?? 0,
        debit: OrderBreakdownModel._double(json['debit']) ?? 0,
        status: json['status']?.toString(),
        availableAt: json['available_at']?.toString(),
        description: json['description']?.toString(),
      );
}

class OrderTimelineEventModel {
  final String key;
  final String? at;
  final String? actor;
  final String? note;

  const OrderTimelineEventModel({required this.key, this.at, this.actor, this.note});

  factory OrderTimelineEventModel.fromJson(Map<String, dynamic> json) => OrderTimelineEventModel(
        key: json['key']?.toString() ?? '',
        at: json['at']?.toString(),
        actor: json['actor']?.toString(),
        note: json['note']?.toString(),
      );
}

/// The processing countdown, present only while the order still waits on the
/// seller. Once it is with the courier there is nothing left to be late for.
class OrderSlaModel {
  final String? deadline;
  final double? hoursLeft;
  final bool isLate;
  final int? windowHours;

  const OrderSlaModel({this.deadline, this.hoursLeft, this.isLate = false, this.windowHours});

  factory OrderSlaModel.fromJson(Map<String, dynamic> json) => OrderSlaModel(
        deadline: json['deadline']?.toString(),
        hoursLeft: OrderBreakdownModel._double(json['hours_left']),
        isLate: json['is_late'] == true,
        windowHours: OrderBreakdownModel._int(json['window_hours']),
      );
}
