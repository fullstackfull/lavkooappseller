import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/notification/models/notification_body.dart';
import 'package:syriacosmeticsmanger/notification/notification_route.dart';
import 'package:syriacosmeticsmanger/notification/seller_deep_link.dart';

/// K-11.4: a `lavkooseller://` link opens the screen it names.
///
/// Both stores have had the scheme registered to this app since before the GCC work -- it is in `AndroidManifest.xml` and in `Info.plist` --
/// and nothing in Dart ever read the link, so the operating system handed one over and the app opened at its own front door with the link
/// thrown away. A support reply that said "open order 4242" did nothing at all.
///
/// A link is translated into the payload a push carries, so a link and a push about the same thing go through ONE decision and ONE opener.
/// That is what the last group here pins: whatever the link says, the screen it reaches is the screen a push saying the same thing reaches.
///
/// Three quarters of these tests are about a link this app must NOT act on. A link is typed, forwarded, shortened and pasted by people, so a
/// shape it does not recognise is not a reason to guess -- an order link with no order in it must not open a blank order screen.
void main() {
  NotificationTarget targetOf(String link, {bool signedIn = true}) => NotificationRoute.targetOf(
        SellerDeepLink.payloadOf(Uri.parse(link)),
        signedIn: signedIn,
      );

  NotificationBody? payloadOf(String link) => SellerDeepLink.payloadOf(Uri.parse(link));

  group('a link this app must not act on', () {
    test('a link in anyone else\'s scheme is not ours', () {
      expect(SellerDeepLink.isOurs(Uri.parse('https://lavkoo.com/order/4242')), isFalse);
      expect(payloadOf('https://lavkoo.com/order/4242'), isNull);
      expect(payloadOf('lavkoo://order/4242'), isNull, reason: 'the customer app\'s scheme is not the seller app\'s');
      expect(SellerDeepLink.payloadOf(null), isNull);
    });

    test('a link that names nothing opens nothing', () {
      expect(payloadOf('lavkooseller://'), isNull);
      expect(payloadOf('lavkooseller://somewhere-else'), isNull);
      expect(targetOf('lavkooseller://somewhere-else'), NotificationTarget.none);
    });

    test('an order link with no order in it opens nothing, not a blank order screen', () {
      expect(payloadOf('lavkooseller://order'), isNull);
      expect(payloadOf('lavkooseller://order/not-a-number'), isNull);
      expect(targetOf('lavkooseller://order/'), NotificationTarget.none);
    });

    test('a refund link with no refund in it opens nothing', () {
      expect(payloadOf('lavkooseller://refund'), isNull);
      expect(payloadOf('lavkooseller://refund/x'), isNull);
    });

    test('the flat spelling with an empty or unreadable query opens nothing', () {
      expect(payloadOf('lavkooseller://push'), isNull);
      expect(payloadOf('lavkooseller://push?nothing=useful'), isNull, reason: 'no type and no order is not something to open');
    });

    test('a seller who is signed out is taken nowhere by a link', () {
      expect(
        targetOf('lavkooseller://order/4242', signedIn: false),
        NotificationTarget.none,
        reason: 'every screen a link opens asks the server for the seller\'s data, and with no credential that is a 401 over the login screen',
      );
    });
  });

  group('the named spelling, for a person to send', () {
    test('an order', () {
      final NotificationBody payload = payloadOf('lavkooseller://order/4242')!;

      expect(payload.orderId, 4242);
      expect(targetOf('lavkooseller://order/4242'), NotificationTarget.order);
      expect(NotificationRoute.orderIdOf(payload), 4242);
    });

    test('a refund, with the order line it is about', () {
      final NotificationBody payload = payloadOf('lavkooseller://refund/77?order_details_id=9')!;

      expect(payload.refundId, 77);
      expect(payload.orderDetailsId, 9);
      expect(targetOf('lavkooseller://refund/77?order_details_id=9'), NotificationTarget.refund);
    });

    test('the chat, and the delivery man\'s tab of it', () {
      expect(targetOf('lavkooseller://chat'), NotificationTarget.chat);
      expect(payloadOf('lavkooseller://chat?message_key=message_from_delivery_man')!.messageKey, 'message_from_delivery_man');
    });

    test('the notification list, the wallet and the product requests', () {
      expect(targetOf('lavkooseller://notifications'), NotificationTarget.themeNotifications);
      expect(targetOf('lavkooseller://wallet'), NotificationTarget.wallet);
      expect(targetOf('lavkooseller://product-requests'), NotificationTarget.productRequests);
    });

    test('the name is read in any case, and after a single slash as well as two', () {
      expect(targetOf('lavkooseller://ORDER/4242'), NotificationTarget.order);
      expect(
        payloadOf('lavkooseller:/order/4242')!.orderId,
        4242,
        reason: 'a link is written by hand, and one slash is as likely as two',
      );
      expect(payloadOf('lavkooseller:/Wallet')!.type, 'wallet_withdraw');
    });

    test('the id may be in the query instead of the path', () {
      expect(payloadOf('lavkooseller://order?order_id=4242')!.orderId, 4242);
      expect(payloadOf('lavkooseller://refund?refund_id=77')!.refundId, 77);
    });
  });

  group('the flat spelling, for a machine to write', () {
    test('the query is read exactly as the data of a push is read', () {
      final NotificationBody payload = payloadOf('lavkooseller://push?type=order&order_id=4242&storefront=KW')!;

      expect(payload.orderId, 4242);
      expect(payload.type, 'order');
      expect(payload.storefront, 'KW');
      expect(targetOf('lavkooseller://push?type=order&order_id=4242'), NotificationTarget.order);
    });

    test('a refund in the flat spelling reaches the refund screen', () {
      expect(targetOf('lavkooseller://push?type=refund&refund_id=77&order_details_id=9'), NotificationTarget.refund);
    });

    test('the chat in the flat spelling', () {
      expect(targetOf('lavkooseller://push?type=chatting'), NotificationTarget.chat);
    });
  });

  group('the market a link names', () {
    test('it is read in one case and trimmed, as a push\'s market is', () {
      expect(payloadOf('lavkooseller://order/4242?storefront=kw')!.storefront, 'KW');
      expect(payloadOf('lavkooseller://wallet?storefront=%20bh%20')!.storefront, 'BH');
    });

    test('a link that names no market names none, and is never read as the market in force', () {
      expect(payloadOf('lavkooseller://order/4242')!.storefront, isNull);
      expect(payloadOf('lavkooseller://order/4242?storefront=')!.storefront, isNull);
    });
  });

  group('a link and a push about the same thing reach the same screen', () {
    test('every target a link can name is a target a push can name', () {
      const Map<String, Map<String, dynamic>> sameThing = <String, Map<String, dynamic>>{
        'lavkooseller://order/4242': <String, dynamic>{'order_id': '4242'},
        'lavkooseller://refund/77?order_details_id=9': <String, dynamic>{'type': 'refund', 'refund_id': '77', 'order_details_id': '9'},
        'lavkooseller://chat': <String, dynamic>{'type': 'chatting'},
        'lavkooseller://notifications': <String, dynamic>{'type': 'Theme'},
        'lavkooseller://wallet': <String, dynamic>{'type': 'wallet_withdraw'},
        'lavkooseller://product-requests': <String, dynamic>{'type': 'product_request_approved_message'},
      };

      sameThing.forEach((String link, Map<String, dynamic> pushData) {
        expect(
          targetOf(link),
          NotificationRoute.targetOf(NotificationBody.fromJson(pushData), signedIn: true),
          reason: '$link and the push $pushData must open the same screen',
        );
      });
    });

    test('and no link reaches a screen outside the list a push can reach', () {
      for (final String link in <String>[
        'lavkooseller://order/1',
        'lavkooseller://refund/1',
        'lavkooseller://chat',
        'lavkooseller://notifications',
        'lavkooseller://wallet',
        'lavkooseller://product-requests',
        'lavkooseller://push?type=order&order_id=1',
      ]) {
        expect(targetOf(link), isNot(NotificationTarget.none), reason: '$link names a real screen');
      }
    });
  });
}
