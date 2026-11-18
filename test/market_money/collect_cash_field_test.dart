import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_button_widget.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/data/model/response/response_model.dart';
import 'package:syriacosmeticsmanger/features/delivery_man/controllers/delivery_man_controller.dart';
import 'package:syriacosmeticsmanger/features/delivery_man/domain/model/delivery_man_body.dart';
import 'package:syriacosmeticsmanger/features/delivery_man/domain/services/delivery_service_interface.dart';
import 'package:syriacosmeticsmanger/features/delivery_man/screens/withdraw/delivery_man_collect_cash_widget.dart';
import 'package:syriacosmeticsmanger/features/splash/controllers/splash_controller.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/market_money.dart';
import 'package:syriacosmeticsmanger/theme/controllers/theme_controller.dart';

import 'support/money_store.dart';

/// The delivery man API as far as collecting cash reaches it, keeping the text of each amount it was asked to collect. It refuses, so the dialog stays open.
class _RecordingDeliveryService implements DeliveryServiceInterface {
  final List<String> collectedAmounts = <String>[];

  @override
  Future<dynamic> collectCashFromDeliveryMan(int? deliveryManId, String amount) async {
    collectedAmounts.add(amount);
    return ResponseModel(false, 'refused');
  }

  @override
  Future<dynamic> getDeliveryManList() => throw UnimplementedError();

  @override
  Future<dynamic> deliveryManWithdrawList(int offset, String status) => throw UnimplementedError();

  @override
  Future<dynamic> getDeliveryManReviewList(int offset, int? id) => throw UnimplementedError();

  @override
  Future<dynamic> deliveryManWithdrawDetails(int? id) => throw UnimplementedError();

  @override
  Future<dynamic> deliveryManWithdrawApprovedDenied(int? id, String note, int approved) => throw UnimplementedError();

  @override
  Future<dynamic> deliveryManList(int offset, String search) => throw UnimplementedError();

  @override
  Future<dynamic> deliveryManDetails(int? deliveryManId) => throw UnimplementedError();

  @override
  Future<dynamic> deliveryManOrderList(int offset, int? deliverymanId) => throw UnimplementedError();

  @override
  Future<dynamic> deliveryManEarningList(int offset, int? deliverymanId) => throw UnimplementedError();

  @override
  Future<dynamic> getTopDeliveryManList() => throw UnimplementedError();

  @override
  Future<dynamic> deliveryManStatusOnOff(int? id, int status) => throw UnimplementedError();

  @override
  Future<dynamic> deleteDeliveryMan(int? deliveryManId) => throw UnimplementedError();

  @override
  Future<dynamic> getDeliverymanOrderHistoryLog(int? orderId) => throw UnimplementedError();

  @override
  Future<dynamic> addNewDeliveryMan(XFile? profileImage, List<XFile?> identityImage, DeliveryManBody deliveryManBody, String token, {bool isUpdate = false}) =>
      throw UnimplementedError();

  @override
  Future<dynamic> getDeliveryManCollectedCashList(int? id, int offset) => throw UnimplementedError();
}

final Map<String, dynamic> _storeWithSeveralCurrencies = moneyStoreConfig(
  currencyModel: 'multi_currency',
  symbolPosition: 'right',
  decimals: 2,
  currencies: <Map<String, dynamic>>[moneyStoreCurrency(1, r'$', 'USD', 1), moneyStoreCurrency(2, 'SR', 'SAR', 3.75)],
);

/// Opens the dialog that collects cash from a delivery man who holds 100 in cash.
Future<_RecordingDeliveryService> _openDialog(WidgetTester tester, {required MarketScope? market}) async {
  MarketMoney.lookUpWith(market == null ? null : () => MarketMoney.forScope(market));
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final SplashController splash = await loadedSplashController(config: _storeWithSeveralCurrencies, shownCurrencyCode: 'SAR');
  final _RecordingDeliveryService service = _RecordingDeliveryService();

  await tester.pumpWidget(
    MultiProvider(
      providers: <ChangeNotifierProvider<ChangeNotifier>>[
        ChangeNotifierProvider<SplashController>.value(value: splash),
        ChangeNotifierProvider<ThemeController>.value(value: ThemeController(sharedPreferences: preferences)),
        ChangeNotifierProvider<DeliveryManController>.value(value: DeliveryManController(deliveryServiceInterface: service)),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SingleChildScrollView(child: CollectedCashFromDeliveryManDialog(totalCashInHand: 100, deliveryManId: 4))),
      ),
    ),
  );
  await tester.pump();

  return service;
}

String _amountField(WidgetTester tester) => tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text;

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextFormField), text);
  await tester.pump();
}

/// K-10.1 and K-10.3: the cash a seller collects from a delivery man is typed in the decimals of the market, beside the market's currency, and sent as typed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => MarketMoney.lookUpWith(null));

  group('with no market working', () {
    testWidgets('the symbol of the config stands beside the amount, and the field takes any decimals up to its length limit', (WidgetTester tester) async {
      await _openDialog(tester, market: null);

      await _type(tester, '12.3456');

      expect(find.text('SR'), findsOneWidget);
      expect(find.text('KWD'), findsNothing);
      expect(_amountField(tester), '12.3456');
    });
  });

  group('in Kuwait', () {
    testWidgets('the currency code stands beside the amount, and the cash in hand is written in dinars', (WidgetTester tester) async {
      await _openDialog(tester, market: MarketScope.kuwait);

      expect(find.text('KWD'), findsOneWidget);
      expect(find.text('SR'), findsNothing);
      expect(find.textContaining('100.000 KWD'), findsOneWidget);
    });

    testWidgets('the field takes three decimals and refuses a fourth', (WidgetTester tester) async {
      await _openDialog(tester, market: MarketScope.kuwait);

      await _type(tester, '12.3456');

      expect(_amountField(tester), '12.345');
    });

    testWidgets('the field keeps its limit of 20 characters', (WidgetTester tester) async {
      await _openDialog(tester, market: MarketScope.kuwait);

      await _type(tester, '1' * 25);

      expect(_amountField(tester), '1' * 20);
    });

    testWidgets('the amount is sent as it was typed', (WidgetTester tester) async {
      final _RecordingDeliveryService service = await _openDialog(tester, market: MarketScope.kuwait);

      await _type(tester, '12.345');
      await tester.tap(find.byType(CustomButtonWidget));
      await tester.pumpAndSettle();

      expect(service.collectedAmounts, <String>['12.345']);
    });
  });

  group('in Saudi Arabia', () {
    testWidgets('the field takes two decimals and refuses a third', (WidgetTester tester) async {
      await _openDialog(tester, market: MarketScope.saudiArabia);

      await _type(tester, '12.345');

      expect(_amountField(tester), '12.34');
      expect(find.text('SAR'), findsOneWidget);
    });
  });
}
