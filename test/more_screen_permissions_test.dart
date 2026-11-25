import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/features/menu/screens/more_screen.dart';
import 'package:syriacosmeticsmanger/features/profile/controllers/profile_controller.dart';
import 'package:syriacosmeticsmanger/features/profile/domain/services/profice_service_interface.dart';
import 'package:syriacosmeticsmanger/features/security/controllers/seller_permission_controller.dart';
import 'package:syriacosmeticsmanger/features/security/domain/models/seller_permission_scope.dart';
import 'package:syriacosmeticsmanger/features/splash/controllers/splash_controller.dart';
import 'package:syriacosmeticsmanger/features/splash/domain/services/splash_service_interface.dart';
import 'package:syriacosmeticsmanger/localization/controllers/localization_controller.dart';
import 'package:syriacosmeticsmanger/theme/controllers/theme_controller.dart';

import 'market_selector/support/harness.dart';

class _UnusedSplashService extends Fake implements SplashServiceInterface {}

class _UnusedProfileService extends Fake implements ProfileServiceInterface {}

/// The entry of the "more" screen for each screen a role can be kept out of, by the key the language file titles it with.
///
/// Every screen that can be hidden is here, so the test below drives the whole mapping through the real screen rather than a
/// sample of it. The point of sale is the one entry of the screen that is absent for two other reasons as well (the platform's
/// POS switch and the shop's), so what the scope decides for it is read in test/seller_permission_scope_test.dart instead.
const Map<SellerScreen, String> _titleKeys = <SellerScreen, String>{
  SellerScreen.myShop: 'my_shop',
  SellerScreen.sellerCentre: 'seller_center',
  SellerScreen.verification: 'verification',
  SellerScreen.addProduct: 'add_product',
  SellerScreen.products: 'products',
  SellerScreen.bulkOperations: 'bulk_operations',
  SellerScreen.inventory: 'inventory',
  SellerScreen.restock: 'restock',
  SellerScreen.clearanceSale: 'clearance_sale',
  SellerScreen.coupons: 'coupons',
  SellerScreen.reviews: 'reviews',
  SellerScreen.refund: 'refund',
  SellerScreen.returns: 'returns',
  SellerScreen.inbox: 'inbox',
  SellerScreen.deliveryMan: 'deliveryman',
  SellerScreen.wallet: 'wallet',
  SellerScreen.bankInformation: 'bank_info',
  SellerScreen.payouts: 'payouts',
  SellerScreen.statement: 'statement',
  SellerScreen.analytics: 'analytics',
  SellerScreen.controlTower: 'control_tower',
  SellerScreen.automation: 'automation',
  SellerScreen.moneyAndPricing: 'money_and_pricing',
  SellerScreen.brands: 'brands',
  SellerScreen.securityCentre: 'security_centre',
  SellerScreen.orderReport: 'order_report',
  SellerScreen.productReport: 'product_report',
  SellerScreen.stockReport: 'stock_report',
};

/// The entries no role can be kept out of, because the routes behind them carry no permission.
const Map<SellerScreen, String> _openTitleKeys = <SellerScreen, String>{
  SellerScreen.profile: 'profile',
  SellerScreen.settings: 'settings',
  SellerScreen.vatManagement: 'vat_management',
};

Map<String, dynamic> _english() =>
    jsonDecode(File('assets/language/en.json').readAsStringSync()) as Map<String, dynamic>;

SellerPermissionScope _staffHolding(List<String> permissions, String role) =>
    SellerPermissionScope.fromPrincipal(<String, dynamic>{
      'principal_type': 'staff',
      'role': role,
      'permissions': permissions,
    });

/// What a seller actually sees in the "more" tab once the server has said who they are (K-08).
///
/// A staff member whose role granted two permissions used to be shown the owner's whole app — the security centre with every
/// colleague's e-mail behind it, the statement, the payouts — and met a 403 toast on opening any of them. The entries are left
/// out now. The screen is drawn at a size that fits every section at once, because the sections are a lazy list and an entry
/// that was never laid out would read as hidden whatever the rule decided.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  late Map<String, dynamic> words;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = await SharedPreferences.getInstance();
    words = _english();
  });

  Future<void> showMore(WidgetTester tester, {SellerPermissionController? permissions}) async {
    MarketHarness.useScreen(tester, const Size(900, 6000));
    await tester.pumpWidget(await MarketHarness.app(
      tester,
      providers: [
        ChangeNotifierProvider<ThemeController>(create: (_) => ThemeController(sharedPreferences: preferences)),
        ChangeNotifierProvider<LocalizationController>(create: (_) => LocalizationController(sharedPreferences: preferences)),
        ChangeNotifierProvider<SplashController>(create: (_) => SplashController(serviceInterface: _UnusedSplashService())),
        ChangeNotifierProvider<ProfileController>(create: (_) => ProfileController(profileServiceInterface: _UnusedProfileService())),
      ],
      home: MoreScreen(storefrontsEnabled: false, permissionController: permissions),
    ));
    await tester.pump();
  }

  void expectEntriesFor(SellerPermissionScope scope) {
    for (final MapEntry<SellerScreen, String> entry in <SellerScreen, String>{..._titleKeys, ..._openTitleKeys}.entries) {
      final String title = words[entry.value] as String;
      expect(
        find.text(title),
        scope.allows(entry.key) ? findsOneWidget : findsNothing,
        reason: '${entry.key.name} ("$title") ${scope.allows(entry.key) ? 'should be shown' : 'should be hidden'}',
      );
    }
  }

  testWidgets('a build with no scope of its own draws every entry, as this screen always did', (WidgetTester tester) async {
    await showMore(tester);

    expectEntriesFor(const SellerPermissionScope.unrestricted());
    for (final String section in <String>['shop_and_account', 'catalog_and_sales', 'orders_and_operations', 'finance_and_reports', 'app_and_policies']) {
      expect(find.text(words[section] as String), findsOneWidget, reason: section);
    }
  });

  testWidgets('the owner is shown every entry of every section', (WidgetTester tester) async {
    final SellerPermissionScope owner = SellerPermissionScope.fromPrincipal(<String, dynamic>{
      'principal_type': 'owner',
      'role': null,
      'permissions': <dynamic>[
        'products.view', 'products.manage', 'orders.view', 'orders.manage', 'inventory.manage',
        'promotions.manage', 'finance.view', 'payouts.request', 'reviews.view', 'shop_settings.manage', 'staff.manage',
      ],
    });

    await showMore(tester, permissions: SellerPermissionController(enabled: true)..apply(owner));

    expectEntriesFor(owner);
  });

  testWidgets('an order clerk is shown the orders and the catalogue they may read, and not the books or the team', (WidgetTester tester) async {
    final SellerPermissionScope clerk = _staffHolding(<String>['products.view', 'orders.view'], 'Order clerk');

    await showMore(tester, permissions: SellerPermissionController(enabled: true)..apply(clerk));

    expectEntriesFor(clerk);
    expect(find.text(words['returns'] as String), findsOneWidget);
    expect(find.text(words['security_centre'] as String), findsNothing, reason: 'the team list carries every colleague\'s e-mail');
    expect(find.text(words['statement'] as String), findsNothing, reason: 'the books are finance.view');
    expect(find.text(words['verification'] as String), findsNothing, reason: 'the shop\'s standing is the owner\'s own');
  });

  testWidgets('a warehouse hand is shown the stock they manage, and not the catalogue writes or the money', (WidgetTester tester) async {
    final SellerPermissionScope warehouse = _staffHolding(<String>['inventory.manage', 'orders.manage'], 'Warehouse');

    await showMore(tester, permissions: SellerPermissionController(enabled: true)..apply(warehouse));

    expectEntriesFor(warehouse);
    expect(find.text(words['inventory'] as String), findsOneWidget);
    expect(find.text(words['refund'] as String), findsOneWidget);
    expect(find.text(words['wallet'] as String), findsNothing);
    expect(find.text(words['payouts'] as String), findsNothing);
  });

  testWidgets('a role that grants nothing leaves the sections it emptied out of the screen, headings and all', (WidgetTester tester) async {
    final SellerPermissionScope observer = _staffHolding(<String>[], 'Observer');

    await showMore(tester, permissions: SellerPermissionController(enabled: true)..apply(observer));

    expectEntriesFor(observer);
    expect(find.text(words['shop_and_account'] as String), findsOneWidget, reason: 'the profile and the language chooser stay');
    expect(find.text(words['app_and_policies'] as String), findsOneWidget, reason: 'and so does the way out of the app');
    for (final String section in <String>['catalog_and_sales', 'orders_and_operations']) {
      expect(find.text(words[section] as String), findsNothing, reason: '$section has nothing left in it');
    }
    expect(find.text(words['logout'] as String), findsOneWidget, reason: 'no role is ever kept from signing out');
  });

  testWidgets('the screen follows the answer: the entries go once the server says who is signed in', (WidgetTester tester) async {
    final SellerPermissionController permissions = SellerPermissionController(enabled: true);

    await showMore(tester, permissions: permissions);

    expect(find.text(words['security_centre'] as String), findsOneWidget, reason: 'nothing is hidden before the answer arrives');

    permissions.apply(_staffHolding(<String>['orders.view'], 'Order clerk'));
    await tester.pump();

    expect(find.text(words['security_centre'] as String), findsNothing);
    expect(find.text(words['returns'] as String), findsOneWidget);
  });

  testWidgets('and comes back when the role signs out, so the next seller on the phone starts from the whole app', (WidgetTester tester) async {
    final SellerPermissionController permissions = SellerPermissionController(enabled: true)
      ..apply(_staffHolding(<String>[], 'Observer'));

    await showMore(tester, permissions: permissions);

    expect(find.text(words['statement'] as String), findsNothing);

    permissions.apply(const SellerPermissionScope.unrestricted());
    await tester.pump();

    expect(find.text(words['statement'] as String), findsOneWidget);
  });
}
