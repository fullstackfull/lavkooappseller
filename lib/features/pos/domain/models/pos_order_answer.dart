/// What the server answered to a POS sale. It refuses a sale with HTTP 200 and no order number (a product that is not available, a digital product for a walk-in), so the status code alone
/// says nothing about whether a sale was recorded: the answer must name the order. An earlier version took every 200 for a sale, showed "order placed", emptied the cart, opened an invoice
/// of no order, and counted a queued sale the server had refused as synced.
class PosOrderAnswer {
  const PosOrderAnswer._();

  /// Whether the answer says a sale was recorded: it names the order, and it is not one of the refusals that come with a 200.
  static bool isPlaced(dynamic data) {
    if (data is! Map) {
      return false;
    }
    if (data['product_not_available'] == true || data['checkProductTypeForWalkingCustomer'] == true) {
      return false;
    }

    return data['order_id'] != null;
  }

  /// What the server said when it refused the sale, or null when it said nothing.
  static String? refusalMessage(dynamic data) {
    if (data is! Map) {
      return null;
    }
    final dynamic message = data['message'];

    return message is String && message.trim().isNotEmpty ? message.trim() : null;
  }
}
