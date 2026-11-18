import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<File> _dartFilesUnder(String directory) => Directory(directory)
    .listSync(recursive: true)
    .whereType<File>()
    .where((File file) => file.path.endsWith('.dart'))
    .toList();

int _occurrences(String source, String text) => text.allMatches(source).length;

/// What cannot be run from here, read from the source instead: these are rules about where the market is wired in, and each says in
/// its name that it reads the source and does not run it.
void main() {
  group('by reading the source', () {
    test('every upload built with package:http takes its headers from the client', () {
      final Map<String, int> sitesWithoutHelper = <String, int>{};
      int sites = 0;
      for (final File file in _dartFilesUnder('lib')) {
        final String source = file.readAsStringSync();
        final int uploads = _occurrences(source, 'http.MultipartRequest(');
        final int helped = _occurrences(source, '.multipartHeaders(');
        sites += uploads;
        if (uploads > helped) {
          sitesWithoutHelper[file.path] = uploads - helped;
        }
      }

      expect(sites, greaterThan(0));
      expect(sitesWithoutHelper, isEmpty);
    });

    test('the dashboard and the order list put the market label in their title area through the labelled action', () {
      for (final String path in <String>[
        'lib/features/home/screens/home_page_screen.dart',
        'lib/features/order/screens/order_screen.dart',
      ]) {
        final String source = File(path).readAsStringSync();

        expect(source, contains('MarketLabeledAction(action: '), reason: path);
        expect(source, isNot(contains('MarketLabel(')), reason: path);
      }
    });

    test('the container registers the market through the storefront registration, which registers nothing while storefronts are off', () {
      final String container = File('lib/di_container.dart').readAsStringSync();

      expect(container, contains('registerStorefrontDependencies(sl);'));
      expect(container, isNot(contains('SellerMarketController')));
    });

    test('the app entry makes no provider of the market: its widgets read it from the container', () {
      final String entry = File('lib/main.dart').readAsStringSync();

      expect(entry, isNot(contains('SellerMarketController')));
      expect(entry, isNot(contains('storefront')));
    });
  });
}
