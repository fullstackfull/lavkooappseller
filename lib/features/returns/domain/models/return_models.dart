/// One lot of goods coming back.
///
/// `restock` is a decision, not a property of the return: whether what arrives
/// can be sold again is only knowable once someone opens the box, so it is set
/// at receipt rather than trusted from when the return was opened.
class ReturnShipmentModel {
  final int id;
  final String? reference;
  final String status;
  final int? productId;
  final String? productName;
  final int qty;
  final String? reason;
  final bool restock;
  final bool isOpen;
  final String? receivedAt;
  final String? createdAt;

  final String? carrier;
  final String? trackingNumber;
  final String? note;
  final int? orderId;
  final int? refundRequestId;

  const ReturnShipmentModel({
    required this.id,
    this.reference,
    this.status = '',
    this.productId,
    this.productName,
    this.qty = 0,
    this.reason,
    this.restock = true,
    this.isOpen = false,
    this.receivedAt,
    this.createdAt,
    this.carrier,
    this.trackingNumber,
    this.note,
    this.orderId,
    this.refundRequestId,
  });

  factory ReturnShipmentModel.fromJson(Map<String, dynamic> json) => ReturnShipmentModel(
        id: _int(json['id']) ?? 0,
        reference: json['reference']?.toString(),
        status: json['status']?.toString() ?? '',
        productId: _int(json['product_id']),
        productName: json['product_name']?.toString(),
        qty: _int(json['qty']) ?? 0,
        reason: json['reason']?.toString(),
        restock: json['restock'] != false,
        isOpen: json['is_open'] == true,
        receivedAt: json['received_at']?.toString(),
        createdAt: json['created_at']?.toString(),
        carrier: json['carrier']?.toString(),
        trackingNumber: json['tracking_number']?.toString(),
        note: json['note']?.toString(),
        orderId: _int(json['order_id']),
        refundRequestId: _int(json['refund_request_id']),
      );

  bool get isAuthorized => status == 'authorized';
  bool get isRestocked => status == 'restocked';

  static int? _int(dynamic value) => value is int ? value : int.tryParse(value?.toString() ?? '');

  static double? _double(dynamic value) =>
      value == null ? null : (value is num ? value.toDouble() : double.tryParse(value.toString()));
}

class ReturnListModel {
  final int totalSize;
  final List<String> statuses;
  final List<ReturnShipmentModel> returns;

  const ReturnListModel({
    this.totalSize = 0,
    this.statuses = const <String>[],
    this.returns = const <ReturnShipmentModel>[],
  });

  factory ReturnListModel.fromJson(Map<String, dynamic> json) => ReturnListModel(
        totalSize: ReturnShipmentModel._int(json['total_size']) ?? 0,
        statuses: json['statuses'] is List
            ? List<String>.from((json['statuses'] as List).map((entry) => entry.toString()))
            : const <String>[],
        returns: json['returns'] is List
            ? (json['returns'] as List)
                .whereType<Map>()
                .map((row) => ReturnShipmentModel.fromJson(Map<String, dynamic>.from(row)))
                .toList()
            : const <ReturnShipmentModel>[],
      );
}

/// What the refund behind a return did to the seller's balance.
///
/// The commission credit is the line sellers never see and most doubt exists:
/// without it a refund leaves the marketplace's cut of a sale it gave back still
/// charged.
class ReturnLedgerEntryModel {
  final String entryType;
  final double credit;
  final double debit;
  final String? status;
  final String? description;
  final String? createdAt;

  const ReturnLedgerEntryModel({
    required this.entryType,
    this.credit = 0,
    this.debit = 0,
    this.status,
    this.description,
    this.createdAt,
  });

  factory ReturnLedgerEntryModel.fromJson(Map<String, dynamic> json) => ReturnLedgerEntryModel(
        entryType: json['entry_type']?.toString() ?? '',
        credit: ReturnShipmentModel._double(json['credit']) ?? 0,
        debit: ReturnShipmentModel._double(json['debit']) ?? 0,
        status: json['status']?.toString(),
        description: json['description']?.toString(),
        createdAt: json['created_at']?.toString(),
      );

  bool get isCredit => credit > 0;
}
