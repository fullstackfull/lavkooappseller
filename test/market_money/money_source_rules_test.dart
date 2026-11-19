import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The source of [path] without its `//` comments, so that a line of commented-out code is not mistaken for code.
String _codeOf(String path) => File(path).readAsStringSync().replaceAll(RegExp(r'//[^\n]*'), '');

/// The call that holds [locator], from its opening parenthesis to the one that closes it: the constructor of the field whose controller [locator] names.
String _callAround(String code, String locator) {
  final int at = code.indexOf(locator);
  expect(at, isNonNegative, reason: 'the field `$locator` is gone');
  expect(code.indexOf(locator, at + 1), -1, reason: '`$locator` names more than one field');

  int depth = 0;
  int start = at;
  while (start >= 0 && !(code[start] == '(' && depth == 0)) {
    if (code[start] == ')') {
      depth++;
    } else if (code[start] == '(') {
      depth--;
    }
    start--;
  }

  depth = 0;
  int end = start;
  do {
    if (code[end] == '(') {
      depth++;
    } else if (code[end] == ')') {
      depth--;
    }
    end++;
  } while (depth > 0);

  return code.substring(start, end);
}

/// The static functions of the money formatter, by name, with their source.
Map<String, String> _formatterFunctions() {
  final List<String> chunks = _codeOf('lib/helper/price_converter.dart').split('\n  static ').skip(1).toList();

  return <String, String>{
    for (final String chunk in chunks) RegExp(r'^\S+ (\w+)\s*\(').firstMatch(chunk)!.group(1)!: chunk,
  };
}

/// The call a field makes when what it had outside a market comes from its widget or from nothing: it asks for the formatters of the market and gives none of its
/// own, so that outside a market it keeps what its widget picks.
final RegExp _noFormattersOfItsOwn = RegExp(r'MarketMoney\.inputFormatters\(\s*\)');

/// The call a field makes when it had the formatter of two decimals outside a market.
final RegExp _twoDecimalsOutsideAMarket = RegExp(r'MarketMoney\.inputFormatters\(\s*outsideMarket:\s*\[\s*MoneyInputFormatter\(decimals: 2\)\s*\]\s*\)');

/// The call a field makes when it had a formatter written in the field itself outside a market.
final RegExp _ownFunctionOutsideAMarket = RegExp(r'MarketMoney\.inputFormatters\(\s*outsideMarket:\s*\[\s*TextInputFormatter\.withFunction\(');

/// Where each field that takes money is, the controller that names it, and the exact call it must make for its formatters: a field that gives the call no argument has
/// no formatters of its own outside a market, and a field that gives it `outsideMarket` keeps the ones it gives.
final List<({String path, String field, String controller, RegExp call})> _moneyFields = <({String path, String field, String controller, RegExp call})>[
  (
    path: 'lib/features/seller_center/widgets/request_payout_sheet_widget.dart',
    field: 'the amount of a payout request',
    controller: 'controller: _amountController',
    call: _twoDecimalsOutsideAMarket
  ),
  (
    path: 'lib/features/bulk_jobs/screens/bulk_edit_screen.dart',
    field: 'the value of a bulk price change',
    controller: 'controller: _valueController',
    call: _twoDecimalsOutsideAMarket
  ),
  (
    path: 'lib/features/pos/widgets/paid_amount_field_widget.dart',
    field: 'the cash a customer paid at the point of sale',
    controller: 'controller: controller',
    call: _noFormattersOfItsOwn
  ),
  (
    path: 'lib/features/pos/widgets/extra_discount_and_coupon_dialog_widget.dart',
    field: 'the extra discount of a sale at the point of sale',
    controller: 'controller: couponDiscountController.extraDiscountController',
    call: _noFormattersOfItsOwn,
  ),
  (
    path: 'lib/common/basewidgets/custom_edit_dialog_widget.dart',
    field: 'the amount of a withdrawal',
    controller: 'controller: _balanceController',
    call: _ownFunctionOutsideAMarket
  ),
  (
    path: 'lib/features/finance_control/screens/finance_control_screen.dart',
    field: 'the price below which a product is never sold',
    controller: 'controller: _minPrice',
    call: _noFormattersOfItsOwn
  ),
  (
    path: 'lib/features/delivery_man/screens/withdraw/delivery_man_collect_cash_widget.dart',
    field: 'the cash collected from a delivery man',
    controller: 'controller: _balanceController',
    call: _noFormattersOfItsOwn
  ),
];

/// The fields that had the number pad outside a market, which a phone can give no decimal point: each asks the market for its keyboard and keeps the number pad
/// outside one.
const List<({String path, String field, String controller})> _numberPadFields = <({String path, String field, String controller})>[
  (
    path: 'lib/features/pos/widgets/paid_amount_field_widget.dart',
    field: 'the cash a customer paid at the point of sale',
    controller: 'controller: controller'
  ),
  (
    path: 'lib/features/pos/widgets/extra_discount_and_coupon_dialog_widget.dart',
    field: 'the extra discount of a sale at the point of sale',
    controller: 'controller: couponDiscountController.extraDiscountController',
  ),
  (path: 'lib/common/basewidgets/custom_edit_dialog_widget.dart', field: 'the amount of a withdrawal', controller: 'controller: _balanceController'),
  (
    path: 'lib/features/delivery_man/screens/withdraw/delivery_man_collect_cash_widget.dart',
    field: 'the cash collected from a delivery man',
    controller: 'controller: _balanceController'
  ),
];

/// K-10.2 and K-10.3 from the source: the places a market build must not multiply by an exchange rate, and the fields that must take the market's decimals. These
/// scans see the code and not what it does; the tests next to this one run it.
void main() {
  group('the exchange rate', () {
    test('is read by no file but the formatter, the config model that parses it and the splash controller that logs it', () {
      final List<String> readers = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File file) => file.path.endsWith('.dart') && _codeOf(file.path).contains('exchangeRate'))
          .map((File file) => file.path)
          .toList()
        ..sort();

      expect(readers, <String>[
        'lib/features/splash/controllers/splash_controller.dart',
        'lib/features/splash/domain/models/config_model.dart',
        'lib/helper/price_converter.dart',
      ]);
    });

    test('is applied by a function of the formatter only after it has asked whether a market is working', () {
      final Map<String, String> multiplying = <String, String>{
        for (final MapEntry<String, String> function in _formatterFunctions().entries)
          if (function.value.contains('exchangeRate')) function.key: function.value,
      };

      expect(
          multiplying.keys,
          containsAll(<String>[
            'convertPrice',
            'convertPriceForWithdraw',
            'convertPriceWithoutSymbol',
            'convertPriceWithoutSymbolForWithdraw',
            'reverseConvertPriceWithoutSymbol',
            'convertAmount',
            'discountCalculationWithOutSymbol',
          ]));

      for (final MapEntry<String, String> function in multiplying.entries) {
        final int market = function.value.indexOf('MarketMoney.current()');

        expect(market, isNonNegative, reason: '${function.key} multiplies by an exchange rate and never asks whether a market is working');
        expect(market, lessThan(function.value.indexOf('exchangeRate')),
            reason: '${function.key} reads an exchange rate before it asks whether a market is working');
      }
    });
  });

  group('the market the app works in', () {
    test('is looked up in the preferences, and only while storefronts are on: the flag of the build is the default of the look-up', () {
      final String code = _codeOf('lib/features/storefront/market_money.dart');

      expect(code, contains('ValueGetter<MarketMoney?> _lookUp = fromStoredMarket;'));
      expect(code, contains('fromStoredMarket({bool enabled = StorefrontConfig.enabled}) =>'));
      expect(code, contains('enabled ? fromRegisteredPreferences() : null'));
      expect(RegExp(r'StorefrontConfig\.enabled').allMatches(code), hasLength(1), reason: 'the flag is read in one place only');
    });
  });

  group('the formatter', () {
    test('has a market branch in every function that writes money, and the others are named here with the reason they have none', () {
      const Set<String> writeNoMoney = <String>{
        // Subtracts a discount from a price in the unit the price came in: no conversion, nothing written.
        'convertWithDiscount',
        // Returns the price it is given, whichever way the currency model is set.
        'systemCurrencyToDefaultCurrency',
        // Writes its amount through convertPrice.
        'percentageCalculation',
        // Shortens a count (the reviews of a product), and has no currency.
        'longToShortPrice',
      };

      final Set<String> withoutMarketBranch = <String>{
        for (final MapEntry<String, String> function in _formatterFunctions().entries)
          if (!function.value.contains('MarketMoney.current()')) function.key,
      };

      expect(withoutMarketBranch, writeNoMoney);
    });
  });

  group('the fields that take money', () {
    for (final ({String path, String field, String controller, RegExp call}) money in _moneyFields) {
      test('${money.field} asks the market for its formatters, and keeps outside a market the ones it had', () {
        final String call = _callAround(_codeOf(money.path), money.controller);

        expect(call, contains(money.call), reason: '${money.path}: ${money.field}');
        if (identical(money.call, _noFormattersOfItsOwn)) {
          expect(call, isNot(contains(RegExp(r'MarketMoney\.inputFormatters\(\s*outsideMarket'))),
              reason: '${money.path}: ${money.field} had no formatter of its own outside a market');
        }
      });
    }

    for (final ({String path, String field, String controller}) money in _numberPadFields) {
      test('${money.field} asks the market for its keyboard, and keeps the number pad outside a market', () {
        expect(
          _callAround(_codeOf(money.path), money.controller),
          contains('MarketMoney.keyboardType(outsideMarket: TextInputType.number)'),
          reason: '${money.path}: ${money.field}',
        );
      });
    }

    test('the paid amount and the discount of a sale take the amount rules of the shared field outside a market only, and are not fixed to a number pad', () {
      final RegExp amountRulesOutsideAMarket = RegExp(r'isAmount:[^,]*MarketMoney\.current\(\) == null');

      expect(_callAround(_codeOf('lib/features/pos/widgets/paid_amount_field_widget.dart'), 'controller: controller'), contains(amountRulesOutsideAMarket));
      expect(
        _callAround(_codeOf('lib/features/pos/widgets/extra_discount_and_coupon_dialog_widget.dart'), 'controller: couponDiscountController.extraDiscountController'),
        contains(amountRulesOutsideAMarket),
      );
    });

    test('the value of a bulk change takes the formatters of the market for an amount of money only, and not for a percent or for a count of stock', () {
      final String code = _codeOf('lib/features/bulk_jobs/screens/bulk_edit_screen.dart');

      expect(code, contains(RegExp(r'bool get _isMoney =>\s*_isPrice &&\s*!_percentModes\.contains\(_mode\);')));
      expect(_callAround(code, 'controller: _valueController'), contains(RegExp(r'_isMoney\s*\?\s*MarketMoney\.inputFormatters\(')));
    });

    test('the point of sale builds the cash a customer paid with the field that asks the market, and hands it what the field it replaced had', () {
      final String code = _codeOf('lib/features/pos/screens/pos_screen.dart');
      final String call = _callAround(code, 'controller: _paidAmountController');

      expect(code, contains('PaidAmountFieldWidget('));
      expect(code, isNot(contains('CustomTextFieldWidget(')));
      expect(call, contains('isEnabled: cartController.paymentTypeIndex == 0'));
      expect(call, contains('isPaidAmountLess: cartController.isPaidAmountLess'));
      expect(call, contains('focusNode: _paidAmountNode'));
    });

    test('the price and the discount of the fee simulator are money and take their formatters from the market, its quantity is not money', () {
      final String code = _codeOf('lib/features/finance_control/screens/finance_control_screen.dart');

      expect(_callAround(code, "_price, 'price_you_are_considering'"), contains('isMoney: true'));
      expect(_callAround(code, "_discount, 'your_discount_optional'"), contains('isMoney: true'));
      expect(_callAround(code, "_quantity, 'quantity'"), isNot(contains('isMoney')));
      expect(_callAround(code, 'controller: controller,'), contains('MarketMoney.inputFormatters('));
    });

    test('the mark beside the cash collected from a delivery man is the one the formatter gives, not the symbol of the config', () {
      final String code = _codeOf('lib/features/delivery_man/screens/withdraw/delivery_man_collect_cash_widget.dart');

      expect(code, contains('PriceConverter.currencyMark(context)'));
      expect(code, isNot(contains('myCurrency')));
    });

    test('the payout field no longer carries a pattern of two decimals of its own', () {
      expect(_codeOf('lib/features/seller_center/widgets/request_payout_sheet_widget.dart'), isNot(contains(r'\d{0,2}')));
    });

    test('the scan finds a field and its formatter, and misses a formatter that belongs to another field (it guards the guard)', () {
      const String source = '''
        Column(children: [
          TextField(controller: first, inputFormatters: MarketMoney.inputFormatters()),
          TextField(controller: second, keyboardType: TextInputType.number),
        ]);''';

      expect(_callAround(source, 'controller: first'), contains('MarketMoney.inputFormatters('));
      expect(_callAround(source, 'controller: second'), isNot(contains('MarketMoney.inputFormatters(')));
    });

    test('the exact calls tell a call with no argument from one with the formatter of two decimals or one of its own (it guards the guard)', () {
      const String none = 'inputFormatters: MarketMoney.inputFormatters(),';
      const String noneOnSeveralLines = 'inputFormatters: MarketMoney.inputFormatters(\n  ),';
      const String twoDecimals = 'inputFormatters: MarketMoney.inputFormatters(outsideMarket: [MoneyInputFormatter(decimals: 2)]),';
      const String threeDecimals = 'inputFormatters: MarketMoney.inputFormatters(outsideMarket: [MoneyInputFormatter(decimals: 3)]),';
      const String ownFunction = 'inputFormatters: MarketMoney.inputFormatters(outsideMarket: [\n TextInputFormatter.withFunction((a, b) => b),\n ]),';

      expect(_noFormattersOfItsOwn.hasMatch(none), isTrue);
      expect(_noFormattersOfItsOwn.hasMatch(noneOnSeveralLines), isTrue);
      expect(_noFormattersOfItsOwn.hasMatch(twoDecimals), isFalse);
      expect(_noFormattersOfItsOwn.hasMatch(ownFunction), isFalse);

      expect(_twoDecimalsOutsideAMarket.hasMatch(twoDecimals), isTrue);
      expect(_twoDecimalsOutsideAMarket.hasMatch(threeDecimals), isFalse);
      expect(_twoDecimalsOutsideAMarket.hasMatch(none), isFalse);

      expect(_ownFunctionOutsideAMarket.hasMatch(ownFunction), isTrue);
      expect(_ownFunctionOutsideAMarket.hasMatch(twoDecimals), isFalse);
    });
  });
}
