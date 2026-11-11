/// Ledger balances and payout history, as
/// `GET /api/v3/seller/seller-center/payouts` returns them.
class PayoutOverviewModel {
  final double available;
  final double pending;
  final double reserved;
  final double paid;
  final double balance;
  final double withdrawable;
  final bool inCoolingPeriod;
  final bool payoutEligible;
  final List<String> payoutCurrencies;
  final List<PayoutRequestModel> requests;
  final int totalSize;
  final int offset;

  PayoutOverviewModel({
    this.available = 0,
    this.pending = 0,
    this.reserved = 0,
    this.paid = 0,
    this.balance = 0,
    this.withdrawable = 0,
    this.inCoolingPeriod = false,
    this.payoutEligible = true,
    this.payoutCurrencies = const [],
    this.requests = const [],
    this.totalSize = 0,
    this.offset = 1,
  });

  factory PayoutOverviewModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> balances = json['balances'] is Map
        ? Map<String, dynamic>.from(json['balances'])
        : <String, dynamic>{};

    return PayoutOverviewModel(
      available: _toDouble(balances['available']),
      pending: _toDouble(balances['pending']),
      reserved: _toDouble(balances['reserved']),
      paid: _toDouble(balances['paid']),
      balance: _toDouble(balances['balance']),
      withdrawable: _toDouble(json['withdrawable']),
      inCoolingPeriod: json['in_cooling_period'] == true,
      payoutEligible: json['payout_eligible'] != false,
      payoutCurrencies: json['payout_currencies'] != null
          ? List<String>.from(json['payout_currencies'].map((code) => '$code'))
          : const [],
      requests: json['requests'] != null
          ? List<PayoutRequestModel>.from(
              json['requests'].map((request) => PayoutRequestModel.fromJson(request)))
          : const [],
      totalSize: int.tryParse('${json['total_size']}') ?? 0,
      offset: int.tryParse('${json['offset']}') ?? 1,
    );
  }
}

class PayoutRequestModel {
  final int? id;
  final String? reference;
  final double amount;
  final String? currency;
  final String status;
  final String? method;
  final String? createdAt;

  PayoutRequestModel({
    this.id,
    this.reference,
    this.amount = 0,
    this.currency,
    this.status = 'requested',
    this.method,
    this.createdAt,
  });

  factory PayoutRequestModel.fromJson(Map<String, dynamic> json) {
    return PayoutRequestModel(
      id: int.tryParse('${json['id']}'),
      reference: json['reference'],
      amount: _toDouble(json['amount']),
      currency: json['currency'],
      status: json['status'] ?? 'requested',
      method: json['method'],
      createdAt: json['created_at'],
    );
  }

  /// Mirrors VendorPayoutRequest::OPEN_STATUSES — only an open request can be cancelled.
  bool get isOpen => const ['requested', 'under_review', 'approved', 'processing'].contains(status);
}

double _toDouble(dynamic value) => double.tryParse('$value') ?? 0;
