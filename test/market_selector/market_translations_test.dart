import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const Map<String, String> _english = <String, String>{
  'market': 'Market',
  'select_market': 'Select market',
  'market_saudi_arabia': 'Saudi Arabia',
  'market_united_arab_emirates': 'United Arab Emirates',
  'market_kuwait': 'Kuwait',
  'market_qatar': 'Qatar',
  'market_bahrain': 'Bahrain',
  'market_oman': 'Oman',
};

const Map<String, String> _arabic = <String, String>{
  'market': 'السوق',
  'select_market': 'اختر السوق',
  'market_saudi_arabia': 'المملكة العربية السعودية',
  'market_united_arab_emirates': 'الإمارات العربية المتحدة',
  'market_kuwait': 'الكويت',
  'market_qatar': 'قطر',
  'market_bahrain': 'البحرين',
  'market_oman': 'عُمان',
};

Map<String, dynamic> _language(String code) =>
    jsonDecode(File('assets/language/$code.json').readAsStringSync()) as Map<String, dynamic>;

/// What the seller reads when choosing a market: the six countries by their standard names, and the words around them, in both
/// languages of the app.
void main() {
  test('the language files give the words of the market selector in English', () {
    final Map<String, dynamic> words = _language('en');

    for (final MapEntry<String, String> entry in _english.entries) {
      expect(words[entry.key], entry.value, reason: entry.key);
    }
  });

  test('the language files give the words of the market selector in Arabic, with the standard names of the six countries', () {
    final Map<String, dynamic> words = _language('ar');

    for (final MapEntry<String, String> entry in _arabic.entries) {
      expect(words[entry.key], entry.value, reason: entry.key);
    }
  });
}
