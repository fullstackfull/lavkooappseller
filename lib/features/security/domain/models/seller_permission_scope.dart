/// A permission of the seller's own shop, named the way the server names it.
///
/// The eleven keys are `SellerPermissionService::catalog()` of the backend, in its order. The owner holds every one of them; a
/// staff member holds what their role grants, read from the role on every request, so a role changed on the server shows on the
/// next answer.
enum SellerPermission {
  productsView('products.view'),
  productsManage('products.manage'),
  ordersView('orders.view'),
  ordersManage('orders.manage'),
  inventoryManage('inventory.manage'),
  promotionsManage('promotions.manage'),
  financeView('finance.view'),
  payoutsRequest('payouts.request'),
  reviewsView('reviews.view'),
  shopSettingsManage('shop_settings.manage'),
  staffManage('staff.manage');

  const SellerPermission(this.key);

  /// The key the server answers and the routes declare (`seller_can:orders.manage`).
  final String key;

  /// The permission of [key], or null for a key this version of the app has never heard of.
  ///
  /// A key the app does not know is NOT a key the caller lacks: the catalogue can grow, and a build that read an unknown key as a
  /// refusal would hide a screen the server would have answered. An unknown key gates nothing here, so it hides nothing.
  static SellerPermission? parse(Object? value) {
    for (final SellerPermission permission in SellerPermission.values) {
      if (permission.key == value) return permission;
    }
    return null;
  }
}

/// Who holds the credential the app signed in with. A key is no person, so the server answers these two and nothing else.
enum SellerPrincipalType {
  owner,
  staff;

  static SellerPrincipalType? parse(Object? value) {
    for (final SellerPrincipalType type in SellerPrincipalType.values) {
      if (type.name == value) return type;
    }
    return null;
  }
}

/// A screen or an entry of the seller app, with what the server asks for before it answers anything behind it (K-08).
///
/// The permissions of each entry are the `seller_can` declarations of the routes that entry reads, from
/// `routes/rest_api/v3/seller.php`. Several permissions mean ANY ONE of them will do, because that is what the gate does
/// (`EnsureSellerPermission`: the first permission the principal holds lets the request through). [ownerOnly] is the
/// `seller_owner` middleware, which no role can be granted: the owner's own account rather than an operation inside the shop.
///
/// An entry with no permission and no owner mark is open to whoever holds a credential of the shop, and is never hidden.
enum SellerScreen {
  /// `seller-info`, which carries no permission: withholding it would leave a staff member unable to see which shop they are in.
  profile(<SellerPermission>[]),
  myShop(<SellerPermission>[SellerPermission.shopSettingsManage]),
  sellerCentre(<SellerPermission>[
    SellerPermission.ordersView,
    SellerPermission.ordersManage,
    SellerPermission.productsView,
    SellerPermission.productsManage,
    SellerPermission.financeView,
  ]),

  /// The shop's standing with the marketplace, which belongs to the account holder and to no delegable permission.
  verification(<SellerPermission>[], ownerOnly: true),

  /// The language chooser is open to any credential, and the shipping setting beside it is not: gating the screen on the
  /// setting would take the language away from a staff member, so the screen stays and the server refuses the part it owns.
  settings(<SellerPermission>[]),

  addProduct(<SellerPermission>[SellerPermission.productsManage]),
  products(<SellerPermission>[SellerPermission.productsView, SellerPermission.productsManage]),
  bulkOperations(<SellerPermission>[
    SellerPermission.productsView,
    SellerPermission.productsManage,
    SellerPermission.inventoryManage,
  ]),
  inventory(<SellerPermission>[SellerPermission.inventoryManage, SellerPermission.productsView]),
  restock(<SellerPermission>[SellerPermission.productsView, SellerPermission.productsManage]),
  clearanceSale(<SellerPermission>[SellerPermission.promotionsManage]),
  coupons(<SellerPermission>[SellerPermission.promotionsManage]),
  reviews(<SellerPermission>[SellerPermission.reviewsView]),

  pointOfSale(<SellerPermission>[SellerPermission.ordersManage]),
  refund(<SellerPermission>[SellerPermission.ordersManage]),
  returns(<SellerPermission>[SellerPermission.ordersView, SellerPermission.ordersManage]),
  inbox(<SellerPermission>[SellerPermission.ordersView, SellerPermission.ordersManage]),
  deliveryMan(<SellerPermission>[SellerPermission.ordersManage]),

  wallet(<SellerPermission>[SellerPermission.financeView]),

  /// Reading where the money is sent is finance; changing it is the account itself, and the server refuses that write on its own.
  bankInformation(<SellerPermission>[SellerPermission.financeView]),
  payouts(<SellerPermission>[SellerPermission.financeView]),
  statement(<SellerPermission>[SellerPermission.financeView]),
  analytics(<SellerPermission>[SellerPermission.financeView, SellerPermission.ordersView]),
  controlTower(<SellerPermission>[SellerPermission.ordersView]),
  automation(<SellerPermission>[SellerPermission.productsView, SellerPermission.productsManage]),
  moneyAndPricing(<SellerPermission>[
    SellerPermission.financeView,
    SellerPermission.productsView,
    SellerPermission.productsManage,
  ]),
  brands(<SellerPermission>[SellerPermission.productsView, SellerPermission.productsManage]),

  /// The team list carries every employee's e-mail and last login and the trail carries the before and after of a bank-details
  /// change, so reading the desk is gated as deliberately as writing it.
  securityCentre(<SellerPermission>[SellerPermission.staffManage]),

  orderReport(<SellerPermission>[
    SellerPermission.ordersView,
    SellerPermission.ordersManage,
    SellerPermission.financeView,
  ]),
  productReport(<SellerPermission>[
    SellerPermission.productsView,
    SellerPermission.productsManage,
    SellerPermission.inventoryManage,
  ]),
  stockReport(<SellerPermission>[
    SellerPermission.productsView,
    SellerPermission.productsManage,
    SellerPermission.inventoryManage,
  ]),

  /// The seller app reads `get-vat-tax-report-list`, which the backend declares in no route file, so there is no `seller_can`
  /// declaration to mirror here. It is left open rather than guessed at.
  vatManagement(<SellerPermission>[]);

  const SellerScreen(this.permissions, {this.ownerOnly = false});

  /// Any one of these lets the server answer. Empty means the entry needs no permission.
  final List<SellerPermission> permissions;

  /// Whether the routes behind the entry carry `seller_owner`, which no role can hold.
  final bool ownerOnly;
}

/// What the signed-in seller or staff member may use, as `GET api/v3/seller/seller-center/security/me` answers it (K-08).
///
/// This hides entries a role cannot use; it does not enforce anything. Enforcement is the server's, on every route, for every
/// caller — a staff member who knows the URL or writes their own client gets the same 403 as one who cannot see the button
/// (`EnsureSellerPermission`: "Enforcement lives here and in policies, never in whether a menu item is drawn"). So an answer
/// that cannot be read leaves the app as it has always been, showing everything, rather than emptying a seller's app on a
/// malformed answer: nothing is reachable that the server would not have served anyway.
class SellerPermissionScope {
  const SellerPermissionScope({this.principalType, this.role, this.permissions});

  /// Nothing was read: a build whose role screens are off, a server with no such route, a request that failed. The app shows
  /// what it always showed.
  const SellerPermissionScope.unrestricted()
      : principalType = null,
        role = null,
        permissions = null;

  /// Reads the scope out of the `me` answer. `permissions` that is not a list is read as not read at all, because a seller whose
  /// answer arrived malformed must not be left staring at an app with nothing in it; an empty list IS an answer, and a role that
  /// grants nothing reaches nothing.
  factory SellerPermissionScope.fromPrincipal(Map<String, dynamic>? principal) {
    if (principal == null) {
      return const SellerPermissionScope.unrestricted();
    }

    final Object? keys = principal['permissions'];
    final Object? role = principal['role'];

    return SellerPermissionScope(
      principalType: SellerPrincipalType.parse(principal['principal_type']),
      role: role is String && role.isNotEmpty ? role : null,
      permissions: keys is List ? _held(keys) : null,
    );
  }

  static Set<SellerPermission> _held(List<Object?> keys) =>
      keys.map(SellerPermission.parse).whereType<SellerPermission>().toSet();

  /// `owner`, `staff`, or null for an answer that named neither.
  final SellerPrincipalType? principalType;

  /// The name of the staff member's role; null for the owner, for a staff member with no role, and for no answer.
  final String? role;

  /// The keys the caller holds, or null when none were read. Null is "no limit", and is never an empty set: a role that grants
  /// nothing holds an empty set and reaches nothing.
  final Set<SellerPermission>? permissions;

  /// Whether an answer was read at all. A scope that read nothing hides nothing.
  bool get read => principalType != null || permissions != null;

  bool get isOwner => principalType == SellerPrincipalType.owner;

  bool get isStaff => principalType == SellerPrincipalType.staff;

  /// Whether the caller holds [permission]. Unknown while no permissions were read, and unknown is never read as lacking.
  bool holds(SellerPermission permission) => permissions?.contains(permission) ?? true;

  /// Whether [screen] is worth drawing for this caller.
  ///
  /// The owner holds every permission and every owner-only action, so the owner is never hidden from. An owner-only entry is
  /// hidden from a staff member even when their permissions could not be read, because `principal_type` alone settles it.
  bool allows(SellerScreen screen) {
    if (isOwner) {
      return true;
    }
    if (screen.ownerOnly) {
      return !isStaff;
    }
    if (screen.permissions.isEmpty) {
      return true;
    }

    final Set<SellerPermission>? held = permissions;

    return held == null || screen.permissions.any(held.contains);
  }
}
