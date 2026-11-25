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

    test('the dashboard builds its title area with the widget that carries the market label, and says nothing of whether it is on', () {
      final String dashboard = File('lib/features/home/screens/home_page_screen.dart').readAsStringSync();

      expect(dashboard, contains('const HomeAppBarWidget(),'));
      expect(dashboard, isNot(contains('SliverAppBar')));
    });

    test('the title areas of the dashboard and of the order list put the market label in front of their action through the labelled action', () {
      final String dashboardBar = File('lib/features/home/widgets/home_app_bar_widget.dart').readAsStringSync();
      final String orderList = File('lib/features/order/screens/order_screen.dart').readAsStringSync();

      expect(RegExp(r'MarketLabeledAction\(\s*enabled: storefrontsEnabled,').hasMatch(dashboardBar), isTrue);
      expect(orderList, contains('MarketLabeledAction(enabled: widget.storefrontsEnabled, action: '));
      for (final String source in <String>[dashboardBar, orderList]) {
        expect(source, isNot(contains('MarketLabel(')));
      }
    });

    test('no screen of the app says whether its market label, its tile or its client is on: all of them follow the build flag', () {
      for (final File file in _dartFilesUnder('lib')) {
        final String source = file.readAsStringSync();

        // A helper that TAKES the flag, with the build flag as its default, may pass its own parameter on -- that is still one answer,
        // the build's. What the rule forbids is a caller stating an answer of its own, so a file naming a literal is caught either way.
        // `NotificationMarket` and `SellerPushTopics` are written this way: a test drives them both ways, and no screen names the flag.
        final bool takesTheFlagItself = source.contains('bool storefrontsEnabled = StorefrontConfig.enabled');

        if (takesTheFlagItself) {
          expect(RegExp(r'storefrontsEnabled:\s*(true|false)\b').hasMatch(source), isFalse, reason: file.path);
        } else {
          expect(source, isNot(contains('storefrontsEnabled:')), reason: file.path);
        }

        expect(RegExp(r'MarketLabeledAction\(\s*enabled:\s*(true|false)\b').hasMatch(source), isFalse, reason: file.path);
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
    });
  });
}
