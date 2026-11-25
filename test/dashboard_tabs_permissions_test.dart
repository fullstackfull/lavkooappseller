import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/dashboard/domain/seller_dashboard_tabs.dart';
import 'package:syriacosmeticsmanger/features/security/domain/models/seller_permission_scope.dart';

SellerPermissionScope _staffHolding(List<String> permissions) => SellerPermissionScope.fromPrincipal(<String, dynamic>{
      'principal_type': 'staff',
      'role': 'A role of two permissions',
      'permissions': permissions,
    });

const SellerPermissionScope _owner = SellerPermissionScope(principalType: SellerPrincipalType.owner);

/// Which tabs the bar at the foot of the app draws for whom (K-08).
///
/// The "more" screen already left out the entries a role lacks. The bar did not: a staff member who may not see orders was still
/// given an Orders tab, and it answered them 403 the moment they touched it. What follows is the whole rule, driven through the
/// list the dashboard itself builds its bar from.
void main() {
  group('what a role sees at the foot of the app', () {
    test('the owner sees every tab, with the till when the point of sale is on', () {
      expect(SellerDashboardTab.visible(posEnabled: true, scope: _owner), SellerDashboardTab.values);
    });

    test('and loses only the till when the point of sale is off, which is no permission of anybody\'s', () {
      expect(
        SellerDashboardTab.visible(posEnabled: false, scope: _owner),
        <SellerDashboardTab>[
          SellerDashboardTab.home,
          SellerDashboardTab.orders,
          SellerDashboardTab.products,
          SellerDashboardTab.more,
        ],
      );
    });

    test('a staff member who may only look at products keeps Home, Products and More', () {
      expect(
        SellerDashboardTab.visible(posEnabled: true, scope: _staffHolding(<String>['products.view'])),
        <SellerDashboardTab>[SellerDashboardTab.home, SellerDashboardTab.products, SellerDashboardTab.more],
      );
    });

    test('a staff member who may manage orders keeps the orders tab and the till', () {
      final List<SellerDashboardTab> tabs =
          SellerDashboardTab.visible(posEnabled: true, scope: _staffHolding(<String>['orders.manage']));

      expect(tabs, contains(SellerDashboardTab.orders));
      expect(tabs, contains(SellerDashboardTab.pointOfSale));
      expect(tabs, isNot(contains(SellerDashboardTab.products)));
    });

    test('a staff member who may view orders keeps the orders tab and NOT the till, which is a write', () {
      final List<SellerDashboardTab> tabs =
          SellerDashboardTab.visible(posEnabled: true, scope: _staffHolding(<String>['orders.view']));

      expect(tabs, contains(SellerDashboardTab.orders));
      expect(tabs, isNot(contains(SellerDashboardTab.pointOfSale)));
    });

    test('a role that grants nothing still reaches Home and More, which is how it signs out', () {
      expect(
        SellerDashboardTab.visible(posEnabled: true, scope: _staffHolding(<String>[])),
        <SellerDashboardTab>[SellerDashboardTab.home, SellerDashboardTab.more],
      );
    });

    test('a scope that was never read hides nothing, so a build with the role screens off draws what it always drew', () {
      expect(
        SellerDashboardTab.visible(posEnabled: true, scope: const SellerPermissionScope.unrestricted()),
        SellerDashboardTab.values,
      );
    });

    test('hiding a tab never renumbers another: each tab keeps the index of its own screen', () {
      expect(
        SellerDashboardTab.values.map((SellerDashboardTab tab) => tab.page).toList(),
        <int>[0, 1, 2, 3, 4],
        reason: 'the dashboard keeps one screen per page, so a page number is a position in that stack and not in the bar',
      );
    });
  });

  group('what draws the bar', () {
    /// The rule above is worth nothing if the screen builds its own list beside it, which is exactly the mistake this tab gating
    /// was added to undo. The dashboard must take the list from here and from nowhere else.
    test('the dashboard builds its bar from this list and names no tab of its own', () {
      final String source = File('lib/features/dashboard/screens/dashboard_screen.dart').readAsStringSync();

      expect(source, contains('SellerDashboardTab.visible(posEnabled: posEnabled, scope: scope)'));
      expect(source.contains("label: 'my_order'"), isFalse, reason: 'a second list of tabs in the screen is the defect itself');
      expect(source.contains("label: 'pos'"), isFalse);
    });
  });
}
