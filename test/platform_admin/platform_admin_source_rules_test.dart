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
        'package:syriacosmeticsmanger/features/reports/widgets/report_widgets.dart',
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

  group('the second step of the sign-in', () {
    /// The only files that may know what the server gave for the second step: the model that reads it, the layers that carry it and the controller that holds it.
    bool mayKnowTheChallenge(String path) => <String>[
          'platform_admin_mfa_models.dart',
          'platform_admin_session_models.dart',
          'platform_admin_repository.dart',
          'platform_admin_repository_interface.dart',
          'platform_admin_service.dart',
          'platform_admin_service_interface.dart',
          'platform_admin_controller.dart',
        ].any(path.endsWith);

    test('the challenge is named only where it is read, carried and held, and in no screen, text, store or failure',
        () {
      // The name of an action of the audit log, auth.mfa_challenge, is a line of the log and not the secret.
      expect(offences(RegExp(r'(?<!mfa_)[cC]hallenge'), except: mayKnowTheChallenge), isEmpty);
    });

    test('nothing the shell holds is carried by a route: no argument, no named route, no route settings', () {
      expect(
          offences(RegExp(
              r'\barguments\b|RouteSettings|\.settings\b|pushNamed|pushReplacementNamed|onGenerateRoute|routeName')),
          isEmpty);
    });

    test('the token store keeps the session, and has no word for the second step', () {
      final String store =
          File('lib/features/platform_admin/domain/repositories/platform_admin_token_store.dart').readAsStringSync();

      expect(store, isNot(contains(RegExp(r'[cC]hallenge|[Mm]fa|[Rr]ecovery|SecondFactor|\bcode\b'))));
      expect(RegExp(r'jsonEncode\(<String, Object\?>\{([^}]*)\}\)').firstMatch(store)!.group(1)!.trim(),
          "'token': session.token,\n            'expires_at': session.expiresAt?.toUtc().toIso8601String(),");
    });

    test('no field of the shell takes part in autofill, and the fields of the second step correct and suggest nothing',
        () {
      expect(offences(RegExp(r'autofillHints\s*:|AutofillGroup|AutofillHints\.|autofillConfiguration')), isEmpty);

      final String screen =
          File('lib/features/platform_admin/screens/platform_admin_second_factor_screen.dart').readAsStringSync();
      expect(screen, contains('autocorrect: false'));
      expect(screen, contains('enableSuggestions: false'));
      expect(screen, contains('enableIMEPersonalizedLearning: false'));
    });

    test(
        'what is typed is emptied when the screen is left, and the one timer of the shell is cancelled with its screen',
        () {
      final String screen =
          File('lib/features/platform_admin/screens/platform_admin_second_factor_screen.dart').readAsStringSync();

      expect(RegExp(r'void dispose\(\) \{[^}]*_timer\?\.cancel\(\);[^}]*_code\.clear\(\);').hasMatch(screen), isTrue);
      expect(
          offences(RegExp(r'\bTimer\b'),
              except: (String path) => path.endsWith('platform_admin_second_factor_screen.dart')),
          isEmpty);
    });
  });

  group('the rest of the app', () {
    test('reaches the shell through two files only: the registration of its objects and the entry on the login screen',
        () {
      final List<String> reaching = <String>[
        for (final FileSystemEntity entity in Directory('lib').listSync(recursive: true))
          if (entity is File &&
              entity.path.endsWith('.dart') &&
              !entity.path.startsWith('lib/features/platform_admin/') &&
              entity.readAsStringSync().contains('features/platform_admin/'))
            entity.path,
      ]..sort();

      expect(reaching, <String>['lib/di_container.dart', 'lib/features/auth/screens/login_screen.dart']);
    });

    test('and the one shared widget the shell asks more of keeps what it did for everyone else', () {
      final String field = File('lib/common/basewidgets/textfeild/custom_text_feild_widget.dart').readAsStringSync();

      expect(field, contains('this.autocorrect = true,'));
      expect(field, contains('this.enableSuggestions = true,'));
      expect(field, contains('this.enableIMEPersonalizedLearning = true,'));
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
