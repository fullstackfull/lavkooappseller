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

/// Where each field that takes money is, and the controller that names it.
const List<({String path, String field, String controller})> _moneyFields = <({String path, String field, String controller})>[
  (
    path: 'lib/features/seller_center/widgets/request_payout_sheet_widget.dart',
    field: 'the amount of a payout request',
    controller: 'controller: _amountController'
  ),
  (path: 'lib/features/bulk_jobs/screens/bulk_edit_screen.dart', field: 'the value of a bulk price change', controller: 'controller: _valueController'),
  (path: 'lib/features/pos/screens/pos_screen.dart', field: 'the cash a customer paid at the point of sale', controller: 'controller: _paidAmountController'),
  (
    path: 'lib/features/pos/widgets/extra_discount_and_coupon_dialog_widget.dart',
    field: 'the extra discount of a sale at the point of sale',
    controller: 'controller: couponDiscountController.extraDiscountController',
  ),
  (path: 'lib/common/basewidgets/custom_edit_dialog_widget.dart', field: 'the amount of a withdrawal', controller: 'controller: _balanceController'),
  (
    path: 'lib/features/finance_control/screens/finance_control_screen.dart',
    field: 'the price below which a product is never sold',
    controller: 'controller: _minPrice'
  ),
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
    for (final ({String path, String field, String controller}) money in _moneyFields) {
      test('${money.field} takes its formatters from the market', () {
        expect(_callAround(_codeOf(money.path), money.controller), contains('MarketMoney.inputFormatters('), reason: '${money.path}: ${money.field}');
      });
    }

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
  });
}
