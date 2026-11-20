import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/features/storefront/controllers/seller_market_controller.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/storefront_config.dart';
import 'package:syriacosmeticsmanger/features/storefront/storefront_dependencies.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

import 'support/market_support.dart';

/// The controller of the market holds the market the seller works in, changes it, and says so. Changing it is the one moment the
/// screens drop what belonged to the market left, so what counts here is what happens, and in which order.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('while storefronts are on', () {
    test('it starts in the market the seller chose, and in Saudi Arabia when none was chosen', () async {
      final SharedPreferences chosen = await preferencesWith(<String, Object>{AppConstants.storefrontCountry: 'KW'});
      expect(controllerOn(chosen).market, MarketScope.kuwait);

      final SharedPreferences nothing = await preferencesWith();
      expect(controllerOn(nothing).market, MarketScope.saudiArabia);
    });

    test('it offers the six markets of the GCC and not All Markets', () async {
      final SellerMarketController controller = controllerOn(await preferencesWith());

      expect(controller.markets, <MarketScope>[
        MarketScope.saudiArabia,
        MarketScope.unitedArabEmirates,
        MarketScope.kuwait,
        MarketScope.qatar,
        MarketScope.bahrain,
        MarketScope.oman,
      ]);
    });

    test('choosing a market saves it, tells the screens, and only then hands over to the switch handler', () async {
      final SharedPreferences preferences = await preferencesWith();
      final List<String> events = <String>[];
      late final SellerMarketController controller;
      controller = controllerOn(
        preferences,
        onMarketSwitched: () async => events.add('handled with ${preferences.getString(AppConstants.storefrontCountry)}'),
      )..addListener(() => events.add('told ${controller.market.name}'));

      final bool switched = await controller.choose(MarketScope.kuwait);

      expect(switched, isTrue);
      expect(controller.market, MarketScope.kuwait);
      expect(preferences.getString(AppConstants.storefrontCountry), 'KW');
      expect(events, <String>['told kuwait', 'handled with KW']);
    });

    test('choosing the market already worked in saves it and switches nothing', () async {
      final SharedPreferences preferences = await preferencesWith();
      int handled = 0;
      int told = 0;
      final SellerMarketController controller = controllerOn(preferences, onMarketSwitched: () async => handled++)
        ..addListener(() => told++);

      final bool chosen = await controller.choose(MarketScope.saudiArabia);

      expect(chosen, isTrue);
      expect(preferences.getString(AppConstants.storefrontCountry), 'SA');
      expect(handled, 0);
      expect(told, 0);
    });

    test('All Markets cannot be chosen: nothing is saved, told or handed over', () async {
      final SharedPreferences preferences = await preferencesWith();
      int handled = 0;
      int told = 0;
      final SellerMarketController controller = controllerOn(preferences, onMarketSwitched: () async => handled++)
        ..addListener(() => told++);

      final bool chosen = await controller.choose(MarketScope.allMarkets);

      expect(chosen, isFalse);
      expect(controller.market, MarketScope.saudiArabia);
      expect(preferences.containsKey(AppConstants.storefrontCountry), isFalse);
      expect(handled, 0);
      expect(told, 0);
    });

    test('a market that could not be saved is not switched to', () async {
      int handled = 0;
      int told = 0;
      final SellerMarketController controller = controllerOn(RefusingPreferences(), onMarketSwitched: () async => handled++)
        ..addListener(() => told++);

      final bool chosen = await controller.choose(MarketScope.oman);

      expect(chosen, isFalse);
      expect(controller.market, MarketScope.saudiArabia);
      expect(handled, 0);
      expect(told, 0);
    });

    test('choosing is complete only when the switch handler is, so a caller can wait for the screens', () async {
      final SharedPreferences preferences = await preferencesWith();
      final Completer<void> reloaded = Completer<void>();
      final SellerMarketController controller = controllerOn(preferences, onMarketSwitched: () => reloaded.future);
      bool complete = false;

      final Future<bool> choosing = controller.choose(MarketScope.qatar).whenComplete(() => complete = true);
      await pumpEventQueue();
      expect(complete, isFalse);

      reloaded.complete();

      expect(await choosing, isTrue);
    });
  });

  group('two switches in a row', () {
    test('are handled one after the other, so that the newest market is the last whose screens are loaded', () async {
      final SharedPreferences preferences = await preferencesWith();
      final List<Completer<void>> handlers = <Completer<void>>[];
      final List<String> events = <String>[];
      final SellerMarketController controller = controllerOn(
        preferences,
        onMarketSwitched: () {
          final int number = handlers.length + 1;
          final Completer<void> handler = Completer<void>();
          handlers.add(handler);
          events.add('start $number');
          return handler.future.whenComplete(() => events.add('end $number'));
        },
      );

      final Future<bool> toKuwait = controller.choose(MarketScope.kuwait);
      final Future<bool> toOman = controller.choose(MarketScope.oman);
      await pumpEventQueue();

      expect(controller.market, MarketScope.oman);
      expect(preferences.getString(AppConstants.storefrontCountry), 'OM');
      expect(events, <String>['start 1']);

      handlers[0].complete();
      await pumpEventQueue();
      expect(events, <String>['start 1', 'end 1', 'start 2']);

      handlers[1].complete();
      expect(await Future.wait<bool>(<Future<bool>>[toKuwait, toOman]), <bool>[true, true]);
      expect(events, <String>['start 1', 'end 1', 'start 2', 'end 2']);
    });

    test('go on after one whose screens could not be loaded, which its own caller hears of', () async {
      final SharedPreferences preferences = await preferencesWith();
      final Completer<void> firstReload = Completer<void>();
      int handled = 0;
      final SellerMarketController controller = controllerOn(
        preferences,
        onMarketSwitched: () {
          handled++;
          return handled == 1 ? firstReload.future : Future<void>.value();
        },
      );

      final Future<bool> toKuwait = controller.choose(MarketScope.kuwait);
      final Future<void> kuwaitFailed = expectLater(toKuwait, throwsStateError);
      final Future<bool> toOman = controller.choose(MarketScope.oman);
      await pumpEventQueue();
      firstReload.completeError(StateError('the reload of the first market failed'));
      await kuwaitFailed;

      expect(await toOman, isTrue);
      expect(handled, 2);
      expect(controller.market, MarketScope.oman);
    });
  });

  group('while storefronts are off', () {
    test('it works in no market and refuses every choice without writing, telling or handing over', () async {
      final SharedPreferences preferences = await preferencesWith(<String, Object>{AppConstants.storefrontCountry: 'AE'});
      int handled = 0;
      int told = 0;
      final SellerMarketController controller = controllerOn(preferences, enabled: false, onMarketSwitched: () async => handled++)
        ..addListener(() => told++);

      expect(controller.market, MarketScope.allMarkets);
      for (final MarketScope scope in MarketScope.gccMarkets) {
        expect(await controller.choose(scope), isFalse);
      }

      expect(controller.market, MarketScope.allMarkets);
      expect(preferences.getString(AppConstants.storefrontCountry), 'AE');
      expect(handled, 0);
      expect(told, 0);
    });
  });

  group('the container', () {
    Future<GetIt> locatorWith(Map<String, Object> stored) async {
      final GetIt locator = GetIt.asNewInstance();
      locator.registerSingleton<SharedPreferences>(await preferencesWith(stored));
      return locator;
    }

    test('registers nothing while storefronts are off', () async {
      final GetIt locator = await locatorWith(<String, Object>{});

      registerStorefrontDependencies(locator, enabled: false);

      expect(locator.isRegistered<SellerMarketController>(), isFalse);
    });

    test('left to itself it follows the build flag', () async {
      final GetIt locator = await locatorWith(<String, Object>{});

      registerStorefrontDependencies(locator);

      expect(locator.isRegistered<SellerMarketController>(), StorefrontConfig.enabled);
    });

    test('registers one controller for the whole app, from the market stored when it is first asked for', () async {
      final GetIt locator = await locatorWith(<String, Object>{AppConstants.storefrontCountry: 'AE'});

      registerStorefrontDependencies(locator, enabled: true);

      final SellerMarketController first = locator<SellerMarketController>();
      expect(first.market, MarketScope.unitedArabEmirates);
      expect(locator<SellerMarketController>(), same(first));
    });

    test('a switch with no screen on show saves the choice and has nothing to reload', () async {
      final GetIt locator = await locatorWith(<String, Object>{});
      registerStorefrontDependencies(locator, enabled: true);

      final bool switched = await locator<SellerMarketController>().choose(MarketScope.oman);

      expect(switched, isTrue);
      expect(locator<SharedPreferences>().getString(AppConstants.storefrontCountry), 'OM');
    });
  });
}
