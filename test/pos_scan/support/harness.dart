import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/localization/app_localization.dart';
import 'package:syriacosmeticsmanger/theme/dark_theme.dart' as dark_theme;
import 'package:syriacosmeticsmanger/theme/light_theme.dart';

/// The app around a widget of the point-of-sale scan, as `main.dart` builds it: the real themes, the real language
/// files, the app's own navigator key (which is how `Get.context` finds its way to the screen) and the providers the
/// code under test reads.
abstract final class PosScanHarness {
  static const Locale english = Locale('en', 'US');
  static const Locale arabic = Locale('ar', 'SY');

  /// The narrowest phone still in use, in logical pixels.
  static const Size narrowPhone = Size(320, 640);

  /// A common phone, in logical pixels.
  static const Size phone = Size(390, 844);

  static Future<Widget> app(
    WidgetTester tester, {
    required Widget home,
    List<SingleChildWidget> providers = const <SingleChildWidget>[],
    Locale locale = english,
    double textScale = 1.0,
    bool darkTheme = false,
  }) async {
    // The language files are read from disk, which a widget test does not wait for, so they are read first and handed over as they are.
    final AppLocalization localization = AppLocalization(locale);
    await tester.runAsync(localization.load);

    final MaterialApp app = MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: darkTheme ? dark_theme.dark : light,
      locale: locale,
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        _LoadedLocalization(localization),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[arabic, english],
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home,
    );

    return providers.isEmpty ? app : MultiProvider(providers: providers, child: app);
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

/// The app's own delegate, with the language files already read: the real [AppLocalization], its fallback to English
/// and all, without waiting for the disk.
class _LoadedLocalization extends LocalizationsDelegate<AppLocalization> {
  const _LoadedLocalization(this._loaded);

  final AppLocalization _loaded;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalization> load(Locale locale) => SynchronousFuture<AppLocalization>(_loaded);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalization> old) => false;
}
