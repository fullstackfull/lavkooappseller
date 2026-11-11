import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/finance_control/domain/models/finance_control_models.dart';

/// Captured from a running backend
/// (`/api/v3/seller/seller-center/finance/pricing-policy`).
///
/// The first case is this marketplace's actual state, and it is the interesting
/// one: no floor set, and — more importantly — not a single product with a
/// recorded cost. A margin floor here would be switched on, look like
/// protection, and refuse nothing at all. The screen has to say that, so the
/// model has to carry it.
void main() {
  const String liveEmpty = '''
  {"min_margin_percent":null,"min_price":null,"enforce":false,"binding":false,
   "products_with_a_cost":0,"products_total":2}''';

  const String liveMarginOnly = '''
  {"min_margin_percent":15,"min_price":null,"enforce":true,"binding":true,
   "products_with_a_cost":0,"products_total":2}''';

  const String onButEmpty = '''
  {"min_margin_percent":null,"min_price":null,"enforce":true,"binding":false,
   "products_with_a_cost":4,"products_total":9}''';

  const String working = '''
  {"min_margin_percent":20,"min_price":50,"enforce":true,"binding":true,
   "products_with_a_cost":9,"products_total":9}''';

  PricingPolicyModel parse(String payload) =>
      PricingPolicyModel.fromJson(jsonDecode(payload) as Map<String, dynamic>);

  test('a shop that has set no floor is not pretending to have one', () {
    final PricingPolicyModel policy = parse(liveEmpty);

    expect(policy.enforce, isFalse);
    expect(policy.binding, isFalse);
    expect(policy.minMarginPercent, isNull);
    expect(policy.onButEmpty, isFalse);
  });

  test('a margin floor over a catalogue with no costs covers nothing', () {
    final PricingPolicyModel policy = parse(liveMarginOnly);

    // Switched on, binding as far as the server is concerned, and able to speak
    // about none of the catalogue. Exactly the case that looks like protection
    // and is not.
    expect(policy.enforce, isTrue);
    expect(policy.binding, isTrue);
    expect(policy.marginCoversNothing, isTrue);
  });

  test('a floor switched on with nothing in it says so', () {
    final PricingPolicyModel policy = parse(onButEmpty);

    expect(policy.onButEmpty, isTrue);
    // Not the same as a floor of zero.
    expect(policy.minPrice, isNull);
    expect(policy.minMarginPercent, isNull);
  });

  test('a floor that actually works reports neither warning', () {
    final PricingPolicyModel policy = parse(working);

    expect(policy.onButEmpty, isFalse);
    expect(policy.marginCoversNothing, isFalse);
    expect(policy.minMarginPercent, 20);
    expect(policy.minPrice, 50);
    expect(policy.productsWithACost, policy.productsTotal);
  });

  test('a numeric field that arrives as a string still parses', () {
    // PHP decimals come back as strings from some drivers, and a floor the app
    // silently read as null would be a floor the seller thinks is set.
    final PricingPolicyModel policy = PricingPolicyModel.fromJson(
      jsonDecode('{"min_margin_percent":"12.50","min_price":"7","enforce":true,"binding":true,'
              '"products_with_a_cost":"3","products_total":"4"}')
          as Map<String, dynamic>,
    );

    expect(policy.minMarginPercent, 12.5);
    expect(policy.minPrice, 7);
    expect(policy.productsWithACost, 3);
  });
}
