import 'dart:math';

import 'package:syriacosmeticsmanger/features/pos/domain/models/temporary_cart_for_customer_model.dart';

/// Who a POS sale is for: a registered customer has a positive id, a walk-in has none, and the server is told 0 for a walk-in.
///
/// A walk-in cart that is put on hold is told apart from every other cart by a negative id, never by a number that a registered customer could have. An earlier version gave it a random
/// number from 0 to 9999 and recognised a walk-in by that number having four digits, so a registered customer whose id has four digits (1000 to 9999) was sold to as a walk-in,
/// and a walk-in whose number had fewer digits was sold to as the registered customer who has that id.
class PosCustomerId {
  const PosCustomerId._();

  /// The name of a customer who has no account, as the POS shows it; a held cart adds the number of the cart after it.
  static const String walkInName = 'Walk-In Customer';

  static const int _heldWalkInIdRange = 1000000;

  static bool isRegistered(int? customerId) => customerId != null && customerId > 0;

  static bool isWalkIn(int? customerId) => !isRegistered(customerId);

  /// The id the server is told: the registered customer's own, and 0 for a walk-in whatever the number its held cart carries.
  static int forServer(int? customerId) => isRegistered(customerId) ? customerId! : 0;

  /// The id of a walk-in cart that is put on hold: negative, so that it is nobody's.
  static int newHeldWalkInId(Random random) => -(random.nextInt(_heldWalkInIdRange) + 1);

  /// The name of a held walk-in cart: the walk-in's name and the number of the cart.
  static String heldWalkInName(String? customerName, int heldWalkInId) => '$customerName-${-heldWalkInId}';

  /// Held carts that an earlier version saved: a walk-in cart carries the random number it was given as its id, and is named after the walk-in and that number. That number belongs
  /// to no customer, so the cart is given the negative id it would have today. A cart of a registered customer is not touched, whatever its name.
  static void markLegacyWalkInCarts(List<TemporaryCartListModel> carts) {
    for (final TemporaryCartListModel cart in carts) {
      final int? userId = cart.userId;
      if (userId != null && userId > 0 && cart.customerName == '$walkInName-$userId') {
        cart.userId = -userId;
      }
    }
  }
}
