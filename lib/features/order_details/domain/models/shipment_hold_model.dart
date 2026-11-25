/// Why one shipment of an order has not left (H1-04, H1-06).
///
/// A shipment can be held for something the seller can act on -- a product with no permission to reach the order's destination, a
/// regulated product with no licence on file, an address no carrier serves. The server answers the reason already in the language the
/// request asked for, so there is nothing here to translate and no key to keep in step: a reason added on the server reaches the seller
/// without another release.
///
/// `reason` can be null, for a hold the server recorded without one. Null means the screen says the shipment is held and does not invent a
/// cause, which is better than a sentence nobody wrote.
class ShipmentHoldModel {
  final int? id;
  final String? reasonCode;
  final String? reason;
  final String? heldAt;

  const ShipmentHoldModel({this.id, this.reasonCode, this.reason, this.heldAt});

  factory ShipmentHoldModel.fromJson(Map<String, dynamic> json) => ShipmentHoldModel(
        id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}'),
        reasonCode: _text(json['reason_code']),
        reason: _text(json['reason']),
        heldAt: _text(json['held_at']),
      );

  /// A list of holds out of the server's answer, dropping anything that is not a map. Never throws, whatever the body is.
  static List<ShipmentHoldModel> listFrom(Object? body) {
    final Object? holds = body is Map ? body['holds'] : null;

    if (holds is! List) {
      return const <ShipmentHoldModel>[];
    }

    return holds
        .whereType<Map>()
        .map((Map entry) => ShipmentHoldModel.fromJson(Map<String, dynamic>.from(entry)))
        .toList();
  }

  static String? _text(Object? value) {
    final String text = value == null ? '' : '$value'.trim();

    return text.isEmpty ? null : text;
  }
}
