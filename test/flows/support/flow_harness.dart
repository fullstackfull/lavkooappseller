import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_toast.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:syriacosmeticsmanger/localization/app_localization.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

import 'scripted_adapter.dart';

/// The app around a seller flow, as `main.dart` builds it where the flows are concerned: the app's own navigator key
/// (which is how `Get.context` finds its way to the screen), the real language files, and the providers the code under
/// test reads. The network is a scripted adapter, so what is asserted is what the app sends and what it does with the
/// answer, never a server.
abstract final class FlowHarness {
  static const Locale english = Locale('en', 'US');
  static const Locale arabic = Locale('ar', 'SY');

  /// The session the seller is signed in with: longer than the 30 characters the seller API insists on.
  static const String sessionToken = 'dummy-session-token-of-the-flow-tests';

  /// The text a screen of a flow shows while it is open, so that a test can tell when the handler closed it.
  static const String openScreenText = 'the screen the flow was started from';

  static Future<DioClient> client(
    ScriptedAdapter adapter, {
    String? token = sessionToken,
    String language = 'en',
  }) async {
    final SharedPreferences preferences = await signedIn(token: token, language: language);
    return DioClient(
      AppConstants.baseUrl,
      Dio()..httpClientAdapter = adapter,
      loggingInterceptor: _QuietLoggingInterceptor(),
      sharedPreferences: preferences,
    );
  }

  static Future<SharedPreferences> signedIn({String? token = sessionToken, String language = 'en'}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppConstants.languageCode: language,
      if (token != null) AppConstants.token: token,
    });
    return SharedPreferences.getInstance();
  }

  /// The headers every request of a signed-in seller carries.
  static void expectSignedIn(RecordedRequest request, {String language = 'en'}) {
    expect(request.headers['authorization'], 'Bearer $sessionToken',
        reason: 'the request carries the seller\'s session');
    expect(request.headers['accept'], 'application/json');
    expect(request.headers[AppConstants.langKey], language);
    if (request.method == 'POST') {
      expect(request.headers['content-type'], contains('application/json'),
          reason: 'the body travels as JSON, which is how the API reads it');
    }
  }

  static Future<Widget> app(
    WidgetTester tester, {
    List<SingleChildWidget> providers = const <SingleChildWidget>[],
    Locale locale = english,
    List<NavigatorObserver> observers = const <NavigatorObserver>[],
  }) async {
    // The language files are read from disk, which a widget test does not wait for, so they are read first and handed
    // over as they are.
    final AppLocalization localization = AppLocalization(locale);
    await tester.runAsync(localization.load);

    final MaterialApp app = MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      navigatorObservers: observers,
      locale: locale,
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        _LoadedLocalization(localization),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[arabic, english],
      home: const Scaffold(body: Text('home')),
    );

    return providers.isEmpty ? app : MultiProvider(providers: providers, child: app);
  }

  /// Puts the app on screen, with a second screen on top of its home: the one a flow's success handler is expected to
  /// close, and the one a refusal is expected to leave open.
  static Future<void> pump(
    WidgetTester tester, {
    List<SingleChildWidget> providers = const <SingleChildWidget>[],
    Locale locale = english,
    List<NavigatorObserver> observers = const <NavigatorObserver>[],
    Widget screen = const Scaffold(body: Text(openScreenText)),
  }) async {
    await tester.pumpWidget(await app(tester, providers: providers, locale: locale, observers: observers));
    navigatorKey.currentState!.push(MaterialPageRoute<void>(builder: (BuildContext context) => screen));
    await tester.pumpAndSettle();
  }

  /// Gives the test the screen of a tall phone, and gives it back afterwards.
  static void useScreen(WidgetTester tester, {Size size = const Size(400, 1000)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// Runs what the seller's tap would run, on the real clock, and lets the screen settle on what the seller would see:
  /// a snack bar is shown for a moment and then gone, so the screen is stepped to the moment it is on show.
  /// The real clock runs a moment longer than the call, because a handler may start a read it does not wait for.
  /// A call that throws fails the test.
  static Future<T> call<T>(WidgetTester tester, Future<T> Function() call) async {
    final T result = (await tester.runAsync(() async {
      final T answer = await call();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return answer;
    })) as T;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));
    return result;
  }

  /// Every message on show in a toast, in the order they are drawn.
  static List<String> shown(WidgetTester tester) => tester
      .widgetList<Text>(find.descendant(of: find.byType(CustomToast), matching: find.byType(Text)))
      .map((Text text) => text.data ?? '')
      .toList();

  /// Whether the screen the flow was started from is still open.
  static bool screenIsOpen(WidgetTester tester) => find.text(openScreenText).evaluate().isNotEmpty;

  /// Lets the seller's own clock run until the toast on show is gone, so that the one queued behind it is on show.
  static Future<void> dismissToast(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// The routes a flow pushed and removed, for a handler whose target screen is too large to build in a test.
class RouteLog extends NavigatorObserver {
  final List<Route<dynamic>> pushed = <Route<dynamic>>[];
  final List<Route<dynamic>> removed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushed.add(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => removed.add(route);
}

/// The app's own interceptor, without the lines it prints for every request: a flow test reads the request from the
/// adapter, and a run of hundreds of them should not bury a failure under its own log.
class _QuietLoggingInterceptor extends LoggingInterceptor {
  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async => handler.next(options);

  @override
  Future<void> onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) async =>
      handler.next(response);

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async => handler.next(err);
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
