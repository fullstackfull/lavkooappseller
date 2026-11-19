import 'package:syriacosmeticsmanger/features/pos/domain/services/cart_service_interface.dart';
import 'package:syriacosmeticsmanger/features/profile/domain/services/profice_service_interface.dart';
import 'package:syriacosmeticsmanger/features/shop/domain/services/shop_service_interface.dart';

/// The cart service of a controller a flow only needs to exist: it is read from the tree by the code under test, and a
/// flow that reached for the cart's network would be a flow that does not do what its test says.
class UnusedCartService implements CartServiceInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('the flow does not use ${invocation.memberName}');
}

/// The same for the seller's profile, which a flow only needs to be told to refresh.
class UnusedProfileService implements ProfileServiceInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('the flow does not use ${invocation.memberName}');
}

/// The same for the shop, which a flow only needs to be told to refresh.
class UnusedShopService implements ShopServiceInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('the flow does not use ${invocation.memberName}');
}
