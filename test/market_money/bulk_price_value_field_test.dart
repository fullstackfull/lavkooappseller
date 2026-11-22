import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_button_widget.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/bulk_jobs/controllers/bulk_job_controller.dart';
import 'package:syriacosmeticsmanger/features/bulk_jobs/domain/services/bulk_job_service_interface.dart';
import 'package:syriacosmeticsmanger/features/bulk_jobs/screens/bulk_edit_screen.dart';
import 'package:syriacosmeticsmanger/features/product/domain/models/filter_model.dart';
import 'package:syriacosmeticsmanger/features/profile/controllers/profile_controller.dart';
import 'package:syriacosmeticsmanger/features/profile/domain/services/profice_service_interface.dart';
import 'package:syriacosmeticsmanger/features/splash/controllers/splash_controller.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/market_money.dart';
import 'package:syriacosmeticsmanger/localization/controllers/localization_controller.dart';
import 'package:syriacosmeticsmanger/theme/controllers/theme_controller.dart';

import 'support/money_store.dart';

ApiResponse _answer(Map<String, dynamic> body) =>
    ApiResponse.withSuccess(Response<Map<String, dynamic>>(requestOptions: RequestOptions(path: '/products'), statusCode: 200, data: body));

/// The bulk job API as far as a change of prices or of stock reaches it. It refuses the change, so the screen stays where it is, and keeps what the change
/// carried.
class _RecordingBulkJobService implements BulkJobServiceInterface {
  final List<({String mode, num value})> priceChanges = <({String mode, num value})>[];
  final List<({String mode, int value})> stockChanges = <({String mode, int value})>[];

  @override
  Future<dynamic> getSellerProductList({
    required String sellerId,
    required int offset,
    required String languageCode,
    required String search,
    FilterModel? filterModel,
  }) async =>
      _answer(<String, dynamic>{
        'total_size': 1,
        'limit': 10,
        'offset': 1,
        'products': <Map<String, dynamic>>[
          <String, dynamic>{'id': 7, 'name': 'Rose serum', 'unit_price': 12.5, 'purchase_price': 6, 'discount': 0, 'current_stock': 3},
        ],
      });

  @override
  Future<dynamic> submitPriceUpdate({required List<int> productIds, required String mode, required num value, num? discount, String? discountType}) async {
    priceChanges.add((mode: mode, value: value));
    return ApiResponse.withError('refused');
  }

  @override
  Future<dynamic> getBulkJobs({int offset = 1}) => throw UnimplementedError();

  @override
  Future<dynamic> getBulkJob(int id) => throw UnimplementedError();

  @override
  Future<dynamic> submitStockUpdate({required List<int> productIds, required String mode, required int value, String? note}) async {
    stockChanges.add((mode: mode, value: value));
    return ApiResponse.withError('refused');
  }

  @override
  Future<dynamic> downloadFailures(int id) => throw UnimplementedError();
}

/// The profile service is never reached: the bulk screen reads the seller's id from the controller, which has none yet.
class _UnreachedProfileService implements ProfileServiceInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

final Map<String, dynamic> _storeWithSeveralCurrencies = moneyStoreConfig(
  currencyModel: 'multi_currency',
  symbolPosition: 'right',
  decimals: 2,
  currencies: <Map<String, dynamic>>[moneyStoreCurrency(1, r'$', 'USD', 1), moneyStoreCurrency(2, 'SR', 'SAR', 3.75)],
);

/// Opens the bulk edit screen, chooses the only product and opens the sheet that [button] names: the change of prices or the change of stock.
Future<_RecordingBulkJobService> _openChange(WidgetTester tester, {required MarketScope? market, required String button}) async {
  MarketMoney.lookUpWith(market == null ? null : () => MarketMoney.forScope(market));
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final SplashController splash = await loadedSplashController(config: _storeWithSeveralCurrencies, shownCurrencyCode: 'SAR');
  final _RecordingBulkJobService service = _RecordingBulkJobService();

  await tester.pumpWidget(
    MultiProvider(
      providers: <ChangeNotifierProvider<ChangeNotifier>>[
        ChangeNotifierProvider<SplashController>.value(value: splash),
        ChangeNotifierProvider<ThemeController>.value(value: ThemeController(sharedPreferences: preferences)),
        ChangeNotifierProvider<LocalizationController>.value(value: LocalizationController(sharedPreferences: preferences)),
        ChangeNotifierProvider<ProfileController>.value(value: ProfileController(profileServiceInterface: _UnreachedProfileService())),
        ChangeNotifierProvider<BulkJobController>.value(value: BulkJobController(bulkJobServiceInterface: service)),
      ],
      child: const MaterialApp(home: BulkEditScreen()),
    ),
  );
  await tester.pump();
  await tester.pump();

  await tester.tap(find.text('Rose serum'));
  await tester.pump();
  await tester.tap(find.widgetWithText(CustomButtonWidget, button));
  await tester.pumpAndSettle();

  return service;
}

Future<_RecordingBulkJobService> _openPriceChange(WidgetTester tester, {required MarketScope? market}) =>
    _openChange(tester, market: market, button: 'bulk_change_price');

Future<_RecordingBulkJobService> _openStockChange(WidgetTester tester, {required MarketScope? market}) =>
    _openChange(tester, market: market, button: 'bulk_change_stock');

Finder get _valueField => find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField));

String _value(WidgetTester tester) => tester.widget<TextField>(_valueField).controller!.text;

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_valueField, text);
  await tester.pump();
}

Future<void> _choose(WidgetTester tester, String mode) async {
  await tester.tap(find.text('bulk_mode_$mode'));
  await tester.pump();
}

Future<void> _apply(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(CustomButtonWidget, 'apply'));
  await tester.pumpAndSettle();
}

TextInputType? _keyboard(WidgetTester tester) => tester.widget<TextField>(_valueField).keyboardType;

/// K-10.3: the value of a bulk price change takes the decimals of the market when it is an amount, keeps two when it is a percent, and is sent as typed. The value of
/// a change of stock is a count: it takes no decimals, in a market or out of one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => MarketMoney.lookUpWith(null));

  group('with no market working', () {
    testWidgets('a price is typed with two decimals, as it always was, and sent with them', (WidgetTester tester) async {
      final _RecordingBulkJobService service = await _openPriceChange(tester, market: null);

      await _type(tester, '12.3456');
      expect(_value(tester), '12.34');

      await _apply(tester);

      expect(service.priceChanges, <({String mode, num value})>[(mode: 'set', value: 12.34)]);
    });

    for (final String mode in <String>['increase_amount', 'decrease_amount']) {
      testWidgets('an amount to ${mode.split('_').first} takes two decimals as well, and is sent with them', (WidgetTester tester) async {
        final _RecordingBulkJobService service = await _openPriceChange(tester, market: null);
        await _choose(tester, mode);

        await _type(tester, '0.1256');
        expect(_value(tester), '0.12');

        await _apply(tester);

        expect(service.priceChanges, <({String mode, num value})>[(mode: mode, value: 0.12)]);
      });
    }

    testWidgets('a percent takes two decimals, as it always did, and is sent with them', (WidgetTester tester) async {
      final _RecordingBulkJobService service = await _openPriceChange(tester, market: null);

      for (final String mode in <String>['increase_percent', 'decrease_percent']) {
        await _choose(tester, mode);
        await _type(tester, '7.256');

        expect(_value(tester), '7.25', reason: mode);
      }

      await _apply(tester);

      expect(service.priceChanges, <({String mode, num value})>[(mode: 'decrease_percent', value: 7.25)]);
    });
  });

  group('in Kuwait', () {
    testWidgets('the list shows the price of the product in dinars', (WidgetTester tester) async {
      await _openPriceChange(tester, market: MarketScope.kuwait);

      expect(find.textContaining('12.500 KWD'), findsOneWidget);
    });

    testWidgets('a price to set is typed with three decimals and the fourth is refused', (WidgetTester tester) async {
      await _openPriceChange(tester, market: MarketScope.kuwait);

      await _type(tester, '12.345');
      expect(_value(tester), '12.345');

      await _type(tester, '12.3456');
      expect(_value(tester), '12.345');
    });

    testWidgets('the price to set is sent as it was typed, with three decimals', (WidgetTester tester) async {
      final _RecordingBulkJobService service = await _openPriceChange(tester, market: MarketScope.kuwait);

      await _type(tester, '12.345');
      await _apply(tester);

      expect(service.priceChanges, <({String mode, num value})>[(mode: 'set', value: 12.345)]);
    });

    testWidgets('the keyboard of a price has a decimal point', (WidgetTester tester) async {
      await _openPriceChange(tester, market: MarketScope.kuwait);

      expect(_keyboard(tester)?.decimal, isTrue);
    });

    for (final String mode in <String>['increase_amount', 'decrease_amount']) {
      testWidgets('an amount to ${mode.split('_').first} takes three decimals as well, and is sent with them', (WidgetTester tester) async {
        final _RecordingBulkJobService service = await _openPriceChange(tester, market: MarketScope.kuwait);
        await _choose(tester, mode);

        await _type(tester, '0.125');
        expect(_value(tester), '0.125');

        await _type(tester, '0.1256');
        expect(_value(tester), '0.125');

        await _apply(tester);

        expect(service.priceChanges, <({String mode, num value})>[(mode: mode, value: 0.125)]);
      });
    }

    testWidgets('a percent is not money, and keeps its two decimals', (WidgetTester tester) async {
      final _RecordingBulkJobService service = await _openPriceChange(tester, market: MarketScope.kuwait);

      for (final String mode in <String>['increase_percent', 'decrease_percent']) {
        await _choose(tester, mode);
        await _type(tester, '7.256');

        expect(_value(tester), '7.25', reason: mode);
      }

      await _apply(tester);

      expect(service.priceChanges, <({String mode, num value})>[(mode: 'decrease_percent', value: 7.25)]);
    });
  });

  group('in Saudi Arabia', () {
    testWidgets('a price to set is typed with two decimals and the third is refused', (WidgetTester tester) async {
      await _openPriceChange(tester, market: MarketScope.saudiArabia);

      await _type(tester, '12.345');

      expect(_value(tester), '12.34');
    });
  });

  group('a change of stock', () {
    for (final MarketScope? market in <MarketScope?>[null, MarketScope.kuwait]) {
      final String where = market == null ? 'with no market working' : 'in Kuwait';

      testWidgets('$where: takes whole units only, whichever way the stock is changed', (WidgetTester tester) async {
        await _openStockChange(tester, market: market);

        for (final String mode in <String>['set', 'increase', 'decrease']) {
          await _choose(tester, mode);
          await _type(tester, '12.5');

          expect(_value(tester), '12', reason: mode);
        }
      });

      testWidgets('$where: is sent as the whole number that was typed', (WidgetTester tester) async {
        final _RecordingBulkJobService service = await _openStockChange(tester, market: market);
        await _choose(tester, 'increase');

        await _type(tester, '12.5');
        await _apply(tester);

        expect(service.stockChanges, <({String mode, int value})>[(mode: 'increase', value: 12)]);
      });

      testWidgets('$where: keeps the keyboard of a count, which has no decimal point', (WidgetTester tester) async {
        await _openStockChange(tester, market: market);

        expect(_keyboard(tester)?.decimal, isFalse);
      });
    }
  });
}
