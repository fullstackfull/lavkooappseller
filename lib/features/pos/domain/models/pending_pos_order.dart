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

  const PendingPosOrder({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.orderAmount,
    required this.customerName,
    this.attempts = 0,
    this.lastError,
  });

  PendingPosOrder copyWith({int? attempts, String? lastError}) => PendingPosOrder(
        id: id,
        body: body,
        createdAt: createdAt,
        orderAmount: orderAmount,
        customerName: customerName,
        attempts: attempts ?? this.attempts,
        lastError: lastError ?? this.lastError,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'body': body,
        'created_at': createdAt.toIso8601String(),
        'order_amount': orderAmount,
        'customer_name': customerName,
        'attempts': attempts,
        'last_error': lastError,
      };

  factory PendingPosOrder.fromJson(Map<String, dynamic> json) => PendingPosOrder(
        id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        body: Map<String, dynamic>.from(json['body'] as Map? ?? <String, dynamic>{}),
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
        orderAmount: double.tryParse(json['order_amount']?.toString() ?? '') ?? 0,
        customerName: json['customer_name']?.toString() ?? '',
        attempts: int.tryParse(json['attempts']?.toString() ?? '') ?? 0,
        lastError: json['last_error']?.toString(),
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
