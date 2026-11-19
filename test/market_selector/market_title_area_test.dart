import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_asset_image_widget.dart';
import 'package:syriacosmeticsmanger/features/home/widgets/home_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/features/notification/controllers/notification_controller.dart';
import 'package:syriacosmeticsmanger/features/notification/domain/services/notification_service_interface.dart';
import 'package:syriacosmeticsmanger/features/order/controllers/order_controller.dart';
import 'package:syriacosmeticsmanger/features/order/domain/services/order_service_interface.dart';
import 'package:syriacosmeticsmanger/features/order/screens/order_screen.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/customer_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/services/cart_service_interface.dart';
import 'package:syriacosmeticsmanger/features/storefront/controllers/seller_market_controller.dart';
import 'package:syriacosmeticsmanger/features/storefront/storefront_config.dart';
import 'package:syriacosmeticsmanger/features/storefront/widgets/market_label.dart';
import 'package:syriacosmeticsmanger/theme/controllers/theme_controller.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/images.dart';

import 'support/harness.dart';
import 'support/market_support.dart';

class _UnusedNotificationService extends Fake implements NotificationServiceInterface {}

class _UnusedOrderService extends Fake implements OrderServiceInterface {}

class _UnusedCartService extends Fake implements CartServiceInterface {}

Map<String, dynamic> _language(Locale locale) =>
    jsonDecode(File('assets/language/${locale.languageCode}.json').readAsStringSync()) as Map<String, dynamic>;

/// The two places where the seller reads money first, the dashboard and the order list, and the market in their title area. Each is the
/// real title area of the real screen, with the label on and off, in both languages, on the narrowest phone with large text: the label
/// must be there, in front of the action it goes with, and must leave the title what it needs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  late SellerMarketController market;

  setUp(() async {
    preferences = await preferencesWith();
    market = controllerOn(preferences);
    GetIt.instance.registerSingleton<SellerMarketController>(market);
  });
  tearDown(GetIt.instance.reset);

  Future<void> precacheLogo(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => precacheImage(const AssetImage(Images.logoWithAppName), tester.element(find.byType(SizedBox))));
  }

  Future<void> showDashboardBar(
    WidgetTester tester, {
    bool? storefrontsEnabled,
    Locale locale = MarketHarness.english,
    double textScale = 1.0,
    Size size = MarketHarness.narrowPhone,
  }) async {
    MarketHarness.useScreen(tester, size);
    await precacheLogo(tester);
    await tester.pumpWidget(await MarketHarness.app(
      tester,
      locale: locale,
      textScale: textScale,
      providers: [
        ChangeNotifierProvider<NotificationController>(
          create: (_) => NotificationController(notificationServiceInterface: _UnusedNotificationService()),
        ),
      ],
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            storefrontsEnabled == null ? const HomeAppBarWidget() : HomeAppBarWidget(storefrontsEnabled: storefrontsEnabled),
          ],
        ),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }

  Future<void> showOrderList(
    WidgetTester tester, {
    bool? storefrontsEnabled,
    Locale locale = MarketHarness.english,
    double textScale = 1.0,
    Size size = MarketHarness.narrowPhone,
  }) async {
    MarketHarness.useScreen(tester, size);
    await tester.pumpWidget(await MarketHarness.app(
      tester,
      locale: locale,
      textScale: textScale,
      providers: [
        ChangeNotifierProvider<ThemeController>(create: (_) => ThemeController(sharedPreferences: preferences)),
        ChangeNotifierProvider<OrderController>(create: (_) => OrderController(orderServiceInterface: _UnusedOrderService())),
        ChangeNotifierProvider<CustomerController>(create: (_) => CustomerController(cartServiceInterface: _UnusedCartService())),
      ],
      home: storefrontsEnabled == null ? const OrderScreen() : OrderScreen(storefrontsEnabled: storefrontsEnabled),
    ));
    await tester.pump();
  }

  Finder pillOf(Finder label) => find.descendant(of: label, matching: find.byType(DecoratedBox));

  final Finder dashboardAction = find.descendant(of: find.byType(SliverAppBar), matching: find.byType(InkWell));
  final Finder dashboardLogo = find.descendant(of: find.byType(SliverAppBar), matching: find.byType(Image));
  final Finder orderListAction = find.ancestor(
    of: find.descendant(of: find.byType(AppBar), matching: find.byType(CustomAssetImageWidget)),
    matching: find.byType(InkWell),
  );

  for (final Locale locale in <Locale>[MarketHarness.english, MarketHarness.arabic]) {
    final bool leftToRight = locale == MarketHarness.english;
    final Finder orderListTitle = find.text(_language(locale)['my_order'] as String);

    group('the title area of the dashboard, in ${locale.languageCode}', () {
      for (final double textScale in <double>[1.0, 1.3, 2.0]) {
        testWidgets('has the label in front of the bell on the narrowest phone at $textScale times the text size', (WidgetTester tester) async {
          await showDashboardBar(tester, storefrontsEnabled: true, locale: locale, textScale: textScale);

          expect(tester.takeException(), isNull);
          expect(find.byType(MarketLabel), findsOneWidget);
          expect(find.text('SA · SAR'), findsOneWidget);
          expect(find.byIcon(CupertinoIcons.bell), findsOneWidget);
          final Rect pill = tester.getRect(pillOf(find.byType(MarketLabel)));
          final Rect bell = tester.getRect(dashboardAction);
          expect(leftToRight ? pill.right <= bell.left : pill.left >= bell.right, isTrue, reason: 'the label comes before the bell');
          expect(pill.left, greaterThanOrEqualTo(0));
          expect(pill.right, lessThanOrEqualTo(MarketHarness.narrowPhone.width));
        });

        testWidgets('leaves the logo at least two thirds of its width on the narrowest phone at $textScale times the text size', (WidgetTester tester) async {
          await showDashboardBar(tester, storefrontsEnabled: false, locale: locale, textScale: textScale);
          final double logoWithoutLabel = tester.getSize(dashboardLogo).width;
          expect(logoWithoutLabel, greaterThan(0));

          await showDashboardBar(tester, storefrontsEnabled: true, locale: locale, textScale: textScale);

          expect(tester.getSize(dashboardLogo).width, greaterThanOrEqualTo(logoWithoutLabel * 2 / 3));
        });
      }

      testWidgets('keeps the gap between the label and the bell on the side of the bell, whichever way the language is read', (WidgetTester tester) async {
        await showDashboardBar(tester, storefrontsEnabled: true, locale: locale);

        final Rect pill = tester.getRect(pillOf(find.byType(MarketLabel)));
        final Rect bell = tester.getRect(dashboardAction);

        expect(leftToRight ? bell.left - pill.right : pill.left - bell.right, Dimensions.paddingSizeSmall);
      });

      testWidgets('has no label while storefronts are off, and the bell where it always was', (WidgetTester tester) async {
        await showDashboardBar(tester, storefrontsEnabled: false, locale: locale, textScale: 1.3);

        expect(find.byType(MarketLabel), findsNothing);
        expect(find.byIcon(CupertinoIcons.bell), findsOneWidget);
        expect(tester.getSize(dashboardLogo).width, greaterThan(90));
      });

      testWidgets('has the label exactly when the build has storefronts on', (WidgetTester tester) async {
        await showDashboardBar(tester, locale: locale);

        expect(find.byType(MarketLabel), StorefrontConfig.enabled ? findsOneWidget : findsNothing);
        expect(find.byIcon(CupertinoIcons.bell), findsOneWidget);
      });
    });

    group('the title area of the order list, in ${locale.languageCode}', () {
      for (final double textScale in <double>[1.0, 1.3, 2.0]) {
        testWidgets('has the label in front of the filter and clear of the title on the narrowest phone at $textScale times the text size', (WidgetTester tester) async {
          await showOrderList(tester, storefrontsEnabled: true, locale: locale, textScale: textScale);

          expect(tester.takeException(), isNull);
          expect(find.byType(MarketLabel), findsOneWidget);
          expect(find.text('SA · SAR'), findsOneWidget);
          final Rect pill = tester.getRect(pillOf(find.byType(MarketLabel)));
          final Rect filter = tester.getRect(orderListAction);
          final Rect title = tester.getRect(orderListTitle);
          expect(leftToRight ? pill.right <= filter.left : pill.left >= filter.right, isTrue, reason: 'the label comes before the filter');
          expect(leftToRight ? title.right <= pill.left : title.left >= pill.right, isTrue, reason: 'the label does not cover the title');
          expect(pill.left, greaterThanOrEqualTo(0));
          expect(pill.right, lessThanOrEqualTo(MarketHarness.narrowPhone.width));
        });
      }

      testWidgets('keeps the gap between the label and the filter on the side of the filter, whichever way the language is read', (WidgetTester tester) async {
        await showOrderList(tester, storefrontsEnabled: true, locale: locale);

        final Rect pill = tester.getRect(pillOf(find.byType(MarketLabel)));
        final Rect filter = tester.getRect(orderListAction);

        expect(leftToRight ? filter.left - pill.right : pill.left - filter.right, Dimensions.paddingSizeSmall);
      });

      testWidgets('has no label while storefronts are off, and the filter where it always was', (WidgetTester tester) async {
        await showOrderList(tester, storefrontsEnabled: false, locale: locale, textScale: 1.3);

        expect(find.byType(MarketLabel), findsNothing);
        expect(orderListAction, findsOneWidget);
      });

      testWidgets('has the label exactly when the build has storefronts on', (WidgetTester tester) async {
        await showOrderList(tester, locale: locale);

        expect(find.byType(MarketLabel), StorefrontConfig.enabled ? findsOneWidget : findsNothing);
        expect(orderListAction, findsOneWidget);
      });
    });
  }

  group('the label', () {
    testWidgets('grows with the text size of the phone up to one and three tenths, and no further', (WidgetTester tester) async {
      final Map<double, Size> sizes = <double, Size>{};
      for (final double textScale in <double>[1.0, 1.3, 2.0]) {
        await tester.pumpWidget(await MarketHarness.app(
          tester,
          textScale: textScale,
          home: Scaffold(body: Center(child: MarketLabel(marketController: market))),
        ));
        sizes[textScale] = tester.getSize(find.byType(MarketLabel));
      }

      expect(sizes[1.3]!.width, greaterThan(sizes[1.0]!.width));
      expect(sizes[2.0], sizes[1.3]);
    });
  });
}
