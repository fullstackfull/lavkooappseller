

class NotificationBody {
  int? orderId;
  int? orderDetailsId;
  int? refundId;
  String? type;
  String? messageKey;

  /// The GCC market the order this push is about was sold in, as the server names it (K-11).
  ///
  /// Null when the server sent none: an older server, a push about something that is not an order, or a platform with storefronts off. Null
  /// is never read as "the market I am looking at" -- `NotificationMarket` decides what to do with it, and with no market it does nothing.
  String? storefront;

  NotificationBody({
    this.orderId,
    this.orderDetailsId,
    this.refundId,
    this.type,
    this.messageKey,
    this.storefront,
  });

  NotificationBody.fromJson(Map<String, dynamic> json) {
    if(json['order_id'] != null && json['order_id'] != ''){
      orderId = int.tryParse(json['order_id'].toString());
    }
    if(json['order_details_id'] != null && json['order_details_id'] != ''){
      orderDetailsId = int.tryParse(json['order_details_id'].toString());
    }
    type = json['type'];
    messageKey = json['message_key'];
    if(json['refund_id'] != null && json['refund_id'] != ''){
      refundId = int.tryParse(json['refund_id'].toString());
    }
    final Object? market = json['storefront'];
    if (market is String && market.trim().isNotEmpty) {
      storefront = market.trim().toUpperCase();
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['order_id'] = orderId;
    data['order_details_id'] = orderDetailsId;
    data['refund_id'] = refundId;
    data['type'] = type;
    data['message_key'] = messageKey;
    data['storefront'] = storefront;
    return data;
  }


}