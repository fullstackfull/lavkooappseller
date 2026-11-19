import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/coupon_discount_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/services/cart_service_interface.dart';
import 'package:syriacosmeticsmanger/features/pos/widgets/extra_discount_and_coupon_dialog_widget.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/market_money.dart';
import 'package:syriacosmeticsmanger/localization/controllers/localization_controller.dart';
import 'package:syriacosmeticsmanger/theme/controllers/theme_controller.dart';

/// The cart service is never reached: the dialog only reads and writes the text of its field until the seller applies the discount.
class _UnreachedCartService implements CartServiceInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

/// Opens the dialog of the extra discount of a sale, with the discount as an amount or as a percent.
Future<void> _openDialog(WidgetTester tester, {required MarketScope? market, required bool asPercent}) async {
  MarketMoney.lookUpWith(market == null ? null : () => MarketMoney.forScope(market));
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final CouponDiscountController discount = CouponDiscountController(cartServiceInterface: _UnreachedCartService());
  if (asPercent) {
    discount.setSelectedDiscountType('percent', isUpdate: false);
    discount.setDiscountTypeIndex(1, false);
  }

  await tester.pumpWidget(
    MultiProvider(
      providers: <ChangeNotifierProvider<ChangeNotifier>>[
        ChangeNotifierProvider<CouponDiscountController>.value(value: discount),
        ChangeNotifierProvider<ThemeController>.value(value: ThemeController(sharedPreferences: preferences)),
        ChangeNotifierProvider<LocalizationController>.value(value: LocalizationController(sharedPreferences: preferences)),
      ],
      child: const MaterialApp(home: Scaffold(body: ExtraDiscountAndCouponDialogWidget(payable: 100))),
    ),
  );
  await tester.pump();
}

String _discountField(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField)).controller!.text;

TextInputType? _keyboard(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField)).keyboardType;

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

/// K-10.3: the extra discount of a sale takes the decimals of the market, and a keyboard with a decimal point, while it is an amount. While it is a percent, or while
/// no market is working, it keeps the formatters and the number pad it had.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => MarketMoney.lookUpWith(null));

  group('a discount in money', () {
    testWidgets('with no market working takes any number of decimals, as it always did', (WidgetTester tester) async {
      await _openDialog(tester, market: null, asPercent: false);

      await _type(tester, '1.23456');

      expect(_discountField(tester), '1.23456');
    });

    testWidgets('with no market working keeps the number pad it always had', (WidgetTester tester) async {
      await _openDialog(tester, market: null, asPercent: false);

      expect(_keyboard(tester), TextInputType.number);
    });

    testWidgets('in Kuwait has a keyboard with a decimal point, so that 0.500 can be typed on a phone whose number pad has none', (WidgetTester tester) async {
      await _openDialog(tester, market: MarketScope.kuwait, asPercent: false);

      expect(_keyboard(tester), const TextInputType.numberWithOptions(decimal: true));
    });

    testWidgets('in Saudi Arabia has a keyboard with a decimal point', (WidgetTester tester) async {
      await _openDialog(tester, market: MarketScope.saudiArabia, asPercent: false);

      expect(_keyboard(tester), const TextInputType.numberWithOptions(decimal: true));
    });

    testWidgets('in Kuwait takes three decimals and refuses a fourth', (WidgetTester tester) async {
      await _openDialog(tester, market: MarketScope.kuwait, asPercent: false);

      await _type(tester, '1.234');
      expect(_discountField(tester), '1.234');

      await _type(tester, '1.2345');
      expect(_discountField(tester), '1.234');
    });

    testWidgets('in Saudi Arabia takes two decimals and refuses a third', (WidgetTester tester) async {
      await _openDialog(tester, market: MarketScope.saudiArabia, asPercent: false);

      await _type(tester, '1.234');

      expect(_discountField(tester), '1.23');
    });
  });

  group('a discount in percent', () {
    testWidgets('in Kuwait is not money: its field has no formatter of the market', (WidgetTester tester) async {
      await _openDialog(tester, market: MarketScope.kuwait, asPercent: true);

      final List<TextInputFormatter> formatters = tester.widget<TextField>(find.byType(TextField)).inputFormatters ?? <TextInputFormatter>[];

      expect(formatters, isNotEmpty);
      expect(formatters, everyElement(isNot(isA<MoneyInputFormatter>())));
    });

    testWidgets('in Kuwait still takes the two digits it always took', (WidgetTester tester) async {
      await _openDialog(tester, market: MarketScope.kuwait, asPercent: true);

      await _type(tester, '15');

      expect(_discountField(tester), '15');
    });

    testWidgets('in Kuwait keeps the number pad it always had, as a percent has no use for a decimal point of its own', (WidgetTester tester) async {
      await _openDialog(tester, market: MarketScope.kuwait, asPercent: true);

      expect(_keyboard(tester), TextInputType.number);
    });

    testWidgets('with no market working keeps the number pad and the formatter of the shared amount field', (WidgetTester tester) async {
      await _openDialog(tester, market: null, asPercent: true);

      expect(_keyboard(tester), TextInputType.number);
      expect(tester.widget<TextField>(find.byType(TextField)).inputFormatters, everyElement(isNot(isA<MoneyInputFormatter>())));
    });
  });
}
