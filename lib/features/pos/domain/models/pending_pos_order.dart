import 'dart:convert';

/// A POS sale that was rung up while the device could not reach the server.
///
/// The order body is kept exactly as it would have been posted, so replaying it
/// later is a byte-for-byte retry rather than a reconstruction.
class PendingPosOrder {
  final String id;
  final Map<String, dynamic> body;
  final DateTime createdAt;
  final double orderAmount;
  final String customerName;
  final int attempts;
  final String? lastError;

  /// The key the sale was first sent with (PosIdempotencyKey): a replay sends the same one. A sale that an earlier version queued has none until its first replay.
  final String? idempotencyKey;

  /// The seller who took the sale. The server records a replayed sale under the seller of the session that sends it, so only this seller's session may send it. A sale that an earlier version
  /// queued, or one taken while the app did not know who was signed in, has no owner: it is sent under whoever is signed in, as every sale was before.
  final String? sellerId;

  const PendingPosOrder({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.orderAmount,
    required this.customerName,
    this.attempts = 0,
    this.lastError,
    this.idempotencyKey,
    this.sellerId,
  });

  /// Whether the seller who is signed in (null while the app does not know) may list, send, retry and remove this sale.
  bool belongsTo(String? signedInSellerId) => sellerId == null || sellerId == signedInSellerId;

  PendingPosOrder copyWith({int? attempts, String? lastError, String? idempotencyKey}) => PendingPosOrder(
        id: id,
        body: body,
        createdAt: createdAt,
        orderAmount: orderAmount,
        customerName: customerName,
        attempts: attempts ?? this.attempts,
        lastError: lastError ?? this.lastError,
        idempotencyKey: idempotencyKey ?? this.idempotencyKey,
        sellerId: sellerId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'body': body,
        'created_at': createdAt.toIso8601String(),
        'order_amount': orderAmount,
        'customer_name': customerName,
        'attempts': attempts,
        'last_error': lastError,
        'idempotency_key': idempotencyKey,
        'seller_id': sellerId,
      };

  factory PendingPosOrder.fromJson(Map<String, dynamic> json) => PendingPosOrder(
        id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        body: Map<String, dynamic>.from(json['body'] as Map? ?? <String, dynamic>{}),
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
        orderAmount: double.tryParse(json['order_amount']?.toString() ?? '') ?? 0,
        customerName: json['customer_name']?.toString() ?? '',
        attempts: int.tryParse(json['attempts']?.toString() ?? '') ?? 0,
        lastError: json['last_error']?.toString(),
        idempotencyKey: json['idempotency_key']?.toString(),
        sellerId: json['seller_id']?.toString(),
      );

  String encode() => jsonEncode(toJson());

  static PendingPosOrder? decode(String raw) {
    try {
      return PendingPosOrder.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
