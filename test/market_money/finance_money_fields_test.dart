import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/finance_control/controllers/finance_control_controller.dart';
import 'package:syriacosmeticsmanger/features/finance_control/domain/services/finance_control_service_interface.dart';
import 'package:syriacosmeticsmanger/features/finance_control/screens/finance_control_screen.dart';
import 'package:syriacosmeticsmanger/features/splash/controllers/splash_controller.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/market_money.dart';
import 'package:syriacosmeticsmanger/theme/controllers/theme_controller.dart';

import 'support/money_store.dart';

ApiResponse _answer(Map<String, dynamic> body) =>
    ApiResponse.withSuccess(Response<Map<String, dynamic>>(requestOptions: RequestOptions(path: '/finance'), statusCode: 200, data: body));

/// The finance API as far as the floor and the simulator reach it, keeping what each of them was sent. A pricing policy with no floor is what it answers.
class _RecordingFinanceService implements FinanceControlServiceInterface {
  final List<Map<String, dynamic>> savedPolicies = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> simulations = <Map<String, dynamic>>[];

  @override
  Future<dynamic> getPricingPolicy() async => _answer(<String, dynamic>{
        'min_margin_percent': null,
        'min_price': null,
        'enforce': false,
        'binding': false,
        'products_with_a_cost': 0,
        'products_total': 2,
      });

  @override
  Future<dynamic> savePricingPolicy(Map<String, dynamic> payload) async {
    savedPolicies.add(payload);
    return _answer(<String, dynamic>{});
  }

  @override
  Future<dynamic> simulateFee(Map<String, dynamic> query) async {
    simulations.add(query);
    return ApiResponse.withError('refused');
  }

  @override
  Future<dynamic> getReconciliation({String? from, String? to}) async => ApiResponse.withError('not needed here');

  @override
  Future<dynamic> getPriceChanges({int? productId, String? source}) async => ApiResponse.withError('not needed here');
}

final Map<String, dynamic> _storeWithSeveralCurrencies = moneyStoreConfig(
  currencyModel: 'multi_currency',
  symbolPosition: 'right',
  decimals: 2,
  currencies: <Map<String, dynamic>>[moneyStoreCurrency(1, r'$', 'USD', 1), moneyStoreCurrency(2, 'SR', 'SAR', 3.75)],
);

/// Opens the finance screen, with the pricing policy the service answers loaded.
Future<_RecordingFinanceService> _openFinanceScreen(WidgetTester tester, {required MarketScope? market}) async {
  MarketMoney.lookUpWith(market == null ? null : () => MarketMoney.forScope(market));
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final SplashController splash = await loadedSplashController(config: _storeWithSeveralCurrencies, shownCurrencyCode: 'SAR');
  final _RecordingFinanceService service = _RecordingFinanceService();

  await tester.pumpWidget(
    MultiProvider(
      providers: <ChangeNotifierProvider<ChangeNotifier>>[
        ChangeNotifierProvider<SplashController>.value(value: splash),
        ChangeNotifierProvider<ThemeController>.value(value: ThemeController(sharedPreferences: preferences)),
        ChangeNotifierProvider<FinanceControlController>.value(value: FinanceControlController(financeControlServiceInterface: service)),
      ],
      child: const MaterialApp(home: FinanceControlScreen()),
    ),
  );
  await tester.pumpAndSettle();

  return service;
}

Future<void> _openTab(WidgetTester tester, String tab) async {
  await tester.tap(find.text(tab));
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.widgetWithText(TextField, label);

String _text(WidgetTester tester, String label) => tester.widget<TextField>(_field(label)).controller!.text;

Future<void> _type(WidgetTester tester, String label, String text) async {
  await tester.enterText(_field(label), text);
  await tester.pump();
}

/// K-10.3: the money fields of the finance screen take the decimals of the market and send what was typed, and a quantity stays a quantity.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => MarketMoney.lookUpWith(null));

  group('the price below which a product is never sold', () {
    testWidgets('with no market working takes any number of decimals, as it always did', (WidgetTester tester) async {
      await _openFinanceScreen(tester, market: null);
      await _openTab(tester, 'price_floor');

      await _type(tester, 'never_sell_below_this_price', '12.3456');

      expect(_text(tester, 'never_sell_below_this_price'), '12.3456');
    });

    testWidgets('in Kuwait takes three decimals and refuses a fourth, and is sent as typed', (WidgetTester tester) async {
      final _RecordingFinanceService service = await _openFinanceScreen(tester, market: MarketScope.kuwait);
      await _openTab(tester, 'price_floor');

      await _type(tester, 'never_sell_below_this_price', '12.3456');
      expect(_text(tester, 'never_sell_below_this_price'), '12.345');

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(service.savedPolicies, hasLength(1));
      expect(service.savedPolicies.single['min_price'], 12.345);
    });

    testWidgets('in Saudi Arabia takes two decimals', (WidgetTester tester) async {
      await _openFinanceScreen(tester, market: MarketScope.saudiArabia);
      await _openTab(tester, 'price_floor');

      await _type(tester, 'never_sell_below_this_price', '12.345');

      expect(_text(tester, 'never_sell_below_this_price'), '12.34');
    });

    testWidgets('the margin is a percent, not money, and keeps taking any decimals', (WidgetTester tester) async {
      await _openFinanceScreen(tester, market: MarketScope.kuwait);
      await _openTab(tester, 'price_floor');

      await _type(tester, 'minimum_margin_over_cost_percent', '12.3456');

      expect(_text(tester, 'minimum_margin_over_cost_percent'), '12.3456');
    });
  });

  group('the fee simulator', () {
    testWidgets('in Kuwait takes three decimals in the price and the discount, sends them as typed, and leaves the quantity alone',
        (WidgetTester tester) async {
      final _RecordingFinanceService service = await _openFinanceScreen(tester, market: MarketScope.kuwait);
      await _openTab(tester, 'fee_simulator');

      await _type(tester, 'price_you_are_considering', '12.3456');
      await _type(tester, 'quantity', '2.5678');
      await _type(tester, 'your_discount_optional', '1.2345');

      expect(_text(tester, 'price_you_are_considering'), '12.345');
      expect(_text(tester, 'quantity'), '2.5678');
      expect(_text(tester, 'your_discount_optional'), '1.234');

      await tester.tap(find.text('work_it_out'));
      await tester.pumpAndSettle();

      expect(service.simulations, <Map<String, dynamic>>[
        <String, dynamic>{'unit_price': '12.345', 'quantity': '2.5678', 'discount': '1.234', 'discount_type': 'flat'},
      ]);
    });

    testWidgets('in Saudi Arabia takes two decimals in the price', (WidgetTester tester) async {
      await _openFinanceScreen(tester, market: MarketScope.saudiArabia);
      await _openTab(tester, 'fee_simulator');

      await _type(tester, 'price_you_are_considering', '12.345');

      expect(_text(tester, 'price_you_are_considering'), '12.34');
    });

    testWidgets('with no market working takes any number of decimals, as it always did', (WidgetTester tester) async {
      await _openFinanceScreen(tester, market: null);
      await _openTab(tester, 'fee_simulator');

      await _type(tester, 'price_you_are_considering', '12.3456');
      await _type(tester, 'your_discount_optional', '1.2345');

      expect(_text(tester, 'price_you_are_considering'), '12.3456');
      expect(_text(tester, 'your_discount_optional'), '1.2345');
    });
  });
}
