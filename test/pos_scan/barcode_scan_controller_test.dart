import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_snackbar_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_toast.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/barcode_scan_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/cart_model.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/services/cart_service_interface.dart';
import 'package:syriacosmeticsmanger/features/pos/widgets/ambiguous_code_sheet_widget.dart';
import 'package:syriacosmeticsmanger/features/product/screens/product_list_screen.dart';

import 'support/harness.dart';
import 'support/scan_fixture.dart';
import 'support/scripted_adapter.dart';

const String _scanUrl = 'https://lavkoo.com/api/v3/seller/pos/products';

const String _enTitle = 'Several products share this code';
const String _enOpenListButton = 'Open product list';
const String _enMarketUnavailable = 'Scanning is not available for this market.';
const String _arMarketUnavailable = 'المسح غير متاح لهذا السوق.';
const String _enProductNotFound = 'Product not found';
const String _arProductNotFound = 'لم يتم العثور على المنتج';

Finder get _sheet => find.byType(AmbiguousCodeSheetWidget);

/// The scan of the seller app's point of sale, end to end up to the network: the real controller, service and repository
/// against a scripted server, on a screen of the real app.
void main() {
  group('a scan that finds one product', () {
    testWidgets('adds it to the cart exactly as before, and asks for the code alone', (WidgetTester tester) async {
      final ScanFixture fixture = await ScanFixture.pump(tester, adapter: ScriptedAdapter.always(oneProduct()));

      await fixture.scan(tester, 'ABC123');

      expect(fixture.adapter.requests.single.uri.toString(), '$_scanUrl?code=ABC123');
      expect(fixture.products.initialised.single.id, 7);
      expect(fixture.cart.added, hasLength(1));
      final CartModel added = fixture.cart.added.single;
      expect(added.price, 25.5);
      expect(added.discountAmount, 2);
      expect(added.quantity, 1);
      expect(added.taxAmount, 5);
      expect(added.variant, isNull);
      expect(added.variation, isNull);
      expect(added.varientKey, isNull);
      expect(added.digitalVariationPrice, isNull);
      expect(added.product?.id, 7);
      expect(added.taxModel, 'exclude');
      expect(fixture.scanner.scanProduct?.id, 7);
      expect(fixture.scanner.isLoading, isFalse);
      expect(_sheet, findsNothing);
    });

    testWidgets('does the same for a single match when the seller works in a market', (WidgetTester tester) async {
      final ScanFixture fixture = await ScanFixture.pump(
        tester,
        adapter: ScriptedAdapter.always(oneProduct()),
        storefrontsEnabled: true,
        stored: <String, Object>{'storefront_country': 'KW'},
      );

      await fixture.scan(tester, 'ABC123');

      expect(fixture.adapter.requests.single.uri.toString(), '$_scanUrl?code=ABC123&country=KW');
      expect(fixture.cart.added.single.product?.id, 7);
      expect(_sheet, findsNothing);
    });
  });

  group('a scan that finds nothing', () {
    testWidgets('tells the seller no product was found, adds nothing, and ends the scan', (WidgetTester tester) async {
      final ScanFixture fixture =
          await ScanFixture.pump(tester, adapter: ScriptedAdapter.always(ScriptedAnswer.json(<Object?>[])));

      await fixture.scan(tester, 'UNKNOWN');

      expect(fixture.adapter.requests.single.uri.toString(), '$_scanUrl?code=UNKNOWN');
      expect(find.text(_enProductNotFound), findsOneWidget);
      expect(fixture.cart.added, isEmpty);
      expect(fixture.products.initialised, isEmpty);
      expect(fixture.scanner.scanProduct, isNull);
      expect(fixture.scanner.isLoading, isFalse, reason: 'the scan is over, so the seller can scan again');
      expect(_sheet, findsNothing);
    });

    testWidgets('says so in Arabic when the app is in Arabic', (WidgetTester tester) async {
      final ScanFixture fixture = await ScanFixture.pump(
        tester,
        adapter: ScriptedAdapter.always(ScriptedAnswer.json(<Object?>[])),
        locale: PosScanHarness.arabic,
      );

      await fixture.scan(tester, 'UNKNOWN');

      expect(find.text(_arProductNotFound), findsOneWidget);
      expect(find.text(_enProductNotFound), findsNothing);
    });

    testWidgets('says so when the seller works in a market, and asks for that market only', (WidgetTester tester) async {
      final ScanFixture fixture = await ScanFixture.pump(
        tester,
        adapter: ScriptedAdapter.always(ScriptedAnswer.json(<Object?>[])),
        storefrontsEnabled: true,
        stored: <String, Object>{'storefront_country': 'KW'},
      );

      await fixture.scan(tester, 'UNKNOWN');

      expect(fixture.adapter.requests.single.uri.toString(), '$_scanUrl?code=UNKNOWN&country=KW');
      expect(find.text(_enProductNotFound), findsOneWidget);
      expect(fixture.cart.added, isEmpty);
    });

    testWidgets('does not say so when a product was found', (WidgetTester tester) async {
      final ScanFixture fixture = await ScanFixture.pump(tester, adapter: ScriptedAdapter.always(oneProduct()));

      await fixture.scan(tester, 'ABC123');

      expect(find.text(_enProductNotFound), findsNothing);
      expect(fixture.cart.added, hasLength(1));
    });
  });

  group('409: several products answer to the code', () {
    ScriptedAdapter serverThatKnowsCountries() => ScriptedAdapter((RecordedRequest request) {
          if (request.uri.queryParameters['country'] == 'KW') {
            return oneProduct(<String, Object?>{...productJson, 'id': 2, 'name': 'Rose Serum 50 ml'});
          }
          return ambiguity(<Map<String, Object?>>[
            candidate(1, 'Rose Serum 30 ml', 'SA'),
            candidate(2, 'Rose Serum 50 ml', 'KW'),
          ]);
        });

    testWidgets('picks nothing: no product is added, and the seller is shown the candidates to choose from',
        (WidgetTester tester) async {
      final ScanFixture fixture = await ScanFixture.pump(tester, adapter: serverThatKnowsCountries());

      await fixture.scan(tester, 'ABC123');

      expect(fixture.adapter.requests, hasLength(1));
      expect(fixture.cart.added, isEmpty);
      expect(fixture.products.initialised, isEmpty);
      expect(fixture.scanner.scanProduct, isNull);
      expect(_sheet, findsOneWidget);
      expect(find.text('Rose Serum 30 ml'), findsOneWidget);
      expect(find.text('Saudi Arabia'), findsOneWidget);
      expect(find.text('Rose Serum 50 ml'), findsOneWidget);
      expect(find.text('Kuwait'), findsOneWidget);
      expect(find.text(_enOpenListButton), findsNothing);
      expect(find.text('Server words for the ambiguity.'), findsNothing,
          reason: 'that text is for the app, not for the seller');
      expect(fixture.scanner.isLoading, isFalse);
    });

    testWidgets(
        'a product chosen in a country is scanned for again with that country, and added when it is the only one',
        (WidgetTester tester) async {
      final ScanFixture fixture = await ScanFixture.pump(tester, adapter: serverThatKnowsCountries());
      await fixture.scan(tester, 'ABC123');

      await tester.tap(find.text('Rose Serum 50 ml'));
      await fixture.letTheScanFinish(tester);

      expect(fixture.adapter.requests.map((RecordedRequest request) => request.uri.toString()), <String>[
        '$_scanUrl?code=ABC123',
        '$_scanUrl?code=ABC123&country=KW',
      ]);
      expect(_sheet, findsNothing);
      expect(fixture.cart.added, hasLength(1));
      expect(fixture.cart.added.single.product?.name, 'Rose Serum 50 ml');
      expect(fixture.scanner.scanProduct?.id, 2);
    });

    testWidgets('scans again with the country the seller chose, not the market the seller works in',
        (WidgetTester tester) async {
      final ScanFixture fixture = await ScanFixture.pump(
        tester,
        adapter: ScriptedAdapter((RecordedRequest request) => request.uri.queryParameters['country'] == 'SA'
            ? oneProduct()
            : ambiguity(<Map<String, Object?>>[
                candidate(1, 'Rose Serum 30 ml', 'SA'),
                candidate(2, 'Rose Serum 50 ml', 'KW')
              ])),
        storefrontsEnabled: true,
        stored: <String, Object>{'storefront_country': 'AE'},
      );
      await fixture.scan(tester, 'ABC123');

      await tester.tap(find.text('Rose Serum 30 ml'));
      await fixture.letTheScanFinish(tester);

      expect(fixture.adapter.requests.first.uri.toString(), '$_scanUrl?code=ABC123&country=AE');
      expect(fixture.adapter.requests.last.uri.toString(), '$_scanUrl?code=ABC123&country=SA');
      expect(fixture.cart.added.single.product?.id, 7);
    });

    testWidgets(
        'products that share a country are explained, not chosen between, and the sheet leads to the product list',
        (WidgetTester tester) async {
      final ScanFixture fixture = await ScanFixture.pump(
        tester,
        adapter: ScriptedAdapter.always(ambiguity(<Map<String, Object?>>[
          candidate(1, 'Rose Serum 30 ml', 'SA'),
          candidate(3, 'Rose Serum 30 ml (new box)', 'SA'),
        ])),
      );

      await fixture.scan(tester, 'ABC123');

      expect(find.text(_enTitle), findsOneWidget);
      expect(find.text('Rose Serum 30 ml'), findsOneWidget);
      expect(find.text('Rose Serum 30 ml (new box)'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(fixture.cart.added, isEmpty);

      await tester.tap(find.text(_enOpenListButton));
      await tester.pumpAndSettle();

      expect(find.text(productListStandIn), findsOneWidget);
      expect(_sheet, findsNothing);
      expect(fixture.adapter.requests, hasLength(1), reason: 'opening the list asks the server nothing');
      expect(fixture.cart.added, isEmpty);
    });

    testWidgets('a tap on a product of a shared country does not scan again', (WidgetTester tester) async {
      final ScanFixture fixture = await ScanFixture.pump(
        tester,
        adapter: ScriptedAdapter.always(ambiguity(<Map<String, Object?>>[
          candidate(1, 'Rose Serum 30 ml', 'SA'),
          candidate(3, 'Rose Serum 30 ml (new box)', 'SA'),
        ])),
      );
      await fixture.scan(tester, 'ABC123');

      await tester.tap(find.text('Rose Serum 30 ml (new box)'));
      await fixture.letTheScanFinish(tester);

      expect(fixture.adapter.requests, hasLength(1));
      expect(_sheet, findsOneWidget);
    });

    testWidgets(
        'the seller can choose a country once: if the server still cannot settle it, the sheet stops offering a choice',
        (WidgetTester tester) async {
      final ScanFixture fixture = await ScanFixture.pump(
        tester,
        adapter: ScriptedAdapter.always(ambiguity(<Map<String, Object?>>[
          candidate(1, 'Rose Serum 30 ml', 'SA'),
          candidate(2, 'Rose Serum 50 ml', 'KW'),
        ])),
      );
      await fixture.scan(tester, 'ABC123');
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));

      await tester.tap(find.text('Rose Serum 50 ml'));
      await fixture.letTheScanFinish(tester);

      expect(fixture.adapter.requests, hasLength(2));
      expect(fixture.adapter.requests.last.uri.queryParameters['country'], 'KW');
      expect(_sheet, findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.text(_enOpenListButton), findsOneWidget);
      expect(fixture.cart.added, isEmpty);
    });

    testWidgets('while storefronts are on the server narrows to one country, so the seller is led to the product list',
        (WidgetTester tester) async {
      final ScanFixture fixture = await ScanFixture.pump(
        tester,
        adapter: ScriptedAdapter.always(ambiguity(<Map<String, Object?>>[
          candidate(5, 'Rose Serum 30 ml', 'KW'),
          candidate(6, 'Rose Serum 30 ml', 'KW'),
        ])),
        storefrontsEnabled: true,
        stored: <String, Object>{'storefront_country': 'KW'},
      );

      await fixture.scan(tester, 'ABC123');

      expect(fixture.adapter.requests.single.uri.toString(), '$_scanUrl?code=ABC123&country=KW');
      expect(find.text(_enOpenListButton), findsOneWidget);
      expect(find.text('Kuwait'), findsNWidgets(2));
      expect(fixture.cart.added, isEmpty);
    });

    testWidgets('an ambiguity with nobody to list still tells the seller, in Arabic when the app is in Arabic',
        (WidgetTester tester) async {
      final ScanFixture fixture = await ScanFixture.pump(
        tester,
        adapter: ScriptedAdapter.always(ambiguity(<Map<String, Object?>>[])),
        locale: PosScanHarness.arabic,
      );

      await fixture.scan(tester, 'ABC123');

      expect(find.text('هذا الرمز مشترك بين عدة منتجات'), findsOneWidget);
      expect(find.text('فتح قائمة المنتجات'), findsOneWidget);
      expect(fixture.cart.added, isEmpty);
    });

    testWidgets('the sheet holds on the narrowest phone at twice the text size, in Arabic',
        (WidgetTester tester) async {
      final ScanFixture fixture = await ScanFixture.pump(
        tester,
        adapter: serverThatKnowsCountries(),
        locale: PosScanHarness.arabic,
        screen: PosScanHarness.narrowPhone,
        textScale: 2.0,
      );

      await fixture.scan(tester, 'ABC123');

      expect(tester.takeException(), isNull);
      expect(_sheet, findsOneWidget);
    });
  });

  test('the sheet leads to the seller\'s own product list unless it is told another page', () {
    final BarcodeScanController scanner = BarcodeScanController(cartServiceInterface: _NoCartService());
    addTearDown(scanner.dispose);

    final Widget page = scanner.productListPage(_NoContext());

    expect(page, isA<ProductListMenuScreen>());
    expect((page as ProductListMenuScreen).isTab, isFalse);
    expect(page.fromNotification, isFalse);
  });

  group('422: the server does not know the market', () {
    testWidgets('shows the server\'s own message, and does not ask again', (WidgetTester tester) async {
      final ScanFixture fixture = await ScanFixture.pump(tester,
          adapter: ScriptedAdapter.always(countryRefused('Server words for the country.')));

      await fixture.scan(tester, 'ABC123');

      expect(find.text('Server words for the country.'), findsOneWidget);
      expect(tester.widget<CustomToast>(find.byType(CustomToast)).sanckBarType, SnackBarType.error);
      expect(_sheet, findsNothing);
      expect(fixture.cart.added, isEmpty);

      await tester.pump(const Duration(seconds: 5));
      expect(fixture.adapter.requests, hasLength(1), reason: 'nothing a retry would change');
    });

    testWidgets('says it in the app\'s own words when the server wrote none', (WidgetTester tester) async {
      final ScanFixture fixture = await ScanFixture.pump(tester, adapter: ScriptedAdapter.always(countryRefused('')));

      await fixture.scan(tester, 'ABC123');

      expect(find.text(_enMarketUnavailable), findsOneWidget);
      expect(fixture.adapter.requests, hasLength(1));
    });

    testWidgets('says it in Arabic when the app is in Arabic and the server wrote none', (WidgetTester tester) async {
      final ScanFixture fixture = await ScanFixture.pump(
        tester,
        adapter: ScriptedAdapter.always(countryRefused('  ')),
        locale: PosScanHarness.arabic,
      );

      await fixture.scan(tester, 'ABC123');

      expect(find.text(_arMarketUnavailable), findsOneWidget);
    });

    testWidgets('a country that is refused for the market the seller works in ends the scan there',
        (WidgetTester tester) async {
      final ScanFixture fixture = await ScanFixture.pump(
        tester,
        adapter: ScriptedAdapter.always(countryRefused()),
        storefrontsEnabled: true,
        stored: <String, Object>{'storefront_country': 'OM'},
      );

      await fixture.scan(tester, 'ABC123');
      await tester.pump(const Duration(seconds: 5));

      expect(fixture.adapter.requests.single.uri.toString(), '$_scanUrl?code=ABC123&country=OM');
      expect(fixture.cart.added, isEmpty);
      expect(fixture.scanner.isLoading, isFalse);
    });
  });

  group('every other failure is shown as it always was', () {
    testWidgets('a server error shows the server\'s message', (WidgetTester tester) async {
      final ScanFixture fixture = await ScanFixture.pump(
        tester,
        adapter: ScriptedAdapter.always(ScriptedAnswer.json(<String, Object?>{'message': 'Boom.'}, status: 500)),
      );

      await fixture.scan(tester, 'ABC123');

      expect(find.text('Boom.'), findsOneWidget);
      expect(_sheet, findsNothing);
      expect(fixture.cart.added, isEmpty);
    });

    testWidgets('a 409 that is not an ambiguity shows its own message, and no sheet', (WidgetTester tester) async {
      final ScanFixture fixture = await ScanFixture.pump(
        tester,
        adapter: ScriptedAdapter.always(ScriptedAnswer.json(<String, Object?>{
          'errors': <Object?>[
            <String, Object?>{'code': 'conflict', 'message': 'Busy.'}
          ],
        }, status: 409)),
      );

      await fixture.scan(tester, 'ABC123');

      expect(find.text('Busy.'), findsOneWidget);
      expect(_sheet, findsNothing);
    });

    testWidgets('a 422 about something else shows its message, as a validation failure always did',
        (WidgetTester tester) async {
      final ScanFixture fixture = await ScanFixture.pump(
        tester,
        adapter: ScriptedAdapter.always(ScriptedAnswer.json(<String, Object?>{
          'errors': <Object?>[
            <String, Object?>{'code': 'code', 'message': 'The code must be text.'}
          ],
        }, status: 422)),
      );

      await fixture.scan(tester, 'ABC123');

      expect(find.text('The code must be text.'), findsOneWidget);
      expect(find.text(_enMarketUnavailable), findsNothing);
    });

    testWidgets('no signal says there is no internet connection', (WidgetTester tester) async {
      final ScanFixture fixture = await ScanFixture.pump(tester, adapter: ScriptedAdapter.offline());

      await fixture.scan(tester, 'ABC123');

      expect(find.text('No internet connection'), findsOneWidget);
      expect(_sheet, findsNothing);
      expect(fixture.cart.added, isEmpty);
    });
  });
}

class _NoCartService implements CartServiceInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// The default page builder does not read its context, so the test hands it none.
class _NoContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
