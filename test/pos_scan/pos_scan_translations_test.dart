import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';

/// Every string the scan flow shows exists in English and in Arabic, and the Arabic is Arabic.
const List<String> _keys = <String>[
  'scan_shared_code_title',
  'scan_shared_code_choose_country',
  'scan_shared_code_open_list',
  'scan_open_product_list',
  'scan_market_unavailable',
  'scan_country_sa',
  'scan_country_ae',
  'scan_country_kw',
  'scan_country_qa',
  'scan_country_bh',
  'scan_country_om',
];

Map<String, dynamic> _language(String code) =>
    jsonDecode(File('assets/language/$code.json').readAsStringSync()) as Map<String, dynamic>;

String _usedKeysSource() => <String>[
      'lib/features/pos/widgets/ambiguous_code_sheet_widget.dart',
      'lib/features/pos/controllers/barcode_scan_controller.dart',
    ].map((String path) => File(path).readAsStringSync()).join('\n');

void main() {
  final Map<String, dynamic> english = _language('en');
  final Map<String, dynamic> arabic = _language('ar');
  final RegExp arabicLetter = RegExp(r'[؀-ۿ]');
  final RegExp latinLetter = RegExp(r'[A-Za-z]');

  test('every key is in both language files, with a text', () {
    for (final String key in _keys) {
      expect(english[key], isA<String>(), reason: 'en: $key');
      expect((english[key] as String).trim(), isNotEmpty, reason: 'en: $key');
      expect(arabic[key], isA<String>(), reason: 'ar: $key');
      expect((arabic[key] as String).trim(), isNotEmpty, reason: 'ar: $key');
    }
  });

  test('the Arabic is Arabic: it has Arabic letters, no Latin ones, and is not the English text', () {
    for (final String key in _keys) {
      final String text = arabic[key] as String;
      expect(arabicLetter.hasMatch(text), isTrue, reason: key);
      expect(latinLetter.hasMatch(text), isFalse, reason: key);
      expect(text, isNot(english[key]), reason: key);
    }
  });

  test('a market has a name for each of the six countries the server configures', () {
    final Set<String> keysOfMarkets =
        MarketScope.gccMarkets.map((MarketScope market) => 'scan_country_${market.countryCode!.toLowerCase()}').toSet();

    expect(keysOfMarkets, hasLength(6));
    expect(keysOfMarkets, _keys.where((String key) => key.startsWith('scan_country_')).toSet());
  });

  test('the texts carry no placeholder, because nothing fills one in', () {
    for (final String key in _keys) {
      for (final Map<String, dynamic> language in <Map<String, dynamic>>[english, arabic]) {
        expect(language[key], isNot(contains('{')), reason: key);
        expect(language[key], isNot(contains('%')), reason: key);
      }
    }
  });

  test('every key is read through getTranslated with a literal, which is what the translation check can see', () {
    final String source = _usedKeysSource();

    for (final String key in _keys) {
      expect(RegExp("getTranslated\\(\\s*'$key'").hasMatch(source), isTrue, reason: key);
    }
  });
}
