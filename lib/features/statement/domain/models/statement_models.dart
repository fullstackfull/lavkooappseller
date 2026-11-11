/// One line in the seller's account.
///
/// `balanceAfter` is what the ledger recorded when it wrote the line, not a
/// figure the app adds up. That distinction matters: a running balance
/// recomputed from a filtered list would be a prettier number that never
/// existed.
class StatementEntryModel {
  final int id;
  final String entryType;
  final double credit;
  final double debit;
  final double balanceAfter;
  final String? status;
  final String? availableAt;
  final String? description;

  /// Backwards: the order that earned it.
  final int? orderId;

  /// Forwards: what took it out.
  final String? payoutReference;
  final String? settlementReference;

  final String? createdAt;

  const StatementEntryModel({
    required this.id,
    this.entryType = '',
    this.credit = 0,
    this.debit = 0,
    this.balanceAfter = 0,
    this.status,
    this.availableAt,
    this.description,
    this.orderId,
    this.payoutReference,
    this.settlementReference,
    this.createdAt,
  });

  factory StatementEntryModel.fromJson(Map<String, dynamic> json) => StatementEntryModel(
        id: _int(json['id']) ?? 0,
        entryType: json['entry_type']?.toString() ?? '',
        credit: _double(json['credit']) ?? 0,
        debit: _double(json['debit']) ?? 0,
        balanceAfter: _double(json['balance_after']) ?? 0,
        status: json['status']?.toString(),
        availableAt: json['available_at']?.toString(),
        description: json['description']?.toString(),
        orderId: _int(json['order_id']),
        payoutReference: json['payout_reference']?.toString(),
        settlementReference: json['settlement_reference']?.toString(),
        createdAt: json['created_at']?.toString(),
      );

  bool get isCredit => credit > 0;

  /// Money still inside the return window: recorded, but not yet drawable.
  bool get isPending => status == 'pending';

  static int? _int(dynamic value) => value is int ? value : int.tryParse(value?.toString() ?? '');

  static double? _double(dynamic value) =>
      value == null ? null : (value is num ? value.toDouble() : double.tryParse(value.toString()));
}

/// What the filtered range adds up to, and what the account holds.
///
/// The two are deliberately different scopes: the range follows the filter, the
/// buckets never do. "Available, of last week's entries" is not a number anyone
/// wants to read.
class StatementSummaryModel {
  final String? currency;
  final int rangeEntries;
  final double rangeCredits;
  final double rangeDebits;
  final double rangeNet;

  final double pending;
  final double available;
  final double reserved;
  final double paid;
  final double balance;
  final double withdrawable;

  const StatementSummaryModel({
    this.currency,
    this.rangeEntries = 0,
    this.rangeCredits = 0,
    this.rangeDebits = 0,
    this.rangeNet = 0,
    this.pending = 0,
    this.available = 0,
    this.reserved = 0,
    this.paid = 0,
    this.balance = 0,
    this.withdrawable = 0,
  });

  factory StatementSummaryModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> range =
        json['range'] is Map ? Map<String, dynamic>.from(json['range'] as Map) : <String, dynamic>{};
    final Map<String, dynamic> buckets =
        json['buckets'] is Map ? Map<String, dynamic>.from(json['buckets'] as Map) : <String, dynamic>{};

    return StatementSummaryModel(
      currency: json['currency']?.toString(),
      rangeEntries: StatementEntryModel._int(range['entries']) ?? 0,
      rangeCredits: StatementEntryModel._double(range['credits']) ?? 0,
      rangeDebits: StatementEntryModel._double(range['debits']) ?? 0,
      rangeNet: StatementEntryModel._double(range['net']) ?? 0,
      pending: StatementEntryModel._double(buckets['pending']) ?? 0,
      available: StatementEntryModel._double(buckets['available']) ?? 0,
      reserved: StatementEntryModel._double(buckets['reserved']) ?? 0,
      paid: StatementEntryModel._double(buckets['paid']) ?? 0,
      balance: StatementEntryModel._double(buckets['balance']) ?? 0,
      withdrawable: StatementEntryModel._double(json['withdrawable']) ?? 0,
    );
  }
}

class StatementModel {
  final int totalSize;
  final List<String> entryTypes;
  final List<String> statuses;
  final StatementSummaryModel summary;
  final List<StatementEntryModel> entries;

  const StatementModel({
    this.totalSize = 0,
    this.entryTypes = const <String>[],
    this.statuses = const <String>[],
    this.summary = const StatementSummaryModel(),
    this.entries = const <StatementEntryModel>[],
  });

  factory StatementModel.fromJson(Map<String, dynamic> json) => StatementModel(
        totalSize: StatementEntryModel._int(json['total_size']) ?? 0,
        entryTypes: _strings(json['entry_types']),
        statuses: _strings(json['statuses']),
        summary: json['summary'] is Map
            ? StatementSummaryModel.fromJson(Map<String, dynamic>.from(json['summary'] as Map))
            : const StatementSummaryModel(),
        entries: json['entries'] is List
            ? (json['entries'] as List)
                .whereType<Map>()
                .map((row) => StatementEntryModel.fromJson(Map<String, dynamic>.from(row)))
                .toList()
            : const <StatementEntryModel>[],
      );

  static List<String> _strings(dynamic value) => value is List
      ? List<String>.from(value.map((entry) => entry.toString()))
      : const <String>[];
}
