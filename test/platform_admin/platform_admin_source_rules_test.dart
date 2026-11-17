import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What the source of the platform admin shell must not contain, read from the
/// source itself.
///
/// A behaviour test proves that today's code does not do something. These prove
/// that the code has no way to: no import that could reach the seller's session,
/// no call that could log, store or send what it must not, and no helper that
/// could turn a count into money. A change that adds one fails here, in the
/// review, instead of surfacing in a log on somebody's phone.
void main() {
  final List<File> sources = Directory('lib/features/platform_admin')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'))
      .toList()
    ..sort((File left, File right) => left.path.compareTo(right.path));

  /// The lines of every file with their number, comments left out, so that a
  /// sentence that says "never PriceConverter" is not mistaken for a use of it.
  final Map<String, List<(int, String)>> code = <String, List<(int, String)>>{
    for (final File file in sources)
      file.path: <(int, String)>[
        for (final (int index, String line) in file.readAsLinesSync().indexed)
          if (!line.trimLeft().startsWith('//')) (index + 1, line.replaceAll(RegExp(r'//.*$'), '')),
      ],
  };

  /// Every place a rule is broken, as `path:line`.
  List<String> offences(Pattern forbidden, {bool Function(String path)? except}) => <String>[
        for (final MapEntry<String, List<(int, String)>> file in code.entries)
          if (except == null || !except(file.key))
            for (final (int, String) line in file.value)
              if (line.$2.contains(forbidden)) '${file.key}:${line.$1}  ${line.$2.trim()}',
      ];

  test('the feature has sources to read, or every rule below proves nothing', () {
    expect(sources, isNotEmpty);
    expect(code.values.expand((List<(int, String)> lines) => lines), isNotEmpty);
  });

  group('the seller app', () {
    test(
        'has no way in: the seller client, its logger, its sign-in, its 401 handler and its saved credentials are not imported',
        () {
      expect(
        offences(RegExp(
            r'dio_client|DioClient|logging_interceptor|LoggingInterceptor|auth_controller|AuthController|auth_repository|AuthRepository|auth_service|api_checker|ApiChecker|secure_credential_store|SecureCredentialStore')),
        isEmpty,
      );
    });

    test(
        'imports only what a shared widget, a helper or the platform admin itself needs, and no seller screen, controller or repository',
        () {
      const List<String> allowed = <String>[
        'package:syriacosmeticsmanger/features/platform_admin/',
        'package:syriacosmeticsmanger/common/basewidgets/',
        'package:syriacosmeticsmanger/helper/date_converter.dart',
        'package:syriacosmeticsmanger/helper/email_checker.dart',
        'package:syriacosmeticsmanger/localization/',
        'package:syriacosmeticsmanger/theme/',
        'package:syriacosmeticsmanger/utill/',
      ];
      final List<String> foreign = <String>[
        for (final MapEntry<String, List<(int, String)>> file in code.entries)
          for (final (int, String) line in file.value)
            if (RegExp(r'''^\s*import\s+['"]package:syriacosmeticsmanger/''').hasMatch(line.$2) &&
                !allowed.any((String prefix) => line.$2.contains("'$prefix")))
              '${file.key}:${line.$1}  ${line.$2.trim()}',
      ];

      expect(foreign, isEmpty);
    });

    test('knows no seller route, no seller key, no seller header and no storefront', () {
      expect(
          offences(RegExp(
              r'/api/v1|/api/v3|seller/|loginUri|AppConstants\.(token|userPassword|userEmail|userNumber|sellerUri|storefront)')),
          isEmpty);
      expect(offences(RegExp(r'X-Storefront|X-localization|X-App-Version|storefront_country', caseSensitive: false)),
          isEmpty);
      expect(offences(RegExp(r'''['"]lang['"]''')), isEmpty);
    });
  });

  group('what leaves the phone, and what stays on it', () {
    test('nothing prints and nothing logs: not a print, not a debugPrint, not a logger', () {
      expect(
          offences(RegExp(r'\bprint\(|debugPrint|dart:developer|\blog\(|Logger|LogInterceptor|debugDumpApp')), isEmpty);
    });

    test('the preferences are not used to store anything, and are read only to learn the language', () {
      expect(
          offences(RegExp(r'SharedPreferences|shared_preferences'),
              except: (String path) => path.endsWith('platform_admin_dependencies.dart')),
          isEmpty);
      expect(
          offences(RegExp(r'\.(setString|setBool|setInt|setDouble|setStringList|remove|clear|reload)\('),
              except: (String path) => !path.endsWith('platform_admin_dependencies.dart')),
          isEmpty);
    });

    test('no database, no file and no other copy on disk', () {
      expect(
          offences(RegExp(
              r'drift|sqflite|\bsqlite|\bHive\b|isar|path_provider|dart:io|\bFile\(|\bDirectory\(|getApplicationDocuments|getTemporaryDirectory')),
          isEmpty);
    });

    test('the only secure storage is the token store, and it never clears more than its own key', () {
      expect(
          offences(RegExp(r'FlutterSecureStorage|flutter_secure_storage'),
              except: (String path) => path.endsWith('platform_admin_token_store.dart')),
          isEmpty);
      expect(offences(RegExp(r'deleteAll|readAll')), isEmpty);
    });

    test('no push topic, no analytics event and no crash report', () {
      expect(
          offences(RegExp(
              r'firebase|Firebase|subscribeToTopic|flutter_local_notifications|FlutterLocalNotifications|AppHealthReporter|Crashlytics|Analytics',
              caseSensitive: true)),
          isEmpty);
    });

    test('no response is kept by the HTTP layer: the cache interceptors and the seller response cache are not used',
        () {
      expect(
          offences(
              RegExp(r'CacheInterceptor|CacheOptions|dio_cache|http_cache|DioCacheInterceptor', caseSensitive: false)),
          isEmpty);
    });
  });
}
