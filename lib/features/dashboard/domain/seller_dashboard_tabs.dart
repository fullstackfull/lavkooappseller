import 'package:syriacosmeticsmanger/features/security/domain/models/seller_permission_scope.dart';
import 'package:syriacosmeticsmanger/utill/images.dart';

/// The tabs at the foot of the seller app, and which of them the signed-in role may use (K-08).
///
/// The "more" screen leaves out the entries a role lacks; the bar did not, so a staff member who may not see orders still had an
/// Orders tab that answered them 403 on arrival, and one who may not see products had a Products tab. Each tab names the entry of
/// the permission catalogue it is, and the list is worked out here rather than in the widget so that what a role sees can be
/// asserted without building a screen.
///
/// Hiding is a courtesy and not a boundary. Enforcement is the server's, on every route, for every caller: a staff member who
/// knows the URL gets the same 403 as one who cannot see the tab. So a scope that could not be read hides nothing, and the app
/// draws exactly what it always drew.
enum SellerDashboardTab {
  home(page: 0, icon: Images.home, label: 'home'),
  orders(page: 1, icon: Images.order, label: 'my_order', screen: SellerScreen.inbox),

  /// The till also needs the point of sale switched on, for the platform and for this shop, which is not a permission.
  pointOfSale(page: 2, icon: Images.pos, label: 'pos', screen: SellerScreen.pointOfSale, needsPointOfSale: true),
  products(page: 3, icon: Images.productIcon, label: 'products', screen: SellerScreen.products),

  /// Open to any credential: it is the way to the profile, the language and the sign-out, and a staff member needs all three.
  more(page: 4, icon: Images.menu, label: 'more');

  const SellerDashboardTab({
    required this.page,
    required this.icon,
    required this.label,
    this.screen,
    this.needsPointOfSale = false,
  });

  /// The index of the tab's screen in the stack the dashboard keeps alive. Fixed per tab, so hiding one never renumbers another.
  final int page;

  final String icon;

  /// The translation key of the tab's label.
  final String label;

  /// The entry of the permission catalogue this tab is, or null for a tab open to whoever holds a credential of the shop.
  final SellerScreen? screen;

  final bool needsPointOfSale;

  /// The tabs to draw, in their order.
  static List<SellerDashboardTab> visible({required bool posEnabled, required SellerPermissionScope scope}) {
    return <SellerDashboardTab>[
      for (final SellerDashboardTab tab in values)
        if ((!tab.needsPointOfSale || posEnabled) && (tab.screen == null || scope.allows(tab.screen!))) tab,
    ];
  }
}
