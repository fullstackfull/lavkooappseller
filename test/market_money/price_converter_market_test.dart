import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/features/splash/controllers/splash_controller.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/market_money.dart';
import 'package:syriacosmeticsmanger/features/storefront/storefront_config.dart';
import 'package:syriacosmeticsmanger/helper/price_converter.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

import 'support/money_store.dart';

/// What one call of the formatter is expected to write.
class _Check {
  const _Check(this.call, this.run, this.expected);

  final String call;
  final Object? Function(BuildContext context) run;
  final Object? expected;
}

/// A store as the config describes it, and what each call of the formatter writes for it, worked out by hand from the rules of the formatter: an amount is
/// multiplied by the shown currency's rate over the base currency's rate in `multi_currency`, rounded (or cut, for a withdrawal) to the decimal setting, which is
/// 1 when the config has none, and written with the symbol of the shown currency on the side the config names.
class _Store {
  const _Store(this.name, {required this.config, required this.shownCurrencyCode, required this.checks});

  final String name;
  final Map<String, dynamic> config;
  final String shownCurrencyCode;
  final List<_Check> checks;
}

Future<BuildContext> _contextOf(WidgetTester tester, _Store store) async {
  final SplashController splash = await loadedSplashController(config: store.config, shownCurrencyCode: store.shownCurrencyCode);

  late BuildContext captured;
  await tester.pumpWidget(
    ChangeNotifierProvider<SplashController>.value(
      value: splash,
      child: Builder(
        builder: (BuildContext context) {
          captured = context;
          return const SizedBox();
        },
      ),
    ),
  );

  return captured;
}

Future<SharedPreferences> _preferencesWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

final List<_Store> _stores = <_Store>[
  _Store(
    'one currency, symbol on the left, 2 decimals',
    config: moneyStoreConfig(
        currencyModel: 'single_currency', symbolPosition: 'left', decimals: 2, currencies: <Map<String, dynamic>>[moneyStoreCurrency(1, r'$', 'USD', 1)]),
    shownCurrencyCode: 'USD',
    checks: <_Check>[
      _Check('currencyMark', (BuildContext c) => PriceConverter.currencyMark(c), r'$'),
      _Check('convertPrice 1234.5', (BuildContext c) => PriceConverter.convertPrice(c, 1234.5), r'$1,234.50'),
      _Check('convertPrice 1234567.891', (BuildContext c) => PriceConverter.convertPrice(c, 1234567.891), r'$1,234,567.89'),
      _Check('convertPrice 0', (BuildContext c) => PriceConverter.convertPrice(c, 0), r'$0.00'),
      _Check('convertPrice 100 less 10 percent', (BuildContext c) => PriceConverter.convertPrice(c, 100, discount: 10, discountType: 'percent'), r'$90.00'),
      _Check('convertPrice 100 less 15.5 flat', (BuildContext c) => PriceConverter.convertPrice(c, 100, discount: 15.5, discountType: 'flat'), r'$84.50'),
      _Check('convertPriceForWithdraw 1234.569', (BuildContext c) => PriceConverter.convertPriceForWithdraw(c, 1234.569), r'$1,234.56'),
      _Check('convertPriceWithoutSymbol 1234.5', (BuildContext c) => PriceConverter.convertPriceWithoutSymbol(c, 1234.5), '1234.50'),
      _Check('convertPriceWithoutSymbol 1234.5678', (BuildContext c) => PriceConverter.convertPriceWithoutSymbol(c, 1234.5678), '1234.57'),
      _Check('convertPriceWithoutSymbolForWithdraw 1234.569', (BuildContext c) => PriceConverter.convertPriceWithoutSymbolForWithdraw(c, 1234.569), '1234.56'),
      _Check('convertAmount 10.456', (BuildContext c) => PriceConverter.convertAmount(10.456, c), 10.46),
      _Check('reverseConvertPriceWithoutSymbol 12.5', (BuildContext c) => PriceConverter.reverseConvertPriceWithoutSymbol(c, 12.5), '12.5'),
      _Check('reverseConvertPriceWithoutSymbol 90 plus 10 flat',
          (BuildContext c) => PriceConverter.reverseConvertPriceWithoutSymbol(c, 90, discount: 10, discountType: 'flat'), '100.0'),
      _Check('reverseConvertPriceWithoutSymbol null', (BuildContext c) => PriceConverter.reverseConvertPriceWithoutSymbol(c, null), '0.00'),
      _Check('discountCalculationWithOutSymbol 10 percent of 200', (BuildContext c) => PriceConverter.discountCalculationWithOutSymbol(c, 200, 10, 'percent'),
          '20.00'),
      _Check('discountCalculationWithOutSymbol 10 amount', (BuildContext c) => PriceConverter.discountCalculationWithOutSymbol(c, 200, 10, 'amount'), '10.00'),
      _Check('discountCalculationWithOutSymbol 1.234 amount', (BuildContext c) => PriceConverter.discountCalculationWithOutSymbol(c, 200, 1.234, 'amount'),
          '1.23'),
      _Check('discountCalculation 10 percent of 200', (BuildContext c) => PriceConverter.discountCalculation(c, 200, 10, 'percent'), r'$ 20.00'),
      _Check('getUnitCurrency 1234.5', (BuildContext c) => PriceConverter.getUnitCurrency(c, 1234.5), r'$1,234.50'),
      _Check('percentageCalculation 12.5 flat', (BuildContext c) => PriceConverter.percentageCalculation(c, 100, 12.5, 'flat'), r'-$12.50'),
      _Check('percentageCalculation 12.5 percent', (BuildContext c) => PriceConverter.percentageCalculation(c, 100, 12.5, 'percent'), '-12.5 %'),
    ],
  ),
  _Store(
    'one currency, symbol on the right, 3 decimals',
    config: moneyStoreConfig(
        currencyModel: 'single_currency', symbolPosition: 'right', decimals: 3, currencies: <Map<String, dynamic>>[moneyStoreCurrency(1, '£', 'GBP', 1)]),
    shownCurrencyCode: 'GBP',
    checks: <_Check>[
      _Check('currencyMark', (BuildContext c) => PriceConverter.currencyMark(c), '£'),
      _Check('convertPrice 1234.5', (BuildContext c) => PriceConverter.convertPrice(c, 1234.5), '1,234.500£'),
      _Check('convertPriceForWithdraw 1234.5699', (BuildContext c) => PriceConverter.convertPriceForWithdraw(c, 1234.5699), '1,234.569£'),
      _Check('convertPriceWithoutSymbol 1234.5', (BuildContext c) => PriceConverter.convertPriceWithoutSymbol(c, 1234.5), '1234.500'),
      _Check('getUnitCurrency 1234.5', (BuildContext c) => PriceConverter.getUnitCurrency(c, 1234.5), '1,234.500£'),
      _Check('discountCalculation 10 percent of 200', (BuildContext c) => PriceConverter.discountCalculation(c, 200, 10, 'percent'), '£ 20.00'),
      _Check('discountCalculationWithOutSymbol 1.234 amount', (BuildContext c) => PriceConverter.discountCalculationWithOutSymbol(c, 200, 1.234, 'amount'),
          '1.23'),
    ],
  ),
  _Store(
    'one currency, no decimal setting, which the formatter reads as 1',
    config:
        moneyStoreConfig(currencyModel: 'single_currency', symbolPosition: 'left', currencies: <Map<String, dynamic>>[moneyStoreCurrency(1, r'$', 'USD', 1)]),
    shownCurrencyCode: 'USD',
    checks: <_Check>[
      _Check('currencyMark', (BuildContext c) => PriceConverter.currencyMark(c), r'$'),
      _Check('convertPrice 1234.56', (BuildContext c) => PriceConverter.convertPrice(c, 1234.56), r'$1,234.6'),
      _Check('convertPriceWithoutSymbol 1234.56', (BuildContext c) => PriceConverter.convertPriceWithoutSymbol(c, 1234.56), '1234.6'),
      _Check('getUnitCurrency 1234.56', (BuildContext c) => PriceConverter.getUnitCurrency(c, 1234.56), r'$1,234.6'),
    ],
  ),
  _Store(
    'one currency, 0 decimals',
    config: moneyStoreConfig(
        currencyModel: 'single_currency', symbolPosition: 'left', decimals: 0, currencies: <Map<String, dynamic>>[moneyStoreCurrency(1, r'$', 'USD', 1)]),
    shownCurrencyCode: 'USD',
    checks: <_Check>[
      _Check('currencyMark', (BuildContext c) => PriceConverter.currencyMark(c), r'$'),
      _Check('convertPrice 1234.5', (BuildContext c) => PriceConverter.convertPrice(c, 1234.5), r'$1,235'),
      _Check('convertPriceForWithdraw 1234.9', (BuildContext c) => PriceConverter.convertPriceForWithdraw(c, 1234.9), r'$1,234'),
      _Check('convertPriceWithoutSymbol 1234.5', (BuildContext c) => PriceConverter.convertPriceWithoutSymbol(c, 1234.5), '1235'),
    ],
  ),
  _Store(
    'several currencies, shown in one worth 3.75 of the base, symbol on the right, 2 decimals',
    config: moneyStoreConfig(
      currencyModel: 'multi_currency',
      symbolPosition: 'right',
      decimals: 2,
      currencies: <Map<String, dynamic>>[moneyStoreCurrency(1, r'$', 'USD', 1), moneyStoreCurrency(2, 'SR', 'SAR', 3.75)],
    ),
    shownCurrencyCode: 'SAR',
    checks: <_Check>[
      _Check('currencyMark', (BuildContext c) => PriceConverter.currencyMark(c), 'SR'),
      _Check('convertPrice 1234.5', (BuildContext c) => PriceConverter.convertPrice(c, 1234.5), '4,629.38SR'),
      _Check('convertPrice 100 less 10 percent', (BuildContext c) => PriceConverter.convertPrice(c, 100, discount: 10, discountType: 'percent'), '337.50SR'),
      _Check('convertPriceForWithdraw 1234.5', (BuildContext c) => PriceConverter.convertPriceForWithdraw(c, 1234.5), '4,629.37SR'),
      _Check('convertPriceWithoutSymbol 100', (BuildContext c) => PriceConverter.convertPriceWithoutSymbol(c, 100), '375.00'),
      _Check('convertPriceWithoutSymbolForWithdraw 1234.5', (BuildContext c) => PriceConverter.convertPriceWithoutSymbolForWithdraw(c, 1234.5), '4629.37'),
      _Check('convertAmount 100', (BuildContext c) => PriceConverter.convertAmount(100, c), 375.0),
      _Check('reverseConvertPriceWithoutSymbol 375', (BuildContext c) => PriceConverter.reverseConvertPriceWithoutSymbol(c, 375), '100.0'),
      _Check('reverseConvertPriceWithoutSymbol 375 plus 25 flat',
          (BuildContext c) => PriceConverter.reverseConvertPriceWithoutSymbol(c, 375, discount: 25, discountType: 'flat'), '125.0'),
      _Check('reverseConvertPriceWithoutSymbol null', (BuildContext c) => PriceConverter.reverseConvertPriceWithoutSymbol(c, null), '0.00'),
      _Check('discountCalculationWithOutSymbol 10 percent of 200', (BuildContext c) => PriceConverter.discountCalculationWithOutSymbol(c, 200, 10, 'percent'),
          '75.00'),
      _Check('discountCalculationWithOutSymbol 10 percent of 200, not converted',
          (BuildContext c) => PriceConverter.discountCalculationWithOutSymbol(c, 200, 10, 'percent', convertCurrency: false), '20.00'),
      _Check('discountCalculationWithOutSymbol 10 amount', (BuildContext c) => PriceConverter.discountCalculationWithOutSymbol(c, 200, 10, 'amount'), '10.00'),
      _Check('discountCalculation 10 percent of 200', (BuildContext c) => PriceConverter.discountCalculation(c, 200, 10, 'percent'), 'SR 20.00'),
      _Check('getUnitCurrency 1234.5', (BuildContext c) => PriceConverter.getUnitCurrency(c, 1234.5), '1,234.50SR'),
      _Check('percentageCalculation 12.5 flat', (BuildContext c) => PriceConverter.percentageCalculation(c, 100, 12.5, 'flat'), '-46.88SR'),
    ],
  ),
  _Store(
    'several currencies, the base worth 2 and the shown one worth 3, symbol on the left',
    config: moneyStoreConfig(
      currencyModel: 'multi_currency',
      symbolPosition: 'left',
      decimals: 2,
      currencies: <Map<String, dynamic>>[moneyStoreCurrency(1, r'$', 'USD', 2), moneyStoreCurrency(2, '€', 'EUR', 3)],
    ),
    shownCurrencyCode: 'EUR',
    checks: <_Check>[
      _Check('currencyMark', (BuildContext c) => PriceConverter.currencyMark(c), '€'),
      _Check('convertPrice 100', (BuildContext c) => PriceConverter.convertPrice(c, 100), '€150.00'),
      _Check('convertPriceWithoutSymbol 100', (BuildContext c) => PriceConverter.convertPriceWithoutSymbol(c, 100), '150.00'),
      _Check('reverseConvertPriceWithoutSymbol 150', (BuildContext c) => PriceConverter.reverseConvertPriceWithoutSymbol(c, 150), '100.0'),
    ],
  ),
];

/// The one money formatter of the app, run through its real calls with a real [SplashController] that holds the config of a store.
///
/// While storefronts are off, or no GCC market is stored, every call must write what it has always written: the symbol, position, decimals and exchange rate
/// of the shared config. In a market the same calls write the money of the market and multiply by no exchange rate.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    MarketMoney.lookUpWith(null);
    await GetIt.instance.reset();
  });

  void expectEveryCallToWriteWhatItAlwaysWrote() {
    for (final _Store store in _stores) {
      testWidgets(store.name, (WidgetTester tester) async {
        final BuildContext context = await _contextOf(tester, store);

        for (final _Check check in store.checks) {
          expect(check.run(context), check.expected, reason: check.call);
        }
      });
    }
  }

  group('with no market stored', () {
    expectEveryCallToWriteWhatItAlwaysWrote();
  });

  group('with storefronts off and a market stored', () {
    setUp(() async {
      GetIt.instance.registerSingleton<SharedPreferences>(await _preferencesWith(<String, Object>{AppConstants.storefrontCountry: 'KW'}));
    });

    expectEveryCallToWriteWhatItAlwaysWrote();
  }, skip: StorefrontConfig.enabled ? 'the flag is on in this run' : false);

  group('with storefronts on and no GCC market stored', () {
    for (final Map<String, Object> stored in <Map<String, Object>>[
      <String, Object>{},
      <String, Object>{AppConstants.storefrontCountry: ''},
      <String, Object>{AppConstants.storefrontCountry: 'US'},
      <String, Object>{AppConstants.storefrontCountry: MarketScope.allMarkets.name},
    ]) {
      group('stored $stored', () {
        setUp(() async {
          final SharedPreferences preferences = await _preferencesWith(stored);
          MarketMoney.lookUpWith(() => MarketMoney.fromPreferences(preferences));
        });

        expectEveryCallToWriteWhatItAlwaysWrote();
      });
    }
  });

  group('in a market', () {
    final _Store multiCurrencyOnTheRight = _stores.firstWhere((_Store store) => store.name.startsWith('several currencies, shown in one worth 3.75'));
    final _Store singleCurrencyOnTheLeft = _stores.first;

    void work(MarketScope scope) => MarketMoney.lookUpWith(() => MarketMoney.forScope(scope));

    Future<void> expectChecks(WidgetTester tester, _Store store, List<_Check> checks) async {
      final BuildContext context = await _contextOf(tester, store);

      for (final _Check check in checks) {
        expect(check.run(context), check.expected, reason: check.call);
      }
    }

    testWidgets('Kuwait: every call writes dinars with three decimals and multiplies by no exchange rate, in a store with several currencies',
        (WidgetTester tester) async {
      work(MarketScope.kuwait);

      await expectChecks(tester, multiCurrencyOnTheRight, <_Check>[
        _Check('convertPrice 1234.5', (BuildContext c) => PriceConverter.convertPrice(c, 1234.5), '1,234.500 KWD'),
        _Check(
            'convertPrice 100 less 10 percent', (BuildContext c) => PriceConverter.convertPrice(c, 100, discount: 10, discountType: 'percent'), '90.000 KWD'),
        _Check('convertPriceForWithdraw 4.35', (BuildContext c) => PriceConverter.convertPriceForWithdraw(c, 4.35), '4.350 KWD'),
        _Check('convertPriceForWithdraw 1234.5699', (BuildContext c) => PriceConverter.convertPriceForWithdraw(c, 1234.5699), '1,234.569 KWD'),
        _Check('convertPriceWithoutSymbol 100', (BuildContext c) => PriceConverter.convertPriceWithoutSymbol(c, 100), '100.000'),
        _Check('convertPriceWithoutSymbol 12.3456', (BuildContext c) => PriceConverter.convertPriceWithoutSymbol(c, 12.3456), '12.346'),
        _Check('convertPriceWithoutSymbolForWithdraw 4.35', (BuildContext c) => PriceConverter.convertPriceWithoutSymbolForWithdraw(c, 4.35), '4.350'),
        _Check('convertAmount 100.12345', (BuildContext c) => PriceConverter.convertAmount(100.12345, c), 100.123),
        _Check('reverseConvertPriceWithoutSymbol 375', (BuildContext c) => PriceConverter.reverseConvertPriceWithoutSymbol(c, 375), '375.0'),
        _Check('reverseConvertPriceWithoutSymbol 375 plus 25 flat',
            (BuildContext c) => PriceConverter.reverseConvertPriceWithoutSymbol(c, 375, discount: 25, discountType: 'flat'), '400.0'),
        _Check('reverseConvertPriceWithoutSymbol null', (BuildContext c) => PriceConverter.reverseConvertPriceWithoutSymbol(c, null), '0.00'),
        _Check('discountCalculationWithOutSymbol 10 percent of 200', (BuildContext c) => PriceConverter.discountCalculationWithOutSymbol(c, 200, 10, 'percent'),
            '20.000'),
        _Check('discountCalculationWithOutSymbol 10 percent of 200, not converted',
            (BuildContext c) => PriceConverter.discountCalculationWithOutSymbol(c, 200, 10, 'percent', convertCurrency: false), '20.000'),
        _Check('discountCalculationWithOutSymbol 1.234 amount', (BuildContext c) => PriceConverter.discountCalculationWithOutSymbol(c, 200, 1.234, 'amount'),
            '1.234'),
        _Check('discountCalculation 10 percent of 200', (BuildContext c) => PriceConverter.discountCalculation(c, 200, 10, 'percent'), 'KWD 20.000'),
        _Check('getUnitCurrency 1234.5', (BuildContext c) => PriceConverter.getUnitCurrency(c, 1234.5), '1,234.500 KWD'),
        _Check('percentageCalculation 12.5 flat', (BuildContext c) => PriceConverter.percentageCalculation(c, 100, 12.5, 'flat'), '-12.500 KWD'),
        _Check('percentageCalculation 12.5 percent', (BuildContext c) => PriceConverter.percentageCalculation(c, 100, 12.5, 'percent'), '-12.5 %'),
        _Check('currencyMark', (BuildContext c) => PriceConverter.currencyMark(c), 'KWD'),
      ]);
    });

    testWidgets('Kuwait: a discount is taken off before the amount is written, by each function that takes one, and the amount is not converted',
        (WidgetTester tester) async {
      work(MarketScope.kuwait);

      await expectChecks(tester, multiCurrencyOnTheRight, <_Check>[
        _Check('convertPriceWithoutSymbol 200 less 10 percent',
            (BuildContext c) => PriceConverter.convertPriceWithoutSymbol(c, 200, discount: 10, discountType: 'percent'), '180.000'),
        _Check('convertPriceWithoutSymbol 200 less 15.5 flat',
            (BuildContext c) => PriceConverter.convertPriceWithoutSymbol(c, 200, discount: 15.5, discountType: 'flat'), '184.500'),
        _Check('convertPriceWithoutSymbolForWithdraw 200 less 10 percent',
            (BuildContext c) => PriceConverter.convertPriceWithoutSymbolForWithdraw(c, 200, discount: 10, discountType: 'percent'), '180.000'),
        _Check('convertPriceWithoutSymbolForWithdraw 200 less 15.5 flat',
            (BuildContext c) => PriceConverter.convertPriceWithoutSymbolForWithdraw(c, 200, discount: 15.5, discountType: 'flat'), '184.500'),
        _Check('convertPriceForWithdraw 200 less 10 percent',
            (BuildContext c) => PriceConverter.convertPriceForWithdraw(c, 200, discount: 10, discountType: 'percent'), '180.000 KWD'),
        _Check('convertPriceForWithdraw 200 less 15.5 flat',
            (BuildContext c) => PriceConverter.convertPriceForWithdraw(c, 200, discount: 15.5, discountType: 'flat'), '184.500 KWD'),
      ]);
    });

    testWidgets('Kuwait: a discount that leaves a third decimal is rounded by the functions that round and cut by the ones that cut', (WidgetTester tester) async {
      work(MarketScope.kuwait);

      await expectChecks(tester, multiCurrencyOnTheRight, <_Check>[
        _Check('convertPriceWithoutSymbol 200 less 0.0004 flat',
            (BuildContext c) => PriceConverter.convertPriceWithoutSymbol(c, 200, discount: 0.0004, discountType: 'flat'), '200.000'),
        _Check('convertPriceWithoutSymbolForWithdraw 200 less 0.0004 flat',
            (BuildContext c) => PriceConverter.convertPriceWithoutSymbolForWithdraw(c, 200, discount: 0.0004, discountType: 'flat'), '199.999'),
        _Check('convertPriceForWithdraw 200 less 0.0004 flat',
            (BuildContext c) => PriceConverter.convertPriceForWithdraw(c, 200, discount: 0.0004, discountType: 'flat'), '199.999 KWD'),
      ]);
    });

    testWidgets('Kuwait: the position of the mark is the one the config gives the symbol, and it is on the left in a store that puts the symbol there',
        (WidgetTester tester) async {
      work(MarketScope.kuwait);

      await expectChecks(tester, singleCurrencyOnTheLeft, <_Check>[
        _Check('convertPrice 1234.5', (BuildContext c) => PriceConverter.convertPrice(c, 1234.5), 'KWD 1,234.500'),
        _Check('convertPriceForWithdraw 1234.5699', (BuildContext c) => PriceConverter.convertPriceForWithdraw(c, 1234.5699), 'KWD 1,234.569'),
        _Check('getUnitCurrency 1234.5', (BuildContext c) => PriceConverter.getUnitCurrency(c, 1234.5), 'KWD 1,234.500'),
        _Check('percentageCalculation 12.5 flat', (BuildContext c) => PriceConverter.percentageCalculation(c, 100, 12.5, 'flat'), '-KWD 12.500'),
      ]);
    });

    testWidgets('Saudi Arabia: riyals with two decimals, and a discount typed with three is written with two', (WidgetTester tester) async {
      work(MarketScope.saudiArabia);

      await expectChecks(tester, multiCurrencyOnTheRight, <_Check>[
        _Check('convertPrice 1234.5', (BuildContext c) => PriceConverter.convertPrice(c, 1234.5), '1,234.50 SAR'),
        _Check('convertPriceWithoutSymbol 12.3456', (BuildContext c) => PriceConverter.convertPriceWithoutSymbol(c, 12.3456), '12.35'),
        _Check('convertAmount 100.12345', (BuildContext c) => PriceConverter.convertAmount(100.12345, c), 100.12),
        _Check('discountCalculationWithOutSymbol 1.234 amount', (BuildContext c) => PriceConverter.discountCalculationWithOutSymbol(c, 200, 1.234, 'amount'),
            '1.23'),
        _Check('convertPriceForWithdraw 4.35', (BuildContext c) => PriceConverter.convertPriceForWithdraw(c, 4.35), '4.35 SAR'),
      ]);
    });

    testWidgets('each of the six markets writes its own code and decimals', (WidgetTester tester) async {
      const Map<MarketScope, String> expected = <MarketScope, String>{
        MarketScope.saudiArabia: 'SAR 1,234.50',
        MarketScope.unitedArabEmirates: 'AED 1,234.50',
        MarketScope.kuwait: 'KWD 1,234.500',
        MarketScope.qatar: 'QAR 1,234.50',
        MarketScope.bahrain: 'BHD 1,234.500',
        MarketScope.oman: 'OMR 1,234.500',
      };
      final BuildContext context = await _contextOf(tester, singleCurrencyOnTheLeft);

      for (final MapEntry<MarketScope, String> market in expected.entries) {
        work(market.key);

        expect(PriceConverter.convertPrice(context, 1234.5), market.value, reason: market.key.name);
        expect(PriceConverter.getUnitCurrency(context, 1234.5), market.value, reason: market.key.name);
        expect(PriceConverter.currencyMark(context), market.key.currencyCode, reason: market.key.name);
      }
    });

    testWidgets('the symbol and the rates of the config play no part: a store whose config lists no currency still writes the market',
        (WidgetTester tester) async {
      work(MarketScope.bahrain);
      final _Store withoutCurrencies = _Store(
        'no currency listed',
        config: moneyStoreConfig(currencyModel: 'multi_currency', symbolPosition: 'right', decimals: 2, currencies: <Map<String, dynamic>>[]),
        shownCurrencyCode: 'SAR',
        checks: const <_Check>[],
      );
      final BuildContext context = await _contextOf(tester, withoutCurrencies);

      expect(PriceConverter.convertPrice(context, 1234.5), '1,234.500 BHD');
      expect(PriceConverter.convertPriceWithoutSymbol(context, 12.3456), '12.346');
      expect(PriceConverter.convertAmount(10, context), 10.0);
      expect(PriceConverter.reverseConvertPriceWithoutSymbol(context, 10), '10.0');
      expect(PriceConverter.discountCalculationWithOutSymbol(context, 200, 10, 'percent'), '20.000');
      expect(PriceConverter.discountCalculation(context, 200, 10, 'percent'), 'BHD 20.000');
      expect(PriceConverter.currencyMark(context), 'BHD');
    });

    testWidgets('a store with the amounts of several currencies writes the same money as a store with one', (WidgetTester tester) async {
      work(MarketScope.oman);
      final BuildContext several = await _contextOf(tester, multiCurrencyOnTheRight);
      final String inSeveral = PriceConverter.convertPriceWithoutSymbol(several, 1234.5678);

      final BuildContext single = await _contextOf(tester, singleCurrencyOnTheLeft);
      final String inOne = PriceConverter.convertPriceWithoutSymbol(single, 1234.5678);

      expect(inSeveral, '1234.568');
      expect(inOne, inSeveral);
    });
  });
}
