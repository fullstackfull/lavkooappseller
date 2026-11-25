import 'package:syriacosmeticsmanger/data/model/currency_figures.dart';

/// Ledger balances and payout history, as
/// `GET /api/v3/seller/seller-center/payouts` returns them.
///
/// **Every combined figure is nullable, and null is not zero.** Where the ledger holds two currencies the server refuses the
/// single total -- a sum of riyals and dirhams is not money -- and answers each currency's own figures beside a reason
/// (`SellerPayoutController::balances`). These were read as `value ?? 0`, so a seller holding money in two currencies was shown
/// **withdrawable 0.00** with nothing to say why; a zero looks authoritative where a blank does not, and on THIS screen the
/// figure is also the ceiling the seller asks for money against. The types carry the distinction now, so a reader has to decide
/// what to draw.
class PayoutOverviewModel {
  final double? available;
  final double? pending;
  final double? reserved;
  final double? paid;
  final double? balance;
  final double? withdrawable;
  final bool inCoolingPeriod;
  final bool payoutEligible;
  final List<String> payoutCurrencies;

  /// The account's buckets in each currency it holds. Empty while there is one currency, which is when the combined figures
  /// above are the answer.
  final List<CurrencyFiguresModel> balancesByCurrency;

  /// Why there is no one figure, as a language key, or null when there is one.
  final String? totalsRefusedBecause;

  final List<PayoutRequestModel> requests;
  final int totalSize;
  final int offset;

  PayoutOverviewModel({
    this.available,
    this.pending,
    this.reserved,
    this.paid,
    this.balance,
    this.withdrawable,
    this.inCoolingPeriod = false,
    this.payoutEligible = true,
    this.payoutCurrencies = const [],
    this.balancesByCurrency = const <CurrencyFiguresModel>[],
    this.totalsRefusedBecause,
    this.requests = const [],
    this.totalSize = 0,
    this.offset = 1,
  });

  /// Whether the server declined to produce one figure, so the per-currency groups are what there is to show.
  bool get totalsRefused => totalsRefusedBecause != null;

  /// Whether there is a withdrawable figure to ask for money against at all. A refusal is not a zero ceiling and not an
  /// unlimited one: there is no ceiling, so there is nothing to ask against until the account holds one currency again.
  bool get hasWithdrawableFigure => !totalsRefused && withdrawable != null;

  factory PayoutOverviewModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> balances = json['balances'] is Map
        ? Map<String, dynamic>.from(json['balances'])
        : <String, dynamic>{};

    return PayoutOverviewModel(
      available: _toDoubleOrNull(balances['available']),
      pending: _toDoubleOrNull(balances['pending']),
      reserved: _toDoubleOrNull(balances['reserved']),
      paid: _toDoubleOrNull(balances['paid']),
      balance: _toDoubleOrNull(balances['balance']),
      withdrawable: _toDoubleOrNull(json['withdrawable']),
      inCoolingPeriod: json['in_cooling_period'] == true,
      payoutEligible: json['payout_eligible'] != false,
      payoutCurrencies: json['payout_currencies'] != null
          ? List<String>.from(json['payout_currencies'].map((code) => '$code'))
          : const [],
      balancesByCurrency: CurrencyFiguresModel.listFrom(json['balances_by_currency']),
      totalsRefusedBecause: json['totals_refused_because']?.toString(),
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

/// A figure the answer carries, or null where it carries none. Never 0 for an absent figure: a refused total and a
/// balance of nothing are different things, and only one of them is a number a seller can act on.
double? _toDoubleOrNull(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value');
