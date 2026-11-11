import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

class AppLocalization {
  AppLocalization(this.locale);

  final Locale locale;

  static const String _fallbackLanguageCode = 'en';

  static AppLocalization? of(BuildContext context) {
    return Localizations.of<AppLocalization>(context, AppLocalization);
  }

  Map<String, String> _localizedValues = <String, String>{};

  /// English values, loaded alongside the active locale so a key that is missing
  /// from the active language file falls back to readable English instead of
  /// leaking a raw snake_case key onto the screen.
  Map<String, String> _fallbackValues = <String, String>{};

  Future<Map<String, String>> _loadLanguageFile(String languageCode) async {
    try {
      final String jsonStringValues = await rootBundle.loadString('assets/language/$languageCode.json');
      final Map<String, dynamic> mappedJson = json.decode(jsonStringValues);
      return mappedJson.map((key, value) => MapEntry(key.trim(), value.toString()));
    } catch (error) {
      debugPrint('AppLocalization: failed to load "$languageCode.json" --- $error');
      return <String, String>{};
    }
  }

  Future<void> load() async {
    _localizedValues = await _loadLanguageFile(locale.languageCode);

    if (locale.languageCode != _fallbackLanguageCode) {
      _fallbackValues = await _loadLanguageFile(_fallbackLanguageCode);
    } else {
      _fallbackValues = _localizedValues;
    }
  }

  /// Never throws: an unknown key resolves to the English value when there is
  /// one, otherwise to the key itself (which lets server-supplied messages pass
  /// through this method unchanged).
  String? translate(String? key) {
    if (key == null) return null;
    return _localizedValues[key] ?? _fallbackValues[key] ?? key;
  }

  /// True when the key is a real entry in some language file, as opposed to
  /// arbitrary text that merely passed through [translate].
  bool hasKey(String? key) {
    if (key == null) return false;
    return _localizedValues.containsKey(key) || _fallbackValues.containsKey(key);
  }

  static const LocalizationsDelegate<AppLocalization> delegate = _DemoLocalizationsDelegate();
}

class _DemoLocalizationsDelegate extends LocalizationsDelegate<AppLocalization> {
  const _DemoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    List<String?> languageString = [];
    for (var language in AppConstants.languages) {
      languageString.add(language.languageCode);
    }
    return languageString.contains(locale.languageCode);
  }

  @override
  Future<AppLocalization> load(Locale locale) async {
    AppLocalization localization = AppLocalization(locale);
    await localization.load();
    return localization;
  }

  @override
  bool shouldReload(LocalizationsDelegate<AppLocalization> old) => false;
}


extension StringExtension on String {
  String toCapitalized() => length > 0 ?'${this[0].toUpperCase()}${substring(1).toLowerCase()}':'';
  String toTitleCase() => replaceAll(RegExp('_'), ' ').split(' ').map((str) => str.toCapitalized()).join(' ');

  String camelCaseToSnakeCase() {
    return replaceAllMapped(
        RegExp(r'([A-Z])'),
            (Match match) =>
        "_${match.group(1)!.toLowerCase()}");
  }
}
