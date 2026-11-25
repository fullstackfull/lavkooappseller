import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/helper/digital_file_address.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

/// Fetching a digital file the platform keeps off the public disk (K-17).
///
/// While `DIGITAL_FILES_PRIVATE` is off the platform answers a public storage address, which is what this app has always been
/// given and what it has always fetched with no credential. While it is on the platform answers the authenticated route of the
/// area that asked, and this app asks `api/v3/seller`, so it is answered one of three routes of its own — which need the same
/// credential as every other request of this app, and were being fetched with none.
///
/// The second half of this is where the credential must NOT go. A download address is a string from an answer, and the app
/// fetches it with whatever it is given, so the rule below is what keeps a bearer token out of a bucket's access log.
void main() {
  const String token = 'seller-session-token';
  const String own = AppConstants.baseUrl;
  const String ordersFile = '$own/api/v3/seller/orders/digital-file/12/invoice.pdf';

  Map<String, String> headersFor(String? address, {String baseUrl = own, String? credential = token}) =>
      DigitalFileAddress.headersFor(address, baseUrl: baseUrl, token: credential);

  group('whether there is an address at all', () {
    test('an answer that carries none is no address, and the word null least of all', () {
      expect(DigitalFileAddress.of(null), isNull);
      expect(DigitalFileAddress.of(''), isNull);
      expect(DigitalFileAddress.of('   '), isNull);
      expect(DigitalFileAddress.of('null'), isNull, reason: 'what interpolating a null path used to produce');
    });

    test('an address is itself, without the spaces around it', () {
      expect(DigitalFileAddress.of(ordersFile), ordersFile);
      expect(DigitalFileAddress.of('  $ordersFile  '), ordersFile);
    });
  });

  group('where the credential goes', () {
    test('to this app\'s own authenticated digital-file routes', () {
      for (final String route in DigitalFileAddress.authenticatedRoutes) {
        expect(headersFor('$own${route}12/file.pdf'), <String, String>{'Authorization': 'Bearer $token'},
            reason: route);
      }
    });

    test('and the three routes are the seller area\'s own, each a prefix of a file address', () {
      expect(DigitalFileAddress.authenticatedRoutes, hasLength(3));
      for (final String route in DigitalFileAddress.authenticatedRoutes) {
        expect(route, startsWith('/api/v3/seller/'), reason: 'the area this app asks as');
        expect(route, endsWith('/'), reason: 'so that a prefix cannot match a longer route name: $route');
      }
    });
  });

  group('where the credential does NOT go', () {
    test('not to a public storage address, even on the app\'s own host', () {
      expect(headersFor('$own/storage/app/public/product/digital-product/2026-11-25-abc.pdf'), isEmpty);
      expect(headersFor('$own/api/v3/seller/orders/list'), isEmpty, reason: 'and not to another route of the app');
    });

    test('not to another host, whatever path it carries', () {
      expect(headersFor('https://files.example.com/api/v3/seller/orders/digital-file/12/invoice.pdf'), isEmpty);
      expect(headersFor('https://lavkoo.com.example.com/api/v3/seller/orders/digital-file/12/x.pdf'), isEmpty);
    });

    test('not over a scheme the app was not built for', () {
      expect(headersFor('http://lavkoo.com/api/v3/seller/orders/digital-file/12/invoice.pdf'), isEmpty);
    });

    test('not to an address that only mentions the route somewhere inside it', () {
      expect(headersFor('$own/redirect?to=/api/v3/seller/orders/digital-file/12/x.pdf'), isEmpty);
      expect(headersFor('$own/x/api/v3/seller/orders/digital-file/12/x.pdf'), isEmpty);
    });

    test('not to an address with no host at all, which is fetched as it was or not at all', () {
      expect(headersFor('/api/v3/seller/orders/digital-file/12/invoice.pdf'), isEmpty);
      expect(headersFor('api/v3/seller/orders/digital-file/12/invoice.pdf'), isEmpty);
    });

    test('and nowhere at all when there is no session, or nothing to fetch', () {
      expect(headersFor(ordersFile, credential: null), isEmpty);
      expect(headersFor(ordersFile, credential: ''), isEmpty);
      expect(headersFor(null), isEmpty);
      expect(headersFor('null'), isEmpty);
      expect(headersFor(''), isEmpty);
    });

    test('and nowhere when the app cannot tell what its own host is', () {
      expect(headersFor(ordersFile, baseUrl: ''), isEmpty);
      expect(headersFor(ordersFile, baseUrl: 'not a url'), isEmpty);
    });
  });

  group('by reading the source', () {
    test('the fetch of a file asks the rule for its headers, and sets them on the request', () {
      final String repository =
          File('lib/features/order_details/domain/repositories/order_details_repository.dart').readAsStringSync();

      expect(repository, contains('DigitalFileAddress.headersFor('));
      expect(repository, contains('headers.forEach((String name, String value) => request.headers.set(name, value));'));
      expect(repository, contains('token: dioClient?.token,'));
    });

    test('the downloader is given the same headers, so Android and iOS fetch the file the same way', () {
      final String controller =
          File('lib/features/order_details/controllers/order_details_controller.dart').readAsStringSync();

      expect(controller, contains('final Map<String, String> downloadHeaders = orderDetailsServiceInterface.downloadHeaders(url);'));
      expect(controller, contains('headers: downloadHeaders,'));
    });

    test('a download with no address asks for nothing instead of fetching the word null', () {
      final String controller =
          File('lib/features/order_details/controllers/order_details_controller.dart').readAsStringSync();
      final String screen =
          File('lib/features/order_details/widgets/order_product_list_item_widget.dart').readAsStringSync();

      expect(controller, contains('if (DigitalFileAddress.of(url) == null) {'));
      expect(screen, isNot(contains(r"'${widget.orderDetailsModel?.digitalFileAfterSellFullUrl?.path}'")));
      expect(screen, contains('String url = file?.path ?? \'\';'));
    });

    test('no screen, controller or repository of the order writes a credential header of its own', () {
      final List<String> naming = <String>[
        for (final FileSystemEntity entity in Directory('lib/features/order_details').listSync(recursive: true))
          if (entity is File &&
              entity.path.endsWith('.dart') &&
              entity.readAsStringSync().contains(RegExp(r'Authorization|Bearer ')))
            entity.path,
      ]..sort();

      expect(naming, isEmpty,
          reason: 'what a download carries is the rule\'s to decide, in one place, for both platforms');
    });
  });
}
