import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/market_money.dart';
import 'package:syriacosmeticsmanger/features/storefront/storefront_config.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

Future<SharedPreferences> _preferencesWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

MarketMoney _moneyOf(MarketScope scope) => MarketMoney.forScope(scope)!;

/// What is in a field after [keystrokes] were typed into it one after the other.
String _typed(TextInputFormatter formatter, String keystrokes) {
  TextEditingValue value = TextEditingValue.empty;
  for (final String keystroke in keystrokes.split('')) {
    final String text = value.text + keystroke;
    value = formatter.formatEditUpdate(value, TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)));
  }
  return value.text;
}

TextEditingValue _pasted(TextInputFormatter formatter, String text) =>
    formatter.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    MarketMoney.lookUpWith(null);
    await GetIt.instance.reset();
  });

  group('the money of a market', () {
    test('is the currency code and the decimals of the scope, for each of the six markets', () {
      const Map<MarketScope, ({String code, int decimals})> expected = <MarketScope, ({String code, int decimals})>{
        MarketScope.saudiArabia: (code: 'SAR', decimals: 2),
        MarketScope.unitedArabEmirates: (code: 'AED', decimals: 2),
        MarketScope.kuwait: (code: 'KWD', decimals: 3),
        MarketScope.qatar: (code: 'QAR', decimals: 2),
        MarketScope.bahrain: (code: 'BHD', decimals: 3),
        MarketScope.oman: (code: 'OMR', decimals: 3),
      };

      for (final MapEntry<MarketScope, ({String code, int decimals})> market in expected.entries) {
        expect(_moneyOf(market.key).currencyCode, market.value.code, reason: market.key.name);
        expect(_moneyOf(market.key).decimals, market.value.decimals, reason: market.key.name);
      }
    });

    test('does not exist for All Markets, which has no currency', () {
      expect(MarketMoney.forScope(MarketScope.allMarkets), isNull);
    });

    test('is read from the market the preferences hold', () async {
      expect(MarketMoney.fromPreferences(await _preferencesWith(<String, Object>{AppConstants.storefrontCountry: 'KW'}))?.currencyCode, 'KWD');
      expect(MarketMoney.fromPreferences(await _preferencesWith(<String, Object>{AppConstants.storefrontCountry: ' om '}))?.currencyCode, 'OMR');
    });

    test('does not exist when the preferences hold no GCC market', () async {
      final List<Map<String, Object>> stored = <Map<String, Object>>[
        <String, Object>{},
        <String, Object>{AppConstants.storefrontCountry: ''},
        <String, Object>{AppConstants.storefrontCountry: 'US'},
        <String, Object>{AppConstants.storefrontCountry: MarketScope.allMarkets.name},
        <String, Object>{AppConstants.storefrontCountry: 7},
      ];

      for (final Map<String, Object> values in stored) {
        expect(MarketMoney.fromPreferences(await _preferencesWith(values)), isNull, reason: '$values');
      }
    });
  });

  group('the market the registered preferences hold', () {
    test('is the money of that market', () async {
      GetIt.instance.registerSingleton<SharedPreferences>(await _preferencesWith(<String, Object>{AppConstants.storefrontCountry: 'KW'}));

      expect(MarketMoney.fromRegisteredPreferences()?.currencyCode, 'KWD');
    });

    test('is no market when they hold none, or hold one that is not a GCC market', () async {
      expect(MarketMoney.fromRegisteredPreferences(), isNull);

      GetIt.instance.registerSingleton<SharedPreferences>(await _preferencesWith(<String, Object>{AppConstants.storefrontCountry: 'US'}));

      expect(MarketMoney.fromRegisteredPreferences(), isNull);
    });

    test('is no market, and no failure, while no preferences are registered', () {
      expect(GetIt.instance.isRegistered<SharedPreferences>(), isFalse);
      expect(MarketMoney.fromRegisteredPreferences(), isNull);
    });
  });

  group('which market is working', () {
    test('storefronts off: no market, even when preferences hold one', () async {
      GetIt.instance.registerSingleton<SharedPreferences>(await _preferencesWith(<String, Object>{AppConstants.storefrontCountry: 'KW'}));

      expect(MarketMoney.current(), isNull);
    }, skip: StorefrontConfig.enabled ? 'the flag is on in this run' : false);

    test('storefronts on: the market the registered preferences hold', () async {
      GetIt.instance.registerSingleton<SharedPreferences>(await _preferencesWith(<String, Object>{AppConstants.storefrontCountry: 'KW'}));

      expect(MarketMoney.current()?.currencyCode, 'KWD');
    }, skip: StorefrontConfig.enabled ? false : 'run with --dart-define=GCC_STOREFRONTS_ENABLED=true');

    test('no market while the preferences are not registered, or hold none', () async {
      expect(MarketMoney.current(), isNull);

      GetIt.instance.registerSingleton<SharedPreferences>(await _preferencesWith(<String, Object>{}));

      expect(MarketMoney.current(), isNull);
    });

    test('a test can put a market in place, and take it out again', () {
      MarketMoney.lookUpWith(() => _moneyOf(MarketScope.oman));
      expect(MarketMoney.current()?.currencyCode, 'OMR');

      MarketMoney.lookUpWith(null);
      expect(MarketMoney.current(), isNull);
    });
  });

  group('an amount written as a price', () {
    test('has the currency code and the decimals of each of the six markets', () {
      const Map<MarketScope, String> expected = <MarketScope, String>{
        MarketScope.saudiArabia: 'SAR 1,234.50',
        MarketScope.unitedArabEmirates: 'AED 1,234.50',
        MarketScope.kuwait: 'KWD 1,234.500',
        MarketScope.qatar: 'QAR 1,234.50',
        MarketScope.bahrain: 'BHD 1,234.500',
        MarketScope.oman: 'OMR 1,234.500',
      };

      for (final MapEntry<MarketScope, String> market in expected.entries) {
        expect(_moneyOf(market.key).amountWithCurrency(1234.5, markOnRight: false), market.value, reason: market.key.name);
      }
    });

    test('has the code on the right when that is where the app puts the currency mark', () {
      expect(_moneyOf(MarketScope.kuwait).amountWithCurrency(1234.5, markOnRight: true), '1,234.500 KWD');
      expect(_moneyOf(MarketScope.saudiArabia).amountWithCurrency(1234.5, markOnRight: true), '1,234.50 SAR');
    });

    test('is grouped in thousands in the whole part only, so no comma lands among the decimals', () {
      expect(_moneyOf(MarketScope.kuwait).amountWithCurrency(1234567.891, markOnRight: false), 'KWD 1,234,567.891');
      expect(_moneyOf(MarketScope.saudiArabia).amountWithCurrency(1234567.891, markOnRight: false), 'SAR 1,234,567.89');
      expect(_moneyOf(MarketScope.kuwait).amountWithCurrency(999.5, markOnRight: false), 'KWD 999.500');
      expect(_moneyOf(MarketScope.kuwait).amountWithCurrency(0, markOnRight: false), 'KWD 0.000');
    });

    test('carries a negative sign in front of the digits, and none on a negative zero', () {
      expect(_moneyOf(MarketScope.kuwait).amountWithCurrency(-1234.5, markOnRight: false), 'KWD -1,234.500');
      expect(_moneyOf(MarketScope.kuwait).amountWithCurrency(-0.0004, markOnRight: false), 'KWD 0.000');
      expect(_moneyOf(MarketScope.saudiArabia).amountWithCurrency(-0.004, markOnRight: true), '0.00 SAR');
    });

    test('truncates instead of rounding when asked to, so a balance is never shown higher than it is', () {
      expect(_moneyOf(MarketScope.kuwait).amountWithCurrency(12.3459, markOnRight: false), 'KWD 12.346');
      expect(_moneyOf(MarketScope.kuwait).amountWithCurrency(12.3459, markOnRight: false, truncate: true), 'KWD 12.345');
      expect(_moneyOf(MarketScope.saudiArabia).amountWithCurrency(12.349, markOnRight: false, truncate: true), 'SAR 12.34');
    });
  });

  group('an amount written as digits', () {
    test('is rounded to the decimals of the market', () {
      expect(_moneyOf(MarketScope.kuwait).amountText(12.3456), '12.346');
      expect(_moneyOf(MarketScope.kuwait).amountText(12.3454), '12.345');
      expect(_moneyOf(MarketScope.saudiArabia).amountText(12.3456), '12.35');
      expect(_moneyOf(MarketScope.saudiArabia).amountText(12.3), '12.30');
      expect(_moneyOf(MarketScope.kuwait).amountText(999.9996), '1000.000');
    });

    test('has no currency code and no grouping, so it can be typed and parsed back', () {
      expect(_moneyOf(MarketScope.kuwait).amountText(1234567.891), '1234567.891');
      expect(double.parse(_moneyOf(MarketScope.kuwait).amountText(1234567.891)), 1234567.891);
    });

    test('keeps the third decimal of a market that has one, and leaves a market with two without it', () {
      expect(_moneyOf(MarketScope.bahrain).amountText(0.125), '0.125');
      expect(_moneyOf(MarketScope.oman).amountText(0.125), '0.125');
      expect(_moneyOf(MarketScope.qatar).amountText(0.125), '0.13');
    });

    test('is truncated to the decimals when asked to', () {
      expect(_moneyOf(MarketScope.kuwait).amountText(12.3459, truncate: true), '12.345');
      expect(_moneyOf(MarketScope.saudiArabia).amountText(12.3459, truncate: true), '12.34');
      expect(_moneyOf(MarketScope.saudiArabia).amountText(-12.3459, truncate: true), '-12.34');
    });

    test('is not cut a cent short when floating point puts a product a hair under it', () {
      // 4.35 * 100 is 434.99999999999994, so a cut after the multiplication gives 4.34.
      expect(4.35 * 100, lessThan(435));
      expect(_moneyOf(MarketScope.saudiArabia).amountText(4.35, truncate: true), '4.35');
      expect(_moneyOf(MarketScope.saudiArabia).amountText(0.29, truncate: true), '0.29');
      expect(_moneyOf(MarketScope.saudiArabia).amountText(8.2, truncate: true), '8.20');
      expect(_moneyOf(MarketScope.kuwait).amountText(1.005, truncate: true), '1.005');
    });

    test('is written as it is, and does not fail, when the amount is not a number', () {
      for (final bool truncate in <bool>[false, true]) {
        expect(_moneyOf(MarketScope.kuwait).amountText(double.nan, truncate: truncate), 'NaN');
        expect(_moneyOf(MarketScope.kuwait).amountText(double.infinity, truncate: truncate), 'Infinity');
        expect(_moneyOf(MarketScope.kuwait).amountText(double.negativeInfinity, truncate: truncate), '-Infinity');
      }
    });

    test('is still cut when the amount really is under the cent', () {
      expect(_moneyOf(MarketScope.saudiArabia).amountText(4.3499, truncate: true), '4.34');
      expect(_moneyOf(MarketScope.kuwait).amountText(4.3499, truncate: true), '4.349');
    });
  });

  group('the input formatter of an amount', () {
    test('accepts digits with at most the decimals of the market', () {
      expect(_typed(MoneyInputFormatter(decimals: 3), '0.125'), '0.125');
      expect(_typed(MoneyInputFormatter(decimals: 3), '1234.5'), '1234.5');
      expect(_typed(MoneyInputFormatter(decimals: 2), '0.12'), '0.12');
    });

    test('refuses a fourth decimal on KWD', () {
      final MoneyInputFormatter formatter = MoneyInputFormatter(decimals: _moneyOf(MarketScope.kuwait).decimals);

      expect(_typed(formatter, '1.2345'), '1.234');
      expect(_pasted(formatter, '12.34567').text, '12.345');
    });

    test('refuses a third decimal on SAR', () {
      final MoneyInputFormatter formatter = MoneyInputFormatter(decimals: _moneyOf(MarketScope.saudiArabia).decimals);

      expect(_typed(formatter, '1.234'), '1.23');
      expect(_pasted(formatter, '12.345').text, '12.34');
    });

    test('refuses a second decimal point and anything that is not a digit', () {
      final MoneyInputFormatter formatter = MoneyInputFormatter(decimals: 3);

      expect(_typed(formatter, '1.2.3'), '1.23');
      expect(_typed(formatter, '12a'), '12');
      expect(_typed(formatter, '-5'), '5');
      expect(_typed(formatter, '1 2'), '12');
      expect(_pasted(formatter, '1.2.3').text, '1.2');
      expect(_pasted(formatter, '-5').text, '');
      expect(_pasted(formatter, 'KWD 12.5').text, '');
    });

    test('takes a point first, and a point last, as a seller types towards a number', () {
      final MoneyInputFormatter formatter = MoneyInputFormatter(decimals: 3);

      expect(_typed(formatter, '.5'), '.5');
      expect(_typed(formatter, '12.'), '12.');
    });

    test('lets a seller delete back through the decimals', () {
      final MoneyInputFormatter formatter = MoneyInputFormatter(decimals: 3);
      const TextEditingValue full = TextEditingValue(text: '1.234', selection: TextSelection.collapsed(offset: 5));
      const TextEditingValue shorter = TextEditingValue(text: '1.23', selection: TextSelection.collapsed(offset: 4));

      expect(formatter.formatEditUpdate(full, shorter), shorter);
    });

    test('with two decimals is the formatter the payout and bulk price fields had, on every edit', () {
      final FilteringTextInputFormatter before = FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'));
      final MoneyInputFormatter shared = MoneyInputFormatter(decimals: 2);
      const List<String> edits = <String>[
        '',
        '0',
        '1',
        '12',
        '12.',
        '12.3',
        '12.34',
        '12.345',
        '.',
        '.5',
        '.567',
        '0.00',
        '00.00',
        'a',
        '1a',
        'a1',
        '1.2.3',
        '1,5',
        '1 5',
        ' 1',
        '-1',
        '+1',
        '1e5',
        '١٢٣',
        '1..2',
        '99999999999999999999.99',
      ];

      for (final String edit in edits) {
        final TextEditingValue next = TextEditingValue(text: edit, selection: TextSelection.collapsed(offset: edit.length));

        expect(shared.formatEditUpdate(TextEditingValue.empty, next), before.formatEditUpdate(TextEditingValue.empty, next), reason: "'$edit'");
      }
    });

    test('keeps the cursor where the seller is typing', () {
      final MoneyInputFormatter formatter = MoneyInputFormatter(decimals: 3);
      const TextEditingValue old = TextEditingValue(text: '1.234', selection: TextSelection.collapsed(offset: 1));
      const TextEditingValue inserted = TextEditingValue(text: '12.234', selection: TextSelection.collapsed(offset: 2));

      expect(formatter.formatEditUpdate(old, inserted).selection, const TextSelection.collapsed(offset: 2));
    });
  });

  group('the input formatters of a money field', () {
    test('are the shared formatter with the decimals of the market while a market is working', () {
      MarketMoney.lookUpWith(() => _moneyOf(MarketScope.kuwait));

      final List<TextInputFormatter>? formatters = MarketMoney.inputFormatters();

      expect(formatters, hasLength(1));
      expect(formatters!.single, isA<MoneyInputFormatter>().having((MoneyInputFormatter formatter) => formatter.decimals, 'decimals', 3));
    });

    test('take the decimals of the market, not those the field had before', () {
      MarketMoney.lookUpWith(() => _moneyOf(MarketScope.saudiArabia));

      final List<TextInputFormatter>? formatters = MarketMoney.inputFormatters(outsideMarket: <TextInputFormatter>[MoneyInputFormatter(decimals: 5)]);

      expect(formatters!.single, isA<MoneyInputFormatter>().having((MoneyInputFormatter formatter) => formatter.decimals, 'decimals', 2));
    });

    test('are what the field had before while no market is working', () {
      final List<TextInputFormatter> before = <TextInputFormatter>[MoneyInputFormatter(decimals: 2)];

      expect(MarketMoney.inputFormatters(outsideMarket: before), same(before));
      expect(MarketMoney.inputFormatters(), isNull);
    });

    test('are what the field had before for a stored value that names no GCC market', () async {
      final SharedPreferences preferences = await _preferencesWith(<String, Object>{AppConstants.storefrontCountry: 'US'});
      MarketMoney.lookUpWith(() => MarketMoney.fromPreferences(preferences));
      final List<TextInputFormatter> before = <TextInputFormatter>[MoneyInputFormatter(decimals: 2)];

      expect(MarketMoney.inputFormatters(outsideMarket: before), same(before));
    });
  });
}
