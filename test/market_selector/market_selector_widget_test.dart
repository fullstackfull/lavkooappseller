import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/features/menu/screens/more_screen.dart';
import 'package:syriacosmeticsmanger/features/order/controllers/order_controller.dart';
import 'package:syriacosmeticsmanger/features/order/domain/services/order_service_interface.dart';
import 'package:syriacosmeticsmanger/features/order/screens/order_screen.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/customer_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/services/cart_service_interface.dart';
import 'package:syriacosmeticsmanger/features/profile/controllers/profile_controller.dart';
import 'package:syriacosmeticsmanger/features/profile/domain/services/profice_service_interface.dart';
import 'package:syriacosmeticsmanger/features/splash/controllers/splash_controller.dart';
import 'package:syriacosmeticsmanger/features/splash/domain/services/splash_service_interface.dart';
import 'package:syriacosmeticsmanger/features/storefront/controllers/seller_market_controller.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/storefront_config.dart';
import 'package:syriacosmeticsmanger/features/storefront/storefront_dependencies.dart';
import 'package:syriacosmeticsmanger/features/storefront/widgets/market_label.dart';
import 'package:syriacosmeticsmanger/features/storefront/widgets/market_labeled_action.dart';
import 'package:syriacosmeticsmanger/features/storefront/widgets/market_picker_sheet.dart';
import 'package:syriacosmeticsmanger/features/storefront/widgets/market_selector_tile.dart';
import 'package:syriacosmeticsmanger/localization/controllers/localization_controller.dart';
import 'package:syriacosmeticsmanger/theme/controllers/theme_controller.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

import 'support/harness.dart';
import 'support/market_support.dart';

class _UnusedSplashService extends Fake implements SplashServiceInterface {}

class _UnusedProfileService extends Fake implements ProfileServiceInterface {}

class _UnusedOrderService extends Fake implements OrderServiceInterface {}

class _UnusedCartService extends Fake implements CartServiceInterface {}

Map<String, dynamic> _language(Locale locale) =>
    jsonDecode(File('assets/language/${locale.languageCode}.json').readAsStringSync()) as Map<String, dynamic>;

const Map<MarketScope, String> _nameKeys = <MarketScope, String>{
  MarketScope.saudiArabia: 'market_saudi_arabia',
  MarketScope.unitedArabEmirates: 'market_united_arab_emirates',
  MarketScope.kuwait: 'market_kuwait',
  MarketScope.qatar: 'market_qatar',
  MarketScope.bahrain: 'market_bahrain',
  MarketScope.oman: 'market_oman',
};

/// What the seller sees and does to know and change the market: a tile with its name, the list of the six, and the label with its code
/// and currency. Each is run in English and in Arabic with the real language files, and a pick has to reach all three.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  late int switches;
  late SellerMarketController market;

  setUp(() async {
    preferences = await preferencesWith();
    switches = 0;
    market = controllerOn(preferences, onMarketSwitched: () async => switches++);
  });

  Future<void> showTileAndLabel(WidgetTester tester, {Locale locale = MarketHarness.english, double textScale = 1.0, bool darkTheme = false}) async {
    await tester.pumpWidget(await MarketHarness.app(
      tester,
      locale: locale,
      textScale: textScale,
      darkTheme: darkTheme,
      home: Scaffold(
        body: Column(
          children: [
            MarketSelectorTile(marketController: market),
            MarketLabel(marketController: market),
          ],
        ),
      ),
    ));
  }

  Finder inSheet(Finder finder) => find.descendant(of: find.byType(MarketPickerSheet), matching: finder);

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byType(MarketSelectorTile));
    await tester.pumpAndSettle();
  }

  for (final Locale locale in <Locale>[MarketHarness.english, MarketHarness.arabic]) {
    final Map<String, dynamic> words = _language(locale);
    String nameOf(MarketScope scope) => words[_nameKeys[scope]] as String;

    group('in ${locale.languageCode == 'en' ? 'English' : 'Arabic'}', () {
      testWidgets('the tile names the market the seller works in and the label gives its code and currency', (WidgetTester tester) async {
        await showTileAndLabel(tester, locale: locale);

        expect(find.text(words['market'] as String), findsOneWidget);
        expect(find.text(nameOf(MarketScope.saudiArabia)), findsOneWidget);
        expect(find.text('SA · SAR'), findsOneWidget);
      });

      testWidgets('the tile opens the six markets, in order, under a title, with the one worked in marked', (WidgetTester tester) async {
        await showTileAndLabel(tester, locale: locale);

        await openSheet(tester);

        expect(inSheet(find.text(words['select_market'] as String)), findsOneWidget);
        final List<double> tops = <double>[];
        for (final MarketScope scope in MarketScope.gccMarkets) {
          expect(inSheet(find.text(nameOf(scope))), findsOneWidget);
          expect(inSheet(find.text('${scope.countryCode} · ${scope.currencyCode}')), findsOneWidget);
          tops.add(tester.getTopLeft(inSheet(find.text(nameOf(scope)))).dy);
        }
        expect(tops, orderedEquals(<double>[...tops]..sort()));

        final Finder marks = inSheet(find.byIcon(Icons.check_circle));
        expect(marks, findsOneWidget);
        final Rect saudiRow = tester.getRect(find.ancestor(of: inSheet(find.text(nameOf(MarketScope.saudiArabia))), matching: find.byType(InkWell)).first);
        expect(saudiRow.contains(tester.getCenter(marks)), isTrue);

        final Finder selected = inSheet(find.byWidgetPredicate((Widget widget) => widget is Semantics && widget.properties.selected == true));
        expect(selected, findsOneWidget);
        expect(find.descendant(of: selected, matching: find.text(nameOf(MarketScope.saudiArabia))), findsOneWidget);
      });

      testWidgets('a pick closes the list, saves the market, and the tile and the label show it', (WidgetTester tester) async {
        await showTileAndLabel(tester, locale: locale);
        await openSheet(tester);

        await tester.tap(inSheet(find.text(nameOf(MarketScope.kuwait))));
        await tester.pumpAndSettle();

        expect(find.byType(MarketPickerSheet), findsNothing);
        expect(preferences.getString(AppConstants.storefrontCountry), 'KW');
        expect(market.market, MarketScope.kuwait);
        expect(switches, 1);
        expect(find.text(nameOf(MarketScope.kuwait)), findsOneWidget);
        expect(find.text(nameOf(MarketScope.saudiArabia)), findsNothing);
        expect(find.text('KW · KWD'), findsOneWidget);
        expect(find.text('SA · SAR'), findsNothing);
      });

      testWidgets('the list opened again marks the market picked, and no other', (WidgetTester tester) async {
        await showTileAndLabel(tester, locale: locale);
        await openSheet(tester);
        await tester.tap(inSheet(find.text(nameOf(MarketScope.oman))));
        await tester.pumpAndSettle();

        await openSheet(tester);

        final Finder marks = inSheet(find.byIcon(Icons.check_circle));
        expect(marks, findsOneWidget);
        final Rect omanRow = tester.getRect(find.ancestor(of: inSheet(find.text(nameOf(MarketScope.oman))), matching: find.byType(InkWell)).first);
        expect(omanRow.contains(tester.getCenter(marks)), isTrue);
      });

      testWidgets('picking the market already worked in closes the list and switches nothing', (WidgetTester tester) async {
        await showTileAndLabel(tester, locale: locale);
        await openSheet(tester);

        await tester.tap(inSheet(find.text(nameOf(MarketScope.saudiArabia))));
        await tester.pumpAndSettle();

        expect(find.byType(MarketPickerSheet), findsNothing);
        expect(switches, 0);
        expect(find.text('SA · SAR'), findsOneWidget);
      });

      for (final bool darkTheme in <bool>[false, true]) {
        testWidgets('the tile and the list fit the narrowest phone with large text${darkTheme ? ', in the dark theme' : ''}', (WidgetTester tester) async {
          MarketHarness.useScreen(tester, MarketHarness.narrowPhone);
          await showTileAndLabel(tester, locale: locale, textScale: 1.3, darkTheme: darkTheme);
          await openSheet(tester);

          expect(tester.takeException(), isNull);
          for (final MarketScope scope in MarketScope.gccMarkets) {
            final Rect name = tester.getRect(inSheet(find.text(nameOf(scope))));
            expect(name.left, greaterThanOrEqualTo(0));
            expect(name.right, lessThanOrEqualTo(MarketHarness.narrowPhone.width));
          }
        });
      }

      testWidgets('the mark sits at the end of its row, whichever way the language is read', (WidgetTester tester) async {
        await showTileAndLabel(tester, locale: locale);
        await openSheet(tester);

        final double name = tester.getCenter(inSheet(find.text(nameOf(MarketScope.saudiArabia)))).dx;
        final double mark = tester.getCenter(inSheet(find.byIcon(Icons.check_circle))).dx;

        expect(mark > name, locale == MarketHarness.english);
      });
    });
  }

  group('the label', () {
    testWidgets('follows every market the seller moves to', (WidgetTester tester) async {
      await showTileAndLabel(tester);

      for (final MarketScope scope in MarketScope.gccMarkets) {
        await tester.runAsync(() => market.choose(scope));
        await tester.pump();

        expect(find.text('${scope.countryCode} · ${scope.currencyCode}'), findsOneWidget);
      }
    });

    testWidgets('shows nothing when there is no market to show', (WidgetTester tester) async {
      market = controllerOn(preferences, enabled: false);
      await tester.pumpWidget(await MarketHarness.app(tester, home: Scaffold(body: Center(child: MarketLabel(marketController: market)))));

      expect(find.byType(Text), findsNothing);
    });
  });

  group('the labelled action', () {
    const ValueKey<String> actionKey = ValueKey<String>('action');

    Future<void> showAction(WidgetTester tester, {bool? enabled, Locale locale = MarketHarness.english}) async {
      await tester.pumpWidget(await MarketHarness.app(
        tester,
        locale: locale,
        home: Scaffold(
          body: Center(
            child: enabled == null
                ? const MarketLabeledAction(action: SizedBox(key: actionKey, width: 25, height: 25))
                : MarketLabeledAction(
                    enabled: enabled,
                    marketController: market,
                    action: const SizedBox(key: actionKey, width: 25, height: 25),
                  ),
          ),
        ),
      ));
    }

    testWidgets('is the action alone while storefronts are off', (WidgetTester tester) async {
      await showAction(tester, enabled: false);

      expect(find.byKey(actionKey), findsOneWidget);
      expect(find.byType(MarketLabel), findsNothing);
      expect(find.byType(Row), findsNothing);
    });

    testWidgets('is the action alone in a build made without the storefront flag', (WidgetTester tester) async {
      await showAction(tester);

      expect(find.byKey(actionKey), findsOneWidget);
      expect(find.byType(MarketLabel), findsNothing);
    }, skip: StorefrontConfig.enabled);

    for (final Locale locale in <Locale>[MarketHarness.english, MarketHarness.arabic]) {
      testWidgets('puts the label before the action while storefronts are on, in ${locale.languageCode}', (WidgetTester tester) async {
        await showAction(tester, enabled: true, locale: locale);

        final double label = tester.getCenter(find.byType(MarketLabel)).dx;
        final double action = tester.getCenter(find.byKey(actionKey)).dx;
        expect(find.text('SA · SAR'), findsOneWidget);
        expect(action > label, locale == MarketHarness.english);
      });
    }
  });

  group('the order list', () {
    setUp(() {
      GetIt.instance.registerSingleton<SharedPreferences>(preferences);
      registerStorefrontDependencies(GetIt.instance);
    });
    tearDown(GetIt.instance.reset);

    testWidgets('has the market label in its title area exactly when the build has storefronts on', (WidgetTester tester) async {
      await tester.pumpWidget(await MarketHarness.app(
        tester,
        providers: [
          ChangeNotifierProvider<ThemeController>(create: (_) => ThemeController(sharedPreferences: preferences)),
          ChangeNotifierProvider<OrderController>(create: (_) => OrderController(orderServiceInterface: _UnusedOrderService())),
          ChangeNotifierProvider<CustomerController>(create: (_) => CustomerController(cartServiceInterface: _UnusedCartService())),
        ],
        home: const OrderScreen(),
      ));
      await tester.pump();

      expect(find.text(_language(MarketHarness.english)['my_order'] as String), findsOneWidget);
      expect(find.byType(MarketLabel), StorefrontConfig.enabled ? findsOneWidget : findsNothing);
    });

    for (final Locale locale in <Locale>[MarketHarness.english, MarketHarness.arabic]) {
      testWidgets('keeps its title area whole on the narrowest phone with large text, in ${locale.languageCode}', (WidgetTester tester) async {
        MarketHarness.useScreen(tester, MarketHarness.narrowPhone);
        await tester.pumpWidget(await MarketHarness.app(
          tester,
          locale: locale,
          textScale: 1.3,
          providers: [
            ChangeNotifierProvider<ThemeController>(create: (_) => ThemeController(sharedPreferences: preferences)),
            ChangeNotifierProvider<OrderController>(create: (_) => OrderController(orderServiceInterface: _UnusedOrderService())),
            ChangeNotifierProvider<CustomerController>(create: (_) => CustomerController(cartServiceInterface: _UnusedCartService())),
          ],
          home: const OrderScreen(),
        ));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text(_language(locale)['my_order'] as String), findsOneWidget);
      });
    }
  });

  group('the more screen', () {
    Future<void> showMoreScreen(WidgetTester tester, {bool? storefrontsEnabled}) async {
      MarketHarness.useScreen(tester, MarketHarness.phone);
      await tester.pumpWidget(await MarketHarness.app(
        tester,
        providers: [
          ChangeNotifierProvider<ThemeController>(create: (_) => ThemeController(sharedPreferences: preferences)),
          ChangeNotifierProvider<LocalizationController>(create: (_) => LocalizationController(sharedPreferences: preferences)),
          ChangeNotifierProvider<SplashController>(create: (_) => SplashController(serviceInterface: _UnusedSplashService())),
          ChangeNotifierProvider<ProfileController>(create: (_) => ProfileController(profileServiceInterface: _UnusedProfileService())),
        ],
        home: storefrontsEnabled == null ? const MoreScreen() : MoreScreen(storefrontsEnabled: storefrontsEnabled),
      ));
    }

    setUp(() => GetIt.instance.registerSingleton<SellerMarketController>(market));
    tearDown(GetIt.instance.reset);

    testWidgets('has no market tile while storefronts are off', (WidgetTester tester) async {
      await showMoreScreen(tester, storefrontsEnabled: false);

      expect(find.byType(MarketSelectorTile), findsNothing);
      expect(find.text(_language(MarketHarness.english)['market'] as String), findsNothing);
      expect(find.text(_language(MarketHarness.english)['shop_and_account'] as String), findsOneWidget);
    });

    testWidgets('has no market tile in a build made without the storefront flag', (WidgetTester tester) async {
      await showMoreScreen(tester);

      expect(find.byType(MarketSelectorTile), findsNothing);
    }, skip: StorefrontConfig.enabled);

    testWidgets('shows the tile above its first section while storefronts are on, and the tile opens the markets', (WidgetTester tester) async {
      await showMoreScreen(tester, storefrontsEnabled: true);

      final String firstSection = _language(MarketHarness.english)['shop_and_account'] as String;
      expect(find.byType(MarketSelectorTile), findsOneWidget);
      expect(tester.getTopLeft(find.byType(MarketSelectorTile)).dy, lessThan(tester.getTopLeft(find.text(firstSection)).dy));

      await tester.tap(find.byType(MarketSelectorTile));
      await tester.pumpAndSettle();
      expect(find.byType(MarketPickerSheet), findsOneWidget);
    });

    testWidgets('picks up the market from the container, as it is registered there', (WidgetTester tester) async {
      await GetIt.instance.reset();
      GetIt.instance.registerSingleton<SharedPreferences>(preferences);
      registerStorefrontDependencies(GetIt.instance, enabled: true);
      await preferences.setString(AppConstants.storefrontCountry, 'QA');

      await showMoreScreen(tester, storefrontsEnabled: true);

      expect(find.text(_language(MarketHarness.english)['market_qatar'] as String), findsOneWidget);
    });
  });
}
