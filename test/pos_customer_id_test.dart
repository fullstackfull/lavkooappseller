import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/pos_customer_id.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/temporary_cart_for_customer_model.dart';

TemporaryCartListModel _cart(int? userId, String? customerName) =>
    TemporaryCartListModel(userId: userId, customerName: customerName, cart: <dynamic>[].cast());

/// K-06: a sale is for a registered customer or for a walk-in, and the server is told which by the number of the customer and by nothing else. An earlier version recognised a walk-in whose cart
/// was put on hold by its random number having four digits, so a registered customer whose id has four digits was sold to as a walk-in, and a walk-in whose number had fewer digits was sold to
/// as the registered customer who has that id.
void main() {
  group('who the server is told a sale is for', () {
    test('a registered customer is told as themselves, whatever the number of digits of their id', () {
      for (final int id in <int>[1, 9, 99, 537, 999, 1000, 1234, 9999, 10000, 123456, 2147483647]) {
        expect(PosCustomerId.forServer(id), id, reason: 'customer $id');
        expect(PosCustomerId.isRegistered(id), isTrue, reason: 'customer $id');
        expect(PosCustomerId.isWalkIn(id), isFalse, reason: 'customer $id');
      }
    });

    test('a walk-in is told as 0, whether it has no id, 0 or the negative id of a held cart', () {
      for (final int? id in <int?>[null, 0, -1, -537, -1234, -999999, -1000000]) {
        expect(PosCustomerId.forServer(id), 0, reason: 'id $id');
        expect(PosCustomerId.isWalkIn(id), isTrue, reason: 'id $id');
        expect(PosCustomerId.isRegistered(id), isFalse, reason: 'id $id');
      }
    });
  });

  group('a walk-in cart put on hold', () {
    test('gets an id that is nobody\'s: negative, and told to the server as a walk-in', () {
      final Random random = Random(7);

      for (int draw = 0; draw < 20000; draw++) {
        final int id = PosCustomerId.newHeldWalkInId(random);

        expect(id, lessThan(0));
        expect(id, greaterThanOrEqualTo(-1000000));
        expect(PosCustomerId.forServer(id), 0);
      }
    });

    test('is named after the walk-in and the number of the cart', () {
      expect(PosCustomerId.heldWalkInName(PosCustomerId.walkInName, -537), 'Walk-In Customer-537');
      expect(PosCustomerId.heldWalkInName(PosCustomerId.walkInName, -1234), 'Walk-In Customer-1234');
    });
  });

  group('held carts saved by an earlier version', () {
    test('a walk-in cart that carries the random number it was given is given the negative id it would have today, whatever the number of its digits', () {
      for (final int number in <int>[0, 7, 537, 999, 1000, 1234, 9999]) {
        final List<TemporaryCartListModel> carts = <TemporaryCartListModel>[_cart(number, 'Walk-In Customer-$number')];

        PosCustomerId.markLegacyWalkInCarts(carts);

        expect(PosCustomerId.forServer(carts.single.userId), 0, reason: 'cart $number');
        expect(carts.single.userId == null || carts.single.userId! <= 0, isTrue, reason: 'cart $number');
      }
    });

    test('a cart of a registered customer is not touched, whatever its name and whatever the number of digits of the id', () {
      final List<TemporaryCartListModel> carts = <TemporaryCartListModel>[
        _cart(537, 'Layla'),
        _cart(1234, 'Omar'),
        _cart(1234, 'Walk-In Customer-1235'),
        _cart(537, 'Walk-In Customer-1234'),
        _cart(537, 'Layla-537'),
        _cart(537, null),
        _cart(null, 'Walk-In Customer-537'),
      ];

      PosCustomerId.markLegacyWalkInCarts(carts);

      expect(carts.map((TemporaryCartListModel cart) => cart.userId).toList(), <int?>[537, 1234, 1234, 537, 537, 537, null]);
    });

    test('the walk-in cart of today and a second reading of the same list are left as they are', () {
      final List<TemporaryCartListModel> carts = <TemporaryCartListModel>[_cart(-537, 'Walk-In Customer-537'), _cart(1234, 'Walk-In Customer-1234')];

      PosCustomerId.markLegacyWalkInCarts(carts);
      PosCustomerId.markLegacyWalkInCarts(carts);

      expect(carts.map((TemporaryCartListModel cart) => cart.userId).toList(), <int?>[-537, -1234]);
    });
  });

  group('the code of the seller app', () {
    String code(String path) => File(path).readAsStringSync();

    List<String> linesOfCode(String path) => code(path).split('\n').where((String line) => !line.trimLeft().startsWith('//')).toList();

    test('no file infers a walk-in from the number of digits of an id', () {
      final List<String> found = <String>[];

      for (final FileSystemEntity entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        for (final String line in linesOfCode(entity.path)) {
          if (RegExp(r'toString\(\)\s*\.length\s*==\s*4').hasMatch(line)) {
            found.add('${entity.path}: ${line.trim()}');
          }
        }
      }

      expect(found, isEmpty, reason: 'a customer id has four digits for a thousand customers; it says nothing about walk-ins');
    });

    test('the POS tells the server who a sale is for through the one helper, and the digital product check uses it too', () {
      final String screen = code('lib/features/pos/screens/pos_screen.dart');

      expect(screen, contains('userId:  PosCustomerId.forServer(customerController.customerId)'));
      expect(screen, contains('hasDigitalProduct && PosCustomerId.isWalkIn(customerController.customerId)'));
    });

    test('a held cart is resumed as the customer the helper says, and the carts of an earlier version are read through the helper', () {
      final String cart = code('lib/features/pos/controllers/cart_controller.dart');

      expect(cart, contains('PosCustomerId.forServer(tempCart.userId)'));
      expect(cart, contains('PosCustomerId.newHeldWalkInId(Random())'));
      expect(cart, contains('PosCustomerId.markLegacyWalkInCarts(localCartList)'));
      expect(cart, isNot(contains("contains('walk.ing')")), reason: 'a pattern that never matched the name of a walk-in');
      expect(cart, isNot(contains('Random().nextInt(10000)')), reason: 'a random number a registered customer could have');
    });
  });
}
