import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/features/auth/controllers/auth_controller.dart';
import 'package:syriacosmeticsmanger/localization/models/language_model.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

class LocalizationController extends ChangeNotifier {
  final SharedPreferences? sharedPreferences;

  LocalizationController({required this.sharedPreferences}) {
    _loadCurrentLanguage();
  }

  int? _languageIndex;
  Locale _locale = Locale(AppConstants.languages[0].languageCode!, AppConstants.languages[0].countryCode);
  bool _isLtr = true;
  Locale get locale => _locale;
  bool get isLtr => _isLtr;
  int? get languageIndex => _languageIndex;
  List<LanguageModel> _languages = [];
  List<LanguageModel> get languages => _languages;


  void setLanguage(Locale locale, int index) {
    _locale = locale;
    _languageIndex = index;
    if(_locale.languageCode == 'ar') {
      _isLtr = false;
    }else {
      _isLtr = true;
    }
    _saveLanguage(_locale);
    // The backend expects a LANGUAGE code. The old code sent the lowercased
    // COUNTRY code, so Arabic went out as 'sa' and never matched.
    Provider.of<AuthController>(Get.context!, listen: false).setCurrentLanguage(_locale.languageCode);
    DioClient.setLanguage(_locale.languageCode);
    initializeDateFormatting(_locale.languageCode, null);
    Intl.defaultLocale = _locale.languageCode;
    notifyListeners();
  }

  Future<void> _loadCurrentLanguage() async {
    _locale = Locale(sharedPreferences!.getString(AppConstants.languageCode) ?? AppConstants.languages[0].languageCode!,
        sharedPreferences!.getString(AppConstants.countryCode) ?? AppConstants.languages[0].countryCode);
    for(int index=0; index<AppConstants.languages.length; index++) {
      if(AppConstants.languages[index].languageCode == _locale.languageCode) {
        _languageIndex = index;
        break;
      }
    }
    _isLtr = _locale.languageCode != 'ar';
    DioClient.setLanguage(_locale.languageCode);
    initializeDateFormatting(_locale.languageCode, null);
    Intl.defaultLocale = _locale.languageCode;
    _languages = [];
    _languages.addAll(AppConstants.languages);
    notifyListeners();
  }

  Future<void> _saveLanguage(Locale locale) async {
    sharedPreferences!.setString(AppConstants.languageCode, locale.languageCode);
    sharedPreferences!.setString(AppConstants.countryCode, locale.countryCode!);
  }

  /// The language code the API should be told to use.
  ///
  /// This used to compare the preference KEY constant ('country_code') against
  /// 'US' — always false — and then return the stored COUNTRY code.
  String getCurrentLanguage() {
    return sharedPreferences!.getString(AppConstants.languageCode) ?? AppConstants.languages[0].languageCode ?? 'en';
  }

  /// Convenience for call sites that used to hardcode a literal 'en'.
  static String apiLanguageCode(BuildContext context) {
    try {
      return Provider.of<LocalizationController>(context, listen: false).locale.languageCode;
    } catch (_) {
      return 'en';
    }
  }


}