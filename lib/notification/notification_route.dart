import 'package:syriacosmeticsmanger/notification/models/notification_body.dart';

enum NotificationTarget { chat, themeNotifications, order, wallet, productRequests, refund, none }

/// Where a push notification opens, decided by what the server put in the data of the message (its type and its numbers) and never by the words of its title.
///
/// The title is written in the language of the seller. An earlier version opened an order only when the title contained the English word Order, so a seller who reads Arabic tapped a new order
/// and nothing opened. A message with no notification part at all (the app is opened from a data message) made the same handler fail before it looked at the data.
class NotificationRoute {
  const NotificationRoute._();

  static const String chatType = 'chatting';
  static const String themeType = 'Theme';
  static const String refundType = 'refund';
  static const String walletWithdrawType = 'wallet_withdraw';
  static const String productRequestApprovedType = 'product_request_approved_message';

  /// The screen a notification opens. The order of the checks is the order the tap of a local notification always had: an order number opens the order unless the message is about a refund.
  ///
  /// [legacyOrderKey] is the order number that an older server also puts in the title key of the notification part; it is read only when the data names no order.
  static NotificationTarget targetOf(NotificationBody? payload, {String? legacyOrderKey}) {
    final String? type = payload?.type;

    if (type == chatType) {
      return NotificationTarget.chat;
    }
    if (type == themeType) {
      return NotificationTarget.themeNotifications;
    }
    if (payload?.orderId != null && type != refundType) {
      return NotificationTarget.order;
    }
    if (type == walletWithdrawType) {
      return NotificationTarget.wallet;
    }
    if (type == productRequestApprovedType) {
      return NotificationTarget.productRequests;
    }
    if (type == refundType) {
      return NotificationTarget.refund;
    }
    if (_legacyOrderId(legacyOrderKey) != null) {
      return NotificationTarget.order;
    }

    return NotificationTarget.none;
  }

  /// The order an order notification opens: the one the data names, else the one an older server put in the title key.
  static int? orderIdOf(NotificationBody? payload, {String? legacyOrderKey}) => payload?.orderId ?? _legacyOrderId(legacyOrderKey);

  static int? _legacyOrderId(String? legacyOrderKey) => int.tryParse(legacyOrderKey ?? '');
}
