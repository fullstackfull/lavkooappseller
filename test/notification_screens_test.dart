import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/chat/screens/inbox_screen.dart';
import 'package:syriacosmeticsmanger/features/notification/screens/notification_screen.dart';
import 'package:syriacosmeticsmanger/features/order_details/screens/order_details_screen.dart';
import 'package:syriacosmeticsmanger/features/product/screens/product_list_screen.dart';
import 'package:syriacosmeticsmanger/features/refund/screens/refund_details_screen.dart';
import 'package:syriacosmeticsmanger/features/wallet/screens/wallet_screen.dart';
import 'package:syriacosmeticsmanger/notification/models/notification_body.dart';
import 'package:syriacosmeticsmanger/notification/notification_screens.dart';
import 'package:syriacosmeticsmanger/notification/seller_deep_link.dart';

/// K-11: ONE list of the screens a notification opens, asked by the opener used while the app is running and by the splash that opens a
/// notification which started the app.
///
/// There were two lists and they disagreed. The splash switched on the type alone, so:
///
///  * an order notice carrying an order number and no type -- which is most of them -- opened the notification LIST on a cold start and the
///    ORDER when the app was already running;
///  * an order notice with a type and no number ran `int.parse('null')` and threw inside the splash's callback.
///
/// Both are pinned below. The widgets are constructed and their type checked rather than pumped: what is at stake is which screen a payload
/// chooses, and a screen that fetches on build would need the whole app behind it to answer that.
void main() {
  Widget? screenOf(Map<String, dynamic> data, {bool signedIn = true}) =>
      NotificationScreens.of(NotificationBody.fromJson(data), signedIn: signedIn);

  group('the two cold-start bugs', () {
    test('an order notice with an order number and no type opens the order', () {
      expect(
        screenOf(<String, dynamic>{'order_id': '4242'}),
        isA<OrderDetailsScreen>(),
        reason: 'the splash used to open the notification list for this, and most order notices look like this',
      );
    });

    test('an order notice with a type and no number opens nothing and does not throw', () {
      expect(
        () => screenOf(<String, dynamic>{'type': 'order'}),
        returnsNormally,
        reason: "the splash used to run int.parse on the word 'null'",
      );
      expect(screenOf(<String, dynamic>{'type': 'order'}), isNull);
    });
  });

  group('every target has one screen', () {
    test('each type reaches its own screen', () {
      expect(screenOf(<String, dynamic>{'type': 'chatting'}), isA<InboxScreen>());
      expect(screenOf(<String, dynamic>{'type': 'Theme'}), isA<NotificationScreen>());
      expect(screenOf(<String, dynamic>{'type': 'wallet_withdraw'}), isA<WalletScreen>());
      expect(screenOf(<String, dynamic>{'type': 'product_request_approved_message'}), isA<ProductListMenuScreen>());
      expect(screenOf(<String, dynamic>{'type': 'refund', 'refund_id': '7'}), isA<RefundDetailsScreen>());
      expect(screenOf(<String, dynamic>{'order_id': '9'}), isA<OrderDetailsScreen>());
    });

    test('a payload that names nothing, and a seller who is signed out, open no screen', () {
      expect(screenOf(<String, dynamic>{}), isNull);
      expect(screenOf(<String, dynamic>{'type': 'something-this-build-never-heard-of'}), isNull);
      expect(screenOf(<String, dynamic>{'order_id': '4242'}, signedIn: false), isNull);
      expect(NotificationScreens.of(null, signedIn: true), isNull);
    });

    test('the order number an older server puts in the title key is read when the data names none', () {
      expect(NotificationScreens.of(null, signedIn: true, legacyOrderKey: '4242'), isA<OrderDetailsScreen>());
    });
  });

  group('a link reaches the same screen as the push that says the same thing', () {
    test('every lavkooseller:// link lands on the screen its push lands on', () {
      const Map<String, Map<String, dynamic>> sameThing = <String, Map<String, dynamic>>{
        'lavkooseller://order/4242': <String, dynamic>{'order_id': '4242'},
        'lavkooseller://refund/77': <String, dynamic>{'type': 'refund', 'refund_id': '77'},
        'lavkooseller://chat': <String, dynamic>{'type': 'chatting'},
        'lavkooseller://notifications': <String, dynamic>{'type': 'Theme'},
        'lavkooseller://wallet': <String, dynamic>{'type': 'wallet_withdraw'},
        'lavkooseller://product-requests': <String, dynamic>{'type': 'product_request_approved_message'},
      };

      sameThing.forEach((String link, Map<String, dynamic> pushData) {
        final Widget? fromLink = NotificationScreens.of(SellerDeepLink.payloadOf(Uri.parse(link)), signedIn: true);
        final Widget? fromPush = screenOf(pushData);

        expect(fromLink, isNotNull, reason: '$link opens nothing');
        expect(fromPush, isNotNull, reason: 'the push $pushData opens nothing');
        expect(
          fromLink!.runtimeType,
          fromPush!.runtimeType,
          reason: '$link and the push $pushData must open the same screen',
        );
      });
    });
  });
}
