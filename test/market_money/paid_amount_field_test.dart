import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/features/pos/widgets/paid_amount_field_widget.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/market_money.dart';
import 'package:syriacosmeticsmanger/theme/controllers/theme_controller.dart';

/// Opens the field of the cash a customer paid, the way the point of sale builds it, in [market] or in no market when it is null. The list it returns holds what
/// the field reported as typed.
Future<List<String>> _openField(WidgetTester tester, {required MarketScope? market, bool isEnabled = true}) async {
  MarketMoney.lookUpWith(market == null ? null : () => MarketMoney.forScope(market));
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final List<String> typed = <String>[];
  final TextEditingController controller = TextEditingController();
  final FocusNode focusNode = FocusNode();
  addTearDown(controller.dispose);
  addTearDown(focusNode.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeController>.value(
      value: ThemeController(sharedPreferences: preferences),
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 45,
            width: 150,
            child: PaidAmountFieldWidget(
              controller: controller,
              focusNode: focusNode,
              isEnabled: isEnabled,
              isPaidAmountLess: false,
              onChanged: typed.add,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  return typed;
}

TextField _field(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField));

String _text(WidgetTester tester) => _field(tester).controller!.text;

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

/// K-10.3: the cash a customer paid at the point of sale is typed in the decimals of the market, on a keyboard that has a decimal point, and is the field it always
/// was while no market is working.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => MarketMoney.lookUpWith(null));

  group('with no market working', () {
    testWidgets('the keyboard is the number pad, as it always was', (WidgetTester tester) async {
      await _openField(tester, market: null);

      expect(_field(tester).keyboardType, TextInputType.number);
    });

    testWidgets('the field takes digits and points, with any number of decimals, as it always did', (WidgetTester tester) async {
      await _openField(tester, market: null);

      await _type(tester, '12.3456');
      expect(_text(tester), '12.3456');

      await _type(tester, '1a2,3-4');
      expect(_text(tester), '1234');

      await _type(tester, '1.2.3');
      expect(_text(tester), '1.2.3', reason: 'the points are not limited to one, as they never were');
    });

    testWidgets('the formatter is the one of the shared amount field, not the one of a market', (WidgetTester tester) async {
      await _openField(tester, market: null);

      expect(_field(tester).inputFormatters, hasLength(1));
      expect(_field(tester).inputFormatters!.single, isNot(isA<MoneyInputFormatter>()));
    });
  });

  group('in Kuwait', () {
    testWidgets('the keyboard has a decimal point', (WidgetTester tester) async {
      await _openField(tester, market: MarketScope.kuwait);

      expect(_field(tester).keyboardType, const TextInputType.numberWithOptions(decimal: true));
    });

    testWidgets('the field takes three decimals and refuses a fourth', (WidgetTester tester) async {
      await _openField(tester, market: MarketScope.kuwait);

      await _type(tester, '12.345');
      expect(_text(tester), '12.345');

      await _type(tester, '12.3456');
      expect(_text(tester), '12.345');
    });

    testWidgets('the formatter is the shared one of the market, with three decimals', (WidgetTester tester) async {
      await _openField(tester, market: MarketScope.kuwait);

      expect(_field(tester).inputFormatters, hasLength(1));
      expect(
        _field(tester).inputFormatters!.single,
        isA<MoneyInputFormatter>().having((MoneyInputFormatter formatter) => formatter.decimals, 'decimals', 3),
      );
    });

    testWidgets('the field refuses a second point and what is not a digit', (WidgetTester tester) async {
      await _openField(tester, market: MarketScope.kuwait);

      await _type(tester, '1.2.3');
      expect(_text(tester), '1.2');

      await _type(tester, '12a');
      expect(_text(tester), '12');
    });

    testWidgets('what the field reports as typed is the amount as it stands in the field', (WidgetTester tester) async {
      final List<String> typed = await _openField(tester, market: MarketScope.kuwait);

      await _type(tester, '12.3456');

      expect(typed, <String>['12.345']);
    });
  });

  group('in Saudi Arabia', () {
    testWidgets('the keyboard has a decimal point and the field takes two decimals and refuses a third', (WidgetTester tester) async {
      await _openField(tester, market: MarketScope.saudiArabia);

      expect(_field(tester).keyboardType, const TextInputType.numberWithOptions(decimal: true));

      await _type(tester, '12.345');

      expect(_text(tester), '12.34');
    });
  });

  group('as the point of sale builds it', () {
    testWidgets('the field is shut for a payment that is not in cash', (WidgetTester tester) async {
      await _openField(tester, market: null, isEnabled: false);

      expect(_field(tester).enabled, isFalse);
    });

    testWidgets('the field is open for a payment in cash, and hints at an amount', (WidgetTester tester) async {
      await _openField(tester, market: null);

      expect(_field(tester).enabled, isTrue);
      expect(_field(tester).decoration!.hintText, 'amount');
    });

    testWidgets('what the field reports as typed, with no market working, is what was typed', (WidgetTester tester) async {
      final List<String> typed = await _openField(tester, market: null);

      await _type(tester, '12.3456');

      expect(typed, <String>['12.3456']);
    });
  });
}
