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

  /// The seller who took the sale. The server records a replayed sale under the seller of the session that sends it, so only this seller's session may send it. A sale taken while the app did not
  /// know who was signed in is given its seller as soon as the app learns it, in the session that rang it up. A sale that names none (an earlier version's, or one whose session ended before the
  /// app learned who it was) is sent only by the session that rang it up, never by a later one: nothing on the device says which seller took it.
  final String? sellerId;

  /// The storefront the sale was taken in: the code the first request of the sale named, which is the market the seller worked in when the sale was queued. The replay names it itself, so a seller
  /// who has switched market since does not book the sale in the new one. A sale queued while storefronts were off, or by an earlier version, names none and is replayed under the market the seller
  /// works in when it is sent, as every sale was before; with storefronts off the entry is written exactly as it always was.
  final String? storefront;

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
    this.storefront,
  });

  /// Whether this sale names the seller who is signed in (null while the app does not know). A sale that names no seller belongs to none by name: whose session may send it is for the outbox to say.
  bool belongsTo(String? signedInSellerId) => sellerId != null && sellerId == signedInSellerId;

  PendingPosOrder copyWith({int? attempts, String? lastError, String? idempotencyKey, String? sellerId}) => PendingPosOrder(
        id: id,
        body: body,
        createdAt: createdAt,
        orderAmount: orderAmount,
        customerName: customerName,
        attempts: attempts ?? this.attempts,
        lastError: lastError ?? this.lastError,
        idempotencyKey: idempotencyKey ?? this.idempotencyKey,
        sellerId: sellerId ?? this.sellerId,
        storefront: storefront,
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
        if (storefront != null) 'storefront': storefront,
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
        storefront: json['storefront']?.toString(),
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
