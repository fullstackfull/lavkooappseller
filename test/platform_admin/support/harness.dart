import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/localization/app_localization.dart';
import 'package:syriacosmeticsmanger/localization/controllers/localization_controller.dart';
import 'package:syriacosmeticsmanger/theme/controllers/theme_controller.dart';
import 'package:syriacosmeticsmanger/theme/dark_theme.dart' as dark_theme;
import 'package:syriacosmeticsmanger/theme/light_theme.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

/// The app around a screen of the platform admin shell, as `main.dart` builds it:
/// the real themes, the real language files, the real shared widgets, and the
/// providers those widgets read.
///
/// The language is set the way the app sets it, so the layout direction, the
/// strings and the dates all follow it.
abstract final class PlatformAdminHarness {
  static const Locale english = Locale('en', 'US');
  static const Locale arabic = Locale('ar', 'SY');

  /// A phone, in logical pixels.
  static const Size phone = Size(390, 844);

  /// The narrowest phone still in use.
  static const Size narrowPhone = Size(320, 640);

  /// A phone as wide as the common one and tall enough to hold a whole list, for tests of what a
  /// list says and not of how it scrolls: a list builds only what is on the screen.
  static const Size tallPhone = Size(390, 6000);

  static Future<Widget> app(
    WidgetTester tester, {
    required Widget home,
    PlatformAdminController? controller,
    Locale locale = english,
    double textScale = 1.0,
    bool darkTheme = false,
    List<NavigatorObserver> navigatorObservers = const <NavigatorObserver>[],
  }) async {
    // The language files are read from disk, which a widget test does not wait for, so they are read first and handed over as they are.
    final AppLocalization localization = AppLocalization(locale);
    await tester.runAsync(localization.load);
    await initializeDateFormatting(locale.languageCode, null);
    Intl.defaultLocale = locale.languageCode;
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppConstants.languageCode: locale.languageCode,
      AppConstants.countryCode: locale.countryCode!,
    });
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeController>(create: (_) => ThemeController(sharedPreferences: preferences)),
        ChangeNotifierProvider<LocalizationController>(
            create: (_) => LocalizationController(sharedPreferences: preferences)),
        if (controller != null) ChangeNotifierProvider<PlatformAdminController>.value(value: controller),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorObservers: navigatorObservers,
        theme: darkTheme ? dark_theme.dark : light,
        locale: locale,
        localizationsDelegates: [
          _LoadedLocalization(localization),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [arabic, english],
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: home,
      ),
    );
  }

  /// Gives the test the screen of a phone, and gives it back afterwards.
  static void useScreen(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// Every string on the screen, in the order it is drawn.
  static List<String> texts(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((Text text) => text.data ?? text.textSpan?.toPlainText() ?? '')
      .where((String text) => text.isNotEmpty)
      .toList();
}

/// The app's own delegate, with the language files already read: the real
/// [AppLocalization], its fallback to English and all, without waiting for the disk.
class _LoadedLocalization extends LocalizationsDelegate<AppLocalization> {
  final AppLocalization _loaded;

  const _LoadedLocalization(this._loaded);

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalization> load(Locale locale) => SynchronousFuture<AppLocalization>(_loaded);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalization> old) => false;
}
