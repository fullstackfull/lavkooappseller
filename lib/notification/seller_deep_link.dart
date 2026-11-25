import 'package:syriacosmeticsmanger/notification/models/notification_body.dart';

/// A `lavkooseller://` link, turned into the same payload a push notification carries (K-11).
///
/// Both app stores have been told this app owns the scheme since before the GCC work -- it is declared in `AndroidManifest.xml` and in
/// `Info.plist` -- but nothing in Dart ever read the link, so every one of them opened the app at its own front door and the link itself was
/// thrown away. A support reply or an email that says "open order 4242" did nothing.
///
/// A link is translated into a [NotificationBody] rather than routed on its own, so a link and a push about the same thing go through ONE
/// decision ([NotificationRoute]) and ONE opener. Two routers would drift: a screen added to the push path would quietly stay missing from the
/// link path, and nobody would notice until a seller followed a link.
///
/// **A link that this cannot place answers null, and null opens nothing.** A link is typed, forwarded, shortened and pasted by people and
/// arrives from outside the app, so a shape this does not recognise is not a reason to guess: a `lavkooseller://order` with no order in it must
/// not open a blank order screen, and a link in anyone else's scheme is not ours to act on at all.
///
/// Two spellings are accepted, because they are written by different authors:
///
///  * a named one for a person to read and send -- `lavkooseller://order/4242`, `lavkooseller://refund/77?order_details_id=9`,
///    `lavkooseller://chat`, `lavkooseller://notifications`, `lavkooseller://wallet`, `lavkooseller://product-requests`;
///  * a flat one for a machine -- `lavkooseller://push?type=order&order_id=4242`, whose query is read exactly as push data is read, so a server
///    that already knows how to fill a push payload can write a link without learning a second grammar.
///
/// Any of them may name a market with `?storefront=KW`, and it is read the same way a push's market is read: the opener asks
/// [NotificationMarket] what to do about it, and a market the seller is not granted opens nothing.
class SellerDeepLink {
  const SellerDeepLink._();

  /// The scheme both app stores have registered to this app.
  static const String scheme = 'lavkooseller';

  static const String _orderHost = 'order';
  static const String _refundHost = 'refund';
  static const String _chatHost = 'chat';
  static const String _notificationsHost = 'notifications';
  static const String _walletHost = 'wallet';
  static const String _productRequestsHost = 'product-requests';
  static const String _flatHost = 'push';

  /// Whether [link] is in this app's scheme. A link in any other scheme is not ours and is never acted on.
  static bool isOurs(Uri? link) => link != null && link.scheme.toLowerCase() == scheme;

  /// The push payload [link] stands for, or null when it is not ours or names nothing this app can open.
  static NotificationBody? payloadOf(Uri? link) {
    if (!isOurs(link)) {
      return null;
    }

    final Uri uri = link!;
    // `lavkooseller://order/4242` puts `order` in the host and `lavkooseller:/order/4242` puts it in the path. Both are written by hand, so
    // both are read.
    final List<String> segments = <String>[
      if (uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments.where((String segment) => segment.isNotEmpty),
    ];

    if (segments.isEmpty) {
      return null;
    }

    final Map<String, String> query = uri.queryParameters;
    final String target = segments.first.toLowerCase();
    final String? id = segments.length > 1 ? segments[1] : null;

    return switch (target) {
      _flatHost => _fromQuery(query),
      _orderHost => _withMarket(_order(id ?? query['order_id']), query),
      _refundHost => _withMarket(_refund(id ?? query['refund_id'], query['order_details_id']), query),
      _chatHost => _withMarket(NotificationBody(type: 'chatting', messageKey: query['message_key']), query),
      _notificationsHost => _withMarket(NotificationBody(type: 'Theme'), query),
      _walletHost => _withMarket(NotificationBody(type: 'wallet_withdraw'), query),
      _productRequestsHost => _withMarket(NotificationBody(type: 'product_request_approved_message'), query),
      _ => null,
    };
  }

  /// The flat spelling: the query is read exactly as the data of a push is read, so one filler serves both.
  static NotificationBody? _fromQuery(Map<String, String> query) {
    if (query.isEmpty) {
      return null;
    }

    final NotificationBody payload = NotificationBody.fromJson(Map<String, dynamic>.of(query));

    return payload.type == null && payload.orderId == null ? null : payload;
  }

  /// An order link with no order in it opens nothing rather than a blank order screen.
  static NotificationBody? _order(String? id) {
    final int? orderId = int.tryParse(id ?? '');

    return orderId == null ? null : NotificationBody(orderId: orderId);
  }

  static NotificationBody? _refund(String? id, String? orderDetailsId) {
    final int? refundId = int.tryParse(id ?? '');

    return refundId == null
        ? null
        : NotificationBody(type: 'refund', refundId: refundId, orderDetailsId: int.tryParse(orderDetailsId ?? ''));
  }

  /// The market a link names, read in one case as a push's market is, and left alone when it names none.
  static NotificationBody? _withMarket(NotificationBody? payload, Map<String, String> query) {
    final String market = (query['storefront'] ?? '').trim();

    if (payload != null && market.isNotEmpty) {
      payload.storefront = market.toUpperCase();
    }

    return payload;
  }
}
