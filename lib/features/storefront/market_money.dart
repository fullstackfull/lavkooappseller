import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/storefront_config.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

/// How money is written in the market a seller works in.
///
/// The server answers each storefront's amounts in that storefront's own
/// currency, so in a market an amount is already in the market's currency: it is
/// never multiplied by an exchange rate, it carries the currency code of the
/// market, and it has the decimals of that currency. [current] is null while
/// storefronts are off, while no GCC market is stored and in All Markets; the
/// shared currency settings of the config write the money then, as they always
/// have.
class MarketMoney {
  const MarketMoney._({required this.currencyCode, required this.decimals});

  final String currencyCode;
  final int decimals;

  /// Digits read past the decimals before an amount is cut, so that an amount
  /// that floating point puts a hair under a whole unit of its last decimal,
  /// such as 4.35 * 100 = 434.99999999999994, is not cut one unit short.
  static const int _guardDigits = 4;

  static ValueGetter<MarketMoney?> _lookUp = _fromStoredMarket;

  /// The money of [scope], or null for All Markets, which has no currency.
  static MarketMoney? forScope(MarketScope scope) {
    final String? currencyCode = scope.currencyCode;
    final int? decimals = scope.decimals;
    if (currencyCode == null || decimals == null) {
      return null;
    }

    return MarketMoney._(currencyCode: currencyCode, decimals: decimals);
  }

  /// The money of the market [preferences] hold, or null when they hold no GCC
  /// market.
  static MarketMoney? fromPreferences(SharedPreferences preferences) {
    final Object? stored = preferences.get(AppConstants.storefrontCountry);
    final MarketScope? scope =
        MarketScope.fromCountryCode(stored is String ? stored : null);

    return scope == null ? null : forScope(scope);
  }

  /// The money of the market the app has stored in the preferences registered
  /// with the service locator, or null when none are registered.
  static MarketMoney? fromRegisteredPreferences() {
    final GetIt locator = GetIt.instance;

    return locator.isRegistered<SharedPreferences>()
        ? fromPreferences(locator<SharedPreferences>())
        : null;
  }

  /// The money of the market the seller works in now, or null when the shared
  /// currency settings of the config write the money.
  static MarketMoney? current() => _lookUp();

  /// Makes [current] answer with [lookUp] until it is given null again. The flag
  /// is a compile-time constant, so a test cannot turn it on and works in a
  /// market through this.
  @visibleForTesting
  static void lookUpWith(ValueGetter<MarketMoney?>? lookUp) {
    _lookUp = lookUp ?? _fromStoredMarket;
  }

  static MarketMoney? _fromStoredMarket() =>
      StorefrontConfig.enabled ? fromRegisteredPreferences() : null;

  /// The formatters of a field that takes money. In a market they are the
  /// shared [MoneyInputFormatter] with the decimals of the market's currency;
  /// outside one they are [outsideMarket], which is what the field had before,
  /// or null to keep the formatters the field's widget picks itself.
  static List<TextInputFormatter>? inputFormatters(
      {List<TextInputFormatter>? outsideMarket}) {
    final MarketMoney? market = current();

    return market == null
        ? outsideMarket
        : <TextInputFormatter>[MoneyInputFormatter(decimals: market.decimals)];
  }

  /// [amount] as digits with the decimals of the currency, without the currency
  /// code or grouping: the form an amount is typed and parsed in. [truncate]
  /// cuts the amount instead of rounding it, so a balance is never shown higher
  /// than it is.
  String amountText(double amount, {bool truncate = false}) {
    final String text = truncate ? _truncated(amount) : _rounded(amount);

    return double.parse(text) == 0 ? text.replaceFirst('-', '') : text;
  }

  /// [amount] as a price: grouped in thousands, with the currency code on the
  /// right of the digits when [markOnRight], and on the left otherwise.
  String amountWithCurrency(double amount,
      {required bool markOnRight, bool truncate = false}) {
    final String digits = _grouped(amountText(amount, truncate: truncate));

    return markOnRight ? '$digits $currencyCode' : '$currencyCode $digits';
  }

  /// Commas in the whole part only, so that none lands among the decimals.
  static String _grouped(String amount) {
    final List<String> parts = amount.split('.');
    final String wholePart = parts.first.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match match) => '${match[1]},',
    );

    return <String>[wholePart, ...parts.skip(1)].join('.');
  }

  String _rounded(double amount) {
    final num scale = pow(10.0, decimals);

    return ((amount * scale).roundToDouble() / scale).toStringAsFixed(decimals);
  }

  String _truncated(double amount) {
    if (!amount.isFinite) {
      return amount.toString();
    }

    final String guarded = amount.toStringAsFixed(decimals + _guardDigits);

    return guarded.substring(0, guarded.length - _guardDigits);
  }
}

/// An amount of money typed by hand: digits, one decimal point and at most
/// [decimals] digits after it. A digit typed beyond that is refused as it is
/// typed, so what a seller reads in the field is what is sent.
class MoneyInputFormatter extends FilteringTextInputFormatter {
  MoneyInputFormatter({required this.decimals})
      : super.allow(RegExp('^\\d*\\.?\\d{0,$decimals}'));

  final int decimals;
}
