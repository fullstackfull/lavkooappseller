import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/notification/models/notification_body.dart';
import 'package:syriacosmeticsmanger/notification/notification_route.dart';

NotificationBody _payload(Map<String, dynamic> data) => NotificationBody.fromJson(data);

/// K-11: a push notification opens the screen the server's data names. Its title is written in the language of the seller, so a test of the English word Order in it opened nothing for a seller who
/// reads Arabic, and a message without a notification part made the handler fail before it looked at the data.
void main() {
  group('what a notification opens, from its data only', () {
    test('an order opens the order whatever language the title of the message is in', () {
      // The title is not part of the data the route reads; this is the data of an Arabic message, whose title was never looked at.
      final NotificationBody arabic = _payload(<String, dynamic>{'order_id': '1234', 'type': 'order', 'title': 'طلب جديد'});
      final NotificationBody english = _payload(<String, dynamic>{'order_id': '1234', 'type': 'order', 'title': 'New Order'});

      expect(NotificationRoute.targetOf(arabic, signedIn: true), NotificationTarget.order);
      expect(NotificationRoute.targetOf(english, signedIn: true), NotificationTarget.order);
      expect(NotificationRoute.orderIdOf(arabic), 1234);
    });

    test('each type the server sends opens its own screen', () {
      expect(NotificationRoute.targetOf(_payload(<String, dynamic>{'type': 'chatting', 'message_key': 'message_from_customer'}), signedIn: true), NotificationTarget.chat);
      expect(NotificationRoute.targetOf(_payload(<String, dynamic>{'type': 'Theme'}), signedIn: true), NotificationTarget.themeNotifications);
      expect(NotificationRoute.targetOf(_payload(<String, dynamic>{'type': 'wallet_withdraw'}), signedIn: true), NotificationTarget.wallet);
      expect(NotificationRoute.targetOf(_payload(<String, dynamic>{'type': 'product_request_approved_message'}), signedIn: true), NotificationTarget.productRequests);
      expect(NotificationRoute.targetOf(_payload(<String, dynamic>{'type': 'refund', 'refund_id': '7', 'order_details_id': '9'}), signedIn: true), NotificationTarget.refund);
    });

    test('a refund that names its order opens the refund and not the order, and a chat that names an order opens the chat', () {
      expect(NotificationRoute.targetOf(_payload(<String, dynamic>{'type': 'refund', 'order_id': '55', 'refund_id': '7'}), signedIn: true), NotificationTarget.refund);
      expect(NotificationRoute.targetOf(_payload(<String, dynamic>{'type': 'chatting', 'order_id': '55'}), signedIn: true), NotificationTarget.chat);
    });

    test('an order number opens the order whatever the type of the message is called', () {
      for (final String type in <String>['new_order', 'order', 'order_status', 'delivery_man_assign', '']) {
        expect(NotificationRoute.targetOf(_payload(<String, dynamic>{'type': type, 'order_id': '8'}), signedIn: true), NotificationTarget.order, reason: 'type "$type"');
      }
    });

    test('a message that names nothing opens nothing: no data, no type, an empty order number, a maintenance beacon', () {
      expect(NotificationRoute.targetOf(null, signedIn: true), NotificationTarget.none);
      expect(NotificationRoute.targetOf(_payload(<String, dynamic>{}), signedIn: true), NotificationTarget.none);
      expect(NotificationRoute.targetOf(_payload(<String, dynamic>{'order_id': '', 'type': 'order'}), signedIn: true), NotificationTarget.none);
      expect(NotificationRoute.targetOf(_payload(<String, dynamic>{'type': 'maintenance_mode'}), signedIn: true), NotificationTarget.none);
    });

    test('a title that mentions an order is not an order: only the data decides', () {
      final NotificationBody payload = _payload(<String, dynamic>{'title': 'Order 12 is ready', 'type': 'maintenance_mode'});

      expect(NotificationRoute.targetOf(payload, signedIn: true), NotificationTarget.none);
    });
  });

  group('the order number an older server puts in the title key', () {
    test('is used only when the data names no order', () {
      expect(NotificationRoute.targetOf(null, legacyOrderKey: '321', signedIn: true), NotificationTarget.order);
      expect(NotificationRoute.orderIdOf(null, legacyOrderKey: '321'), 321);
      expect(NotificationRoute.targetOf(_payload(<String, dynamic>{'type': 'x'}), legacyOrderKey: '321', signedIn: true), NotificationTarget.order);
    });

    test('never takes the place of what the data says', () {
      final NotificationBody payload = _payload(<String, dynamic>{'order_id': '10', 'type': 'order'});

      expect(NotificationRoute.orderIdOf(payload, legacyOrderKey: '321'), 10);
      expect(NotificationRoute.targetOf(_payload(<String, dynamic>{'type': 'refund', 'refund_id': '2'}), legacyOrderKey: '321', signedIn: true), NotificationTarget.refund);
      expect(NotificationRoute.targetOf(_payload(<String, dynamic>{'type': 'chatting'}), legacyOrderKey: '321', signedIn: true), NotificationTarget.chat);
    });

    test('an empty or non numeric key opens nothing', () {
      for (final String? key in <String?>[null, '', 'abc', ' ', '12x']) {
        expect(NotificationRoute.targetOf(null, legacyOrderKey: key, signedIn: true), NotificationTarget.none, reason: 'key $key');
      }
    });
  });

  group('a seller who is signed out', () {
    test('is taken nowhere by a notification, whatever it is about and whatever an older server put in its title key', () {
      final List<NotificationBody?> notifications = <NotificationBody?>[
        _payload(<String, dynamic>{'order_id': '1234', 'type': 'order'}),
        _payload(<String, dynamic>{'type': 'chatting', 'message_key': 'message_from_customer'}),
        _payload(<String, dynamic>{'type': 'Theme'}),
        _payload(<String, dynamic>{'type': 'wallet_withdraw'}),
        _payload(<String, dynamic>{'type': 'product_request_approved_message'}),
        _payload(<String, dynamic>{'type': 'refund', 'refund_id': '7'}),
        null,
      ];

      for (final NotificationBody? notification in notifications) {
        expect(NotificationRoute.targetOf(notification, signedIn: false, legacyOrderKey: '321'), NotificationTarget.none, reason: '${notification?.type}');
        expect(NotificationRoute.targetOf(notification, signedIn: true, legacyOrderKey: '321'), isNot(NotificationTarget.none), reason: 'the same notification opens a screen once the seller is signed in: ${notification?.type}');
      }
    });
  });

  group('the handlers of the seller app', () {
    final List<String> lines = File('lib/notification/my_notification.dart').readAsStringSync().split('\n').where((String line) => !line.trimLeft().startsWith('//')).toList();
    final String code = lines.join('\n');

    test('no handler looks at the words of a title to decide where to go', () {
      final RegExp titleTest = RegExp(r'title\s*[!?]?\s*\.\s*contains\(');

      expect(titleTest.hasMatch(code), isFalse, reason: 'a title is in the language of the seller');
    });

    test('a message without a notification part does not stop the handler', () {
      expect(code, isNot(contains('message.notification!')), reason: 'a data message has no notification part');
    });

    test('the tap of a local notification and the opening of the app from a push both go through the one opener', () {
      expect(RegExp(r'_open\(NotificationBody\.fromJson\(jsonDecode\(data\.payload!\)\)\)').hasMatch(code), isTrue);
      expect(code, contains('_open(message.data.isNotEmpty ? NotificationBody.fromJson(message.data) : null, legacyOrderKey: message.notification?.titleLocKey)'));
      expect(RegExp(r'NotificationRoute\.targetOf\(').allMatches(code).length, 1, reason: 'one decision, not one for each entry point');
    });

    test('the opener does not dereference a navigator that is not mounted', () {
      expect(code, isNot(contains('Get.navigator!')));
      expect(code, contains('final NavigatorState? navigator = Get.navigator;'));
    });

    test('the opener tells the route whether the seller is signed in, as the chat refresh of a push already asks', () {
      expect(code, contains('final bool signedIn = Provider.of<AuthController>(navigator.context, listen: false).isLoggedIn();'));
      expect(code, contains('NotificationRoute.targetOf(payload, signedIn: signedIn, legacyOrderKey: legacyOrderKey)'));
    });
  });
}
