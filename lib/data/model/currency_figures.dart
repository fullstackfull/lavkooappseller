/// One currency's own figures, as the seller API answers them in a `*_by_currency` list.
///
/// Where an account or a period holds more than one currency the server refuses the single total — a sum of riyals and dirhams
/// is not money — and answers each currency's real figures beside a reason instead (`SellerMarketTotals::money`). Every row is
/// `{"currency_code": "SAR", ...the named figures}`, so the names are read as they come rather than listed here: a figure the
/// answer adds reaches the screen without a model change, and a figure it drops is absent rather than zero.
///
/// A figure here is NEVER converted to the display currency. The point of the per-currency answer is that these are different
/// kinds of money.
class CurrencyFiguresModel {
  const CurrencyFiguresModel({this.currencyCode = '', this.figures = const <String, double>{}});

  final String currencyCode;
  final Map<String, double> figures;

  factory CurrencyFiguresModel.fromJson(Map<String, dynamic> json) {
    final Map<String, double> figures = <String, double>{};

    json.forEach((String key, dynamic value) {
      if (key == 'currency_code') return;
      final double? figure = value is num ? value.toDouble() : double.tryParse('$value');
      if (figure != null) figures[key] = figure;
    });

    return CurrencyFiguresModel(currencyCode: json['currency_code']?.toString() ?? '', figures: figures);
  }

  /// The rows of a `*_by_currency` member, and nothing at all for anything else: a malformed list is no breakdown, never a
  /// breakdown of zeros.
  static List<CurrencyFiguresModel> listFrom(dynamic value) => value is List
      ? value
          .whereType<Map>()
          .map((Map<dynamic, dynamic> row) => CurrencyFiguresModel.fromJson(Map<String, dynamic>.from(row)))
          .toList()
      : const <CurrencyFiguresModel>[];

  double? operator [](String name) => figures[name];
}
