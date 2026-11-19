import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_edit_dialog_widget.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/features/splash/controllers/splash_controller.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/market_money.dart';
import 'package:syriacosmeticsmanger/features/wallet/controllers/wallet_controller.dart';
import 'package:syriacosmeticsmanger/features/wallet/domain/services/wallet_service_interface.dart';
import 'package:syriacosmeticsmanger/theme/controllers/theme_controller.dart';

import 'support/money_store.dart';

/// The wallet service is never reached: the dialog only fills in and reads the text of its amount field until the seller asks to withdraw.
class _UnreachedWalletService implements WalletServiceInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

final Map<String, dynamic> _storeWithSeveralCurrencies = moneyStoreConfig(
  currencyModel: 'multi_currency',
  symbolPosition: 'right',
  decimals: 2,
  currencies: <Map<String, dynamic>>[moneyStoreCurrency(1, r'$', 'USD', 1), moneyStoreCurrency(2, 'SR', 'SAR', 3.75)],
);

/// Opens the withdrawal dialog for a seller whose earnings are 1234.5699.
Future<void> _openDialog(WidgetTester tester, {required MarketScope? market}) async {
  MarketMoney.lookUpWith(market == null ? null : () => MarketMoney.forScope(market));
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final SplashController splash = await loadedSplashController(config: _storeWithSeveralCurrencies, shownCurrencyCode: 'SAR');

  await tester.pumpWidget(
    MultiProvider(
      providers: <ChangeNotifierProvider<ChangeNotifier>>[
        ChangeNotifierProvider<SplashController>.value(value: splash),
        ChangeNotifierProvider<ThemeController>.value(value: ThemeController(sharedPreferences: preferences)),
        ChangeNotifierProvider<WalletController>.value(value: WalletController(walletServiceInterface: _UnreachedWalletService())),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SingleChildScrollView(child: CustomEditDialogWidget(totalEarning: 1234.5699))),
      ),
    ),
  );
  await tester.pump();
}

String _amountField(WidgetTester tester) => tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'enter_withdraw_amount')).controller!.text;

TextInputType? _keyboard(WidgetTester tester) => tester
    .widget<TextField>(find.descendant(of: find.widgetWithText(TextFormField, 'enter_withdraw_amount'), matching: find.byType(TextField)))
    .keyboardType;

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'enter_withdraw_amount'), text);
  await tester.pump();
}

/// K-10.2 and K-10.3: the amount of a withdrawal starts as the earnings cut to the decimals of the market, with no exchange rate, and takes no more decimals than the market
/// has, on a keyboard with a decimal point. The test goes as far as the field: the dialog is never asked to withdraw, so what it sends is not run here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => MarketMoney.lookUpWith(null));

  group('with no market working', () {
    testWidgets('the earnings are converted and cut to the decimals of the config, and up to five decimals can be typed, as it always was',
        (WidgetTester tester) async {
      await _openDialog(tester, market: null);

      expect(_amountField(tester), '4629.63');

      await _type(tester, '1.23456');
      expect(_amountField(tester), '1.23456');

      await _type(tester, '1.234567');
      expect(_amountField(tester), '1.23456');
    });

    testWidgets('the keyboard is the number pad, as it always was', (WidgetTester tester) async {
      await _openDialog(tester, market: null);

      expect(_keyboard(tester), TextInputType.number);
    });
  });

  group('in Kuwait', () {
    testWidgets('the earnings are cut to three decimals and not converted', (WidgetTester tester) async {
      await _openDialog(tester, market: MarketScope.kuwait);

      expect(_amountField(tester), '1234.569');
    });

    testWidgets('the keyboard has a decimal point, so that 0.500 can be typed on a phone whose number pad has none', (WidgetTester tester) async {
      await _openDialog(tester, market: MarketScope.kuwait);

      expect(_keyboard(tester), const TextInputType.numberWithOptions(decimal: true));
    });

    testWidgets('three decimals can be typed and a fourth is refused', (WidgetTester tester) async {
      await _openDialog(tester, market: MarketScope.kuwait);

      await _type(tester, '12.345');
      expect(_amountField(tester), '12.345');

      await _type(tester, '12.3456');
      expect(_amountField(tester), '12.345');
    });
  });

  group('in Saudi Arabia', () {
    testWidgets('the earnings are cut to two decimals and not converted, and a third decimal is refused', (WidgetTester tester) async {
      await _openDialog(tester, market: MarketScope.saudiArabia);

      expect(_amountField(tester), '1234.56');

      await _type(tester, '12.345');
      expect(_amountField(tester), '12.34');
      expect(_keyboard(tester), const TextInputType.numberWithOptions(decimal: true));
    });
  });
}
