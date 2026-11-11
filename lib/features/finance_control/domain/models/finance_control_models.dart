/// Does what the seller sold add up to what the seller was paid.
///
/// `reconciles` is the server's answer and is not recomputed here. It is true
/// only when nothing fell out of either hand-off, which is a stricter question
/// than whether the two totals happen to match — a client that compared the
/// numbers itself would report a shop as fine while a line's earning was
/// missing and an extra credit covered it.
class ReconciliationModel {
  final String from;
  final String to;
  final ReconciliationStage delivered;
  final ReconciliationRecorded recorded;
  final ReconciliationCredited credited;
  final ReconciliationGap linesWithoutEarning;
  final ReconciliationGap earningsWithoutCredit;
  final bool reconciles;

  const ReconciliationModel({
    required this.from,
    required this.to,
    required this.delivered,
    required this.recorded,
    required this.credited,
    required this.linesWithoutEarning,
    required this.earningsWithoutCredit,
    required this.reconciles,
  });

  bool get hasGaps => linesWithoutEarning.count > 0 || earningsWithoutCredit.count > 0;

  static ReconciliationModel fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> gaps = _map(json['gaps']);

    return ReconciliationModel(
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
      delivered: ReconciliationStage.fromJson(_map(json['delivered'])),
      recorded: ReconciliationRecorded.fromJson(_map(json['recorded'])),
      credited: ReconciliationCredited.fromJson(_map(json['credited'])),
      linesWithoutEarning: ReconciliationGap.fromJson(_map(gaps['lines_without_earning'])),
      earningsWithoutCredit: ReconciliationGap.fromJson(_map(gaps['earnings_without_credit'])),
      reconciles: json['reconciles'] == true,
    );
  }
}

class ReconciliationStage {
  final int lines;
  final int orders;
  final double gross;

  const ReconciliationStage({required this.lines, required this.orders, required this.gross});

  static ReconciliationStage fromJson(Map<String, dynamic> json) => ReconciliationStage(
        lines: _int(json['lines']),
        orders: _int(json['orders']),
        gross: _double(json['gross']),
      );
}

class ReconciliationRecorded {
  final int lines;
  final double commission;
  final double net;

  /// Which record the figures came from: the per-line commission snapshot, the
  /// older per-order transaction, or neither. Shown rather than hidden — a
  /// figure whose provenance is unstated is a figure nobody can check.
  final String source;

  const ReconciliationRecorded({
    required this.lines,
    required this.commission,
    required this.net,
    required this.source,
  });

  bool get isRecorded => source != 'not_recorded';

  static ReconciliationRecorded fromJson(Map<String, dynamic> json) => ReconciliationRecorded(
        lines: _int(json['lines']),
        commission: _double(json['commission']),
        net: _double(json['net']),
        source: json['source']?.toString() ?? 'not_recorded',
      );
}

class ReconciliationCredited {
  final int entries;
  final double amount;

  const ReconciliationCredited({required this.entries, required this.amount});

  static ReconciliationCredited fromJson(Map<String, dynamic> json) => ReconciliationCredited(
        entries: _int(json['entries']),
        amount: _double(json['amount']),
      );
}

class ReconciliationGap {
  final int count;
  final double amount;
  final List<Map<String, dynamic>> sample;

  const ReconciliationGap({required this.count, required this.amount, required this.sample});

  static ReconciliationGap fromJson(Map<String, dynamic> json) => ReconciliationGap(
        count: _int(json['count']),
        amount: _double(json['amount']),
        sample: (json['sample'] as List?)?.whereType<Map>().map(_map).toList() ??
            const <Map<String, dynamic>>[],
      );
}

/// What the marketplace would charge on a sale that has not happened yet.
class FeeSimulationModel {
  final int quantity;
  final double unitPrice;
  final double discountPerUnit;
  final double gross;
  final double commissionableAmount;
  final double commissionAmount;
  final double sellerReceives;

  /// Null when there is nothing to take a share of. A percentage of nothing is
  /// undefined, not nought per cent, and the screen says so.
  final double? effectiveRatePercent;

  final String? ruleLabel;
  final String? productName;

  /// What the figure does not cover, named by the server.
  final List<String> excludes;

  const FeeSimulationModel({
    required this.quantity,
    required this.unitPrice,
    required this.discountPerUnit,
    required this.gross,
    required this.commissionableAmount,
    required this.commissionAmount,
    required this.sellerReceives,
    required this.excludes,
    this.effectiveRatePercent,
    this.ruleLabel,
    this.productName,
  });

  static FeeSimulationModel fromJson(Map<String, dynamic> json) => FeeSimulationModel(
        quantity: _int(json['quantity']),
        unitPrice: _double(json['unit_price']),
        discountPerUnit: _double(json['discount_per_unit']),
        gross: _double(json['gross']),
        commissionableAmount: _double(json['commissionable_amount']),
        commissionAmount: _double(json['commission_amount']),
        sellerReceives: _double(json['seller_receives']),
        effectiveRatePercent:
            json['effective_rate_percent'] == null ? null : _double(json['effective_rate_percent']),
        ruleLabel: _map(json['rule'])['label']?.toString(),
        productName: json['product'] == null ? null : _map(json['product'])['name']?.toString(),
        excludes: (json['excludes'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[],
      );
}

/// One recorded move of a price or a discount.
class PriceChangeModel {
  final int id;
  final int productId;
  final double? previousPrice;
  final double newPrice;
  final double delta;
  final bool isFirstPrice;
  final String source;
  final String? reason;
  final String? actorName;
  final String? createdAt;

  const PriceChangeModel({
    required this.id,
    required this.productId,
    required this.newPrice,
    required this.delta,
    required this.isFirstPrice,
    required this.source,
    this.previousPrice,
    this.reason,
    this.actorName,
    this.createdAt,
  });

  static PriceChangeModel fromJson(Map<String, dynamic> json) => PriceChangeModel(
        id: _int(json['id']),
        productId: _int(json['product_id']),
        previousPrice: json['previous_price'] == null ? null : _double(json['previous_price']),
        newPrice: _double(json['new_price']),
        delta: _double(json['delta']),
        isFirstPrice: json['is_first_price'] == true,
        source: json['source']?.toString() ?? '',
        reason: json['reason']?.toString(),
        actorName: json['actor_name']?.toString(),
        createdAt: json['created_at']?.toString(),
      );
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _double(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

/// The floor a seller has set under their own prices.
///
/// `productsWithACost` is the honest half of this screen: a margin floor can
/// only speak about products whose cost is recorded, so a seller switching one
/// on needs to know whether it covers their catalogue or a corner of it.
class PricingPolicyModel {
  final double? minMarginPercent;
  final double? minPrice;
  final bool enforce;
  final bool binding;
  final int productsWithACost;
  final int productsTotal;

  const PricingPolicyModel({
    required this.enforce,
    required this.binding,
    required this.productsWithACost,
    required this.productsTotal,
    this.minMarginPercent,
    this.minPrice,
  });

  /// Switched on with nothing in it. Not the same as a floor of zero, and the
  /// screen has to say so rather than showing a reassuring toggle.
  bool get onButEmpty => enforce && !binding;

  /// A margin floor that can speak about none of the catalogue.
  bool get marginCoversNothing => minMarginPercent != null && productsWithACost == 0;

  static PricingPolicyModel fromJson(Map<String, dynamic> json) => PricingPolicyModel(
        minMarginPercent: _double(json['min_margin_percent']),
        minPrice: _double(json['min_price']),
        enforce: json['enforce'] == true,
        binding: json['binding'] == true,
        productsWithACost: _int(json['products_with_a_cost']),
        productsTotal: _int(json['products_total']),
      );

  static double? _double(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

