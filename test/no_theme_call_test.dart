import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The seller app draws no storefront theme. The backend's theme engine sends a section to a channel only when a renderer stands behind it, and the seller app (`vendor_app`)
/// has none: its channel is sent no section. This source test keeps it that way from the app's side: no file under `lib` may name an endpoint that serves a theme page or a
/// theme-backed product list, so a call to one cannot be added without this test failing first.
///
/// The endpoints are `/api/v1/theme/sections`, `/api/v1/theme/home`, `/api/v1/theme/version` and `/api/v1/products/theme-collection`.
final RegExp _themeEndpoint = RegExp(r'''(?:['"/])theme/(?:sections|home|version)\b|theme-collection''');

/// The lines of [source] that name a theme endpoint, as `line: text`. A line that imports or exports a Dart file is not a call, whatever the file is called.
List<String> themeEndpointLinesOf(String source) {
  final List<String> lines = source.split('\n');
  final List<String> found = <String>[];

  for (int index = 0; index < lines.length; index++) {
    final String line = lines[index].trim();
    final bool isDirective = line.startsWith('import ') || line.startsWith('export ') || line.startsWith('part ');

    if (!isDirective && _themeEndpoint.hasMatch(line)) {
      found.add('${index + 1}: $line');
    }
  }

  return found;
}

void main() {
  group('the seller app makes no theme call', () {
    test('no file under lib names a theme endpoint', () {
      final List<String> offenders = <String>[];

      for (final FileSystemEntity entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }

        for (final String line in themeEndpointLinesOf(entity.readAsStringSync())) {
          offenders.add('${entity.path}:$line');
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'the seller app has no renderer for a theme, so the backend sends its channel no section; a call to a theme endpoint '
            'would be answered with an empty page. Offending lines:\n${offenders.join('\n')}',
      );
    });

    test('the scan sees an endpoint when one is written (it guards the guard)', () {
      const List<String> calls = <String>[
        "final url = '/api/v1/theme/home';",
        'static const String themeVersion = "/api/v1/theme/version";',
        "client.get('theme/sections?page=home');",
        "uri: '\${AppConstants.baseUrl}/api/v1/products/theme-collection',",
      ];

      for (final String call in calls) {
        expect(themeEndpointLinesOf(call), hasLength(1), reason: call);
      }
    });

    test('the scan leaves the app\'s own colour themes alone', () {
      const List<String> notCalls = <String>[
        "import 'package:syriacosmeticsmanger/theme/controllers/theme_controller.dart';",
        "import 'package:syriacosmeticsmanger/theme/home.dart';",
        "export 'package:syriacosmeticsmanger/theme/version.dart';",
        'final controller = Provider.of<ThemeController>(context);',
        "final active = configModel?.activeTheme == 'theme_aster';",
        "final text = 'the home of the theme';",
      ];

      for (final String line in notCalls) {
        expect(themeEndpointLinesOf(line), isEmpty, reason: line);
      }
    });
  });
}
