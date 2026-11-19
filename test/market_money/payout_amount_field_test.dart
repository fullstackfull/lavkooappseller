import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_button_widget.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/seller_center/controllers/seller_center_controller.dart';
import 'package:syriacosmeticsmanger/features/seller_center/domain/models/payout_models.dart';
import 'package:syriacosmeticsmanger/features/seller_center/domain/services/seller_center_service_interface.dart';
import 'package:syriacosmeticsmanger/features/seller_center/widgets/request_payout_sheet_widget.dart';
import 'package:syriacosmeticsmanger/features/splash/controllers/splash_controller.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/market_money.dart';

import 'support/money_store.dart';

ApiResponse _answer(Map<String, dynamic> body) =>
    ApiResponse.withSuccess(Response<Map<String, dynamic>>(requestOptions: RequestOptions(path: '/payouts'), statusCode: 200, data: body));

/// The seller center's API as far as a payout request reaches it, keeping the amount each request carried.
class _RecordingSellerCenterService implements SellerCenterServiceInterface {
  final List<double> requestedAmounts = <double>[];

  @override
  Future<dynamic> requestPayout({required double amount, String? method, String? payoutCurrency}) async {
    requestedAmounts.add(amount);
    return _answer(<String, dynamic>{'message': 'requested'});
  }

  @override
  Future<dynamic> getPayouts({int offset = 1}) async => _answer(<String, dynamic>{});

  @override
  Future<dynamic> getOverview() async => _answer(<String, dynamic>{});

  @override
  Future<dynamic> getScorecard() => throw UnimplementedError();

  @override
  Future<dynamic> getVerification() => throw UnimplementedError();

  @override
  Future<dynamic> submitVerificationDocument({required String documentType, String? documentNumber, String? expiresAt, XFile? documentFile}) =>
      throw UnimplementedError();

  @override
  Future<dynamic> cancelPayout(int id) => throw UnimplementedError();

  @override
  Future<dynamic> getAnalytics({String? range}) => throw UnimplementedError();

  @override
  Future<dynamic> getActivities() => throw UnimplementedError();
}

/// A store with several currencies, the one the seller reads worth 3.75 of the base: the case where a conversion would change an amount.
final Map<String, dynamic> _storeWithSeveralCurrencies = moneyStoreConfig(
  currencyModel: 'multi_currency',
  symbolPosition: 'right',
  decimals: 2,
  currencies: <Map<String, dynamic>>[moneyStoreCurrency(1, r'$', 'USD', 1), moneyStoreCurrency(2, 'SR', 'SAR', 3.75)],
);

final Map<String, dynamic> _storeWithOneCurrency = moneyStoreConfig(
  currencyModel: 'single_currency',
  symbolPosition: 'left',
  decimals: 2,
  currencies: <Map<String, dynamic>>[moneyStoreCurrency(1, r'$', 'USD', 1)],
);

/// Opens the payout sheet the way the payouts screen does, in [market], or in no market when it is null.
Future<_RecordingSellerCenterService> _openPayoutSheet(
  WidgetTester tester, {
  required MarketScope? market,
  required Map<String, dynamic> store,
  double withdrawable = 1234.5699,
}) async {
  MarketMoney.lookUpWith(market == null ? null : () => MarketMoney.forScope(market));
  final SplashController splash = await loadedSplashController(config: store, shownCurrencyCode: store == _storeWithOneCurrency ? 'USD' : 'SAR');
  final _RecordingSellerCenterService service = _RecordingSellerCenterService();
  final SellerCenterController sellerCenter = SellerCenterController(sellerCenterServiceInterface: service);

  await tester.pumpWidget(
    MultiProvider(
      providers: <ChangeNotifierProvider<ChangeNotifier>>[
        ChangeNotifierProvider<SplashController>.value(value: splash),
        ChangeNotifierProvider<SellerCenterController>.value(value: sellerCenter),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => RequestPayoutSheetWidget(payouts: PayoutOverviewModel(withdrawable: withdrawable)),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  return service;
}

String _amountField(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField)).controller!.text;

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

Future<void> _requestPayout(WidgetTester tester) async {
  await tester.tap(find.byType(CustomButtonWidget));
  await tester.pumpAndSettle();
}

/// K-10.3: the payout field takes the decimals of the market, and sends the amount as it was typed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => MarketMoney.lookUpWith(null));

  group('with no market working', () {
    testWidgets('the field takes two decimals, as it always did, and sends them', (WidgetTester tester) async {
      final _RecordingSellerCenterService service = await _openPayoutSheet(tester, market: null, store: _storeWithOneCurrency);

      await _type(tester, '12.3456');

      expect(_amountField(tester), '12.34');

      await _requestPayout(tester);

      expect(service.requestedAmounts, <double>[12.34]);
    });
  });

  group('in Kuwait', () {
    testWidgets('the field takes three decimals and refuses a fourth', (WidgetTester tester) async {
      await _openPayoutSheet(tester, market: MarketScope.kuwait, store: _storeWithSeveralCurrencies);

      await _type(tester, '12.345');
      expect(_amountField(tester), '12.345');

      await _type(tester, '12.3456');
      expect(_amountField(tester), '12.345');
    });

    testWidgets('the amount sent is the amount typed, with its three decimals and no exchange rate applied', (WidgetTester tester) async {
      final _RecordingSellerCenterService service = await _openPayoutSheet(tester, market: MarketScope.kuwait, store: _storeWithSeveralCurrencies);

      await _type(tester, '12.345');
      await _requestPayout(tester);

      expect(service.requestedAmounts, <double>[12.345]);
    });

    testWidgets('Max fills in the balance cut to three decimals, and that amount can be requested as it stands', (WidgetTester tester) async {
      final _RecordingSellerCenterService service = await _openPayoutSheet(tester, market: MarketScope.kuwait, store: _storeWithSeveralCurrencies);

      await tester.tap(find.text('max'));
      await tester.pump();

      expect(_amountField(tester), '1234.569');

      await _requestPayout(tester);

      expect(service.requestedAmounts, <double>[1234.569]);
    });

    testWidgets('an amount above the balance is refused, down to the third decimal', (WidgetTester tester) async {
      final _RecordingSellerCenterService service = await _openPayoutSheet(tester, market: MarketScope.kuwait, store: _storeWithSeveralCurrencies);

      await _type(tester, '1234.570');
      await _requestPayout(tester);

      expect(find.text('amount_exceeds_withdrawable_balance'), findsOneWidget);
      expect(service.requestedAmounts, isEmpty);
    });
  });

  group('in Saudi Arabia', () {
    testWidgets('the field takes two decimals and refuses a third', (WidgetTester tester) async {
      await _openPayoutSheet(tester, market: MarketScope.saudiArabia, store: _storeWithSeveralCurrencies);

      await _type(tester, '12.345');

      expect(_amountField(tester), '12.34');
    });

    testWidgets('Max fills in the balance cut to two decimals, with no exchange rate applied', (WidgetTester tester) async {
      await _openPayoutSheet(tester, market: MarketScope.saudiArabia, store: _storeWithSeveralCurrencies);

      await tester.tap(find.text('max'));
      await tester.pump();

      expect(_amountField(tester), '1234.56');
    });
  });
}
