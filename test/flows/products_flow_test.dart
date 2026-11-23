import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/features/product/controllers/product_controller.dart';
import 'package:syriacosmeticsmanger/features/product/domain/models/filter_model.dart';
import 'package:syriacosmeticsmanger/features/product/domain/repositories/product_repository.dart';
import 'package:syriacosmeticsmanger/features/product/domain/services/product_service.dart';
import 'package:syriacosmeticsmanger/features/product_details/controllers/product_details_controller.dart';
import 'package:syriacosmeticsmanger/features/product_details/domain/repositories/product_details_repository.dart';
import 'package:syriacosmeticsmanger/features/product_details/domain/services/product_details_service.dart';

import 'support/fixtures.dart';
import 'support/flow_harness.dart';
import 'support/scripted_adapter.dart';

const String _listPath = '/api/v3/seller/products/3/all-products';
const String _deletePath = '/api/v3/seller/products/delete/7';
const String _detailsPath = '/api/v3/seller/products/details/7';
const String _statusPath = '/api/v3/seller/products/status-update';

const String _enNoInternet = 'No internet connection';
const String _enTimeout = 'Connection timed out. Please try again';
const String _enServerError = 'Server error. Please try again later';
const String _enDeleted = 'Product deleted successfully';
const String _enStatusUpdated = 'Status updated successfully';

/// The product list, the delete and the status switch, as the seller app runs them: the real controllers, services and
/// repositories over the app's own Dio client, with a scripted server instead of the network.
class _ProductsFlow {
  _ProductsFlow._(this.adapter, this.products, this.details);

  final ScriptedAdapter adapter;
  final ProductController products;
  final ProductDetailsController details;

  static Future<_ProductsFlow> pump(WidgetTester tester, ScriptedAdapter adapter, {String language = 'en'}) async {
    final DioClient client = await FlowHarness.client(adapter, language: language);
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final ProductController products = ProductController(
      productServiceInterface:
          ProductService(productRepoInterface: ProductRepository(sharedPreferences: preferences, dioClient: client)),
    );
    final ProductDetailsController details = ProductDetailsController(
      productDetailsServiceInterface:
          ProductDetailsService(productDetailsRepositoryInterface: ProductDetailsRepository(dioClient: client)),
    );

    await FlowHarness.pump(tester, providers: [
      ChangeNotifierProvider<ProductController>.value(value: products),
      ChangeNotifierProvider<ProductDetailsController>.value(value: details),
    ]);

    addTearDown(products.dispose);
    addTearDown(details.dispose);

    return _ProductsFlow._(adapter, products, details);
  }

  Future<void> loadPage(
    WidgetTester tester, {
    int offset = 1,
    String search = '',
    String language = 'en',
    FilterModel? filter,
  }) =>
      FlowHarness.call(
        tester,
        () => products.getSellerProductList('3', offset, language, search, filterSearchModel: filter),
      );

  Future<void> delete(WidgetTester tester) => FlowHarness.call(tester, () => products.deleteProduct(Get.context!, 7));

  Future<void> loadDetails(WidgetTester tester) => FlowHarness.call(tester, () => details.getProductDetails(7));

  Future<void> switchStatus(WidgetTester tester, {required int status}) =>
      FlowHarness.call(tester, () => details.productStatusOnOff(Get.context!, 7, status));
}

ScriptedAnswer _pageOf(List<Map<String, Object?>> products, {int? totalSize, int offset = 1}) =>
    ScriptedAnswer.json(productPageJson(products, totalSize: totalSize, offset: offset));

void main() {
  group('the product list', () {
    group('the request', () {
      testWidgets('is a GET of the seller\'s products, twenty to a page, signed in, with no body',
          (WidgetTester tester) async {
        final _ProductsFlow flow =
            await _ProductsFlow.pump(tester, ScriptedAdapter.always(_pageOf(<Map<String, Object?>>[productJson()])));

        await flow.loadPage(tester);

        expect(flow.adapter.only.method, 'GET');
        expect(flow.adapter.only.path, _listPath);
        expect(flow.adapter.only.query, <String, String>{'limit': '20', 'offset': '1', 'search': ''});
        expect(flow.adapter.only.body, isNull);
        FlowHarness.expectSignedIn(flow.adapter.only);
      });

      testWidgets('carries the words the seller searched for, and the page they are on', (WidgetTester tester) async {
        final _ProductsFlow flow =
            await _ProductsFlow.pump(tester, ScriptedAdapter.always(_pageOf(<Map<String, Object?>>[])));

        await flow.loadPage(tester, search: 'serum', offset: 1);

        expect(flow.adapter.only.query['search'], 'serum');
        expect(flow.adapter.only.query['offset'], '1');
      });

      testWidgets('asks in the language the screen is in, which is a header of this request alone',
          (WidgetTester tester) async {
        final _ProductsFlow flow =
            await _ProductsFlow.pump(tester, ScriptedAdapter.always(_pageOf(<Map<String, Object?>>[])));

        await flow.loadPage(tester, language: 'ar');

        expect(flow.adapter.only.headers['lang'], 'ar');
        expect(flow.adapter.only.headers['authorization'], 'Bearer ${FlowHarness.sessionToken}');
      });

      testWidgets('carries the seller\'s filter in the keys the API reads', (WidgetTester tester) async {
        final _ProductsFlow flow =
            await _ProductsFlow.pump(tester, ScriptedAdapter.always(_pageOf(<Map<String, Object?>>[])));

        await flow.loadPage(
          tester,
          filter: FilterModel(
            productType: <String>['physical'],
            minPrice: 10,
            maxPrice: 500,
            brandIds: <int>[1, 2],
            categoryIds: <int>[3],
            filterSubCategoryIds: <int>[4],
            status: <String>['active'],
            isApproved: 'denied',
            sorting: 'latest',
            startDate: DateTime(2026, 11, 1, 9, 30),
            endDate: DateTime(2026, 11, 15, 18, 5),
          ),
        );

        expect(flow.adapter.only.query, <String, String>{
          'limit': '20',
          'offset': '1',
          'search': '',
          'product_types': jsonEncode(<String>['physical']),
          'min_price': '10.0',
          'max_price': '500.0',
          'start_date': '11/01/2026 09:30:00 AM',
          'end_date': '11/15/2026 06:05:00 PM',
          'brand_ids': jsonEncode(<int>[1, 2]),
          'category_ids': jsonEncode(<int>[3]),
          'filter_sub_category_ids': jsonEncode(<int>[4]),
          'product_status': jsonEncode(<int>[1]),
          'request_status': '2',
          'filter_sort_by': 'latest',
        });
      });

      // The screen says active and inactive; the API reads 1 and 0, and asking for both is asking for neither alone.
      const Map<String, List<String>> statusesOfChoice = <String, List<String>>{
        'only the active': <String>['active'],
        'only the inactive': <String>['inactive'],
        'both': <String>['active', 'inactive'],
      };
      const Map<String, String> statusSent = <String, String>{
        'only the active': '[1]',
        'only the inactive': '[0]',
        'both': '[0,1]',
      };

      for (final MapEntry<String, List<String>> choice in statusesOfChoice.entries) {
        testWidgets('for ${choice.key} asks for the status ${statusSent[choice.key]}', (WidgetTester tester) async {
          final _ProductsFlow flow =
              await _ProductsFlow.pump(tester, ScriptedAdapter.always(_pageOf(<Map<String, Object?>>[])));

          await flow.loadPage(tester, filter: FilterModel(status: choice.value));

          expect(flow.adapter.only.query['product_status'], statusSent[choice.key]);
        });
      }
    });

    group('a success answer', () {
      testWidgets('is the page the screen reads: its products, its size, and what each product says',
          (WidgetTester tester) async {
        final _ProductsFlow flow = await _ProductsFlow.pump(
          tester,
          ScriptedAdapter.always(_pageOf(
            <Map<String, Object?>>[productJson(), productJson(id: 8, name: 'Argan Oil', currentStock: 0, status: 0)],
            totalSize: 31,
          )),
        );

        expect(flow.products.sellerProductModel, isNull,
            reason: 'nothing is read before the answer, so the screen shows its placeholder');

        await flow.loadPage(tester);

        expect(flow.products.sellerProductModel!.totalSize, 31);
        expect(flow.products.sellerProductModel!.products!.map((product) => product.name),
            <String?>['Rose Serum', 'Argan Oil']);
        expect(flow.products.sellerProductModel!.products!.last.currentStock, 0);
        expect(flow.products.sellerProductModel!.products!.last.status, 0);
        expect(flow.products.sellerProductModel!.products!.first.unitPrice, 25.5);
        expect(flow.products.isLoading, isFalse);
        expect(FlowHarness.shown(tester), isEmpty);
      });

      testWidgets('adds the next page to the first, and a first page starts the list again',
          (WidgetTester tester) async {
        final _ProductsFlow flow = await _ProductsFlow.pump(
          tester,
          ScriptedAdapter.inOrder(<ScriptedAnswer>[
            _pageOf(<Map<String, Object?>>[productJson(id: 1)], totalSize: 3),
            _pageOf(<Map<String, Object?>>[productJson(id: 2)], totalSize: 3, offset: 2),
            _pageOf(<Map<String, Object?>>[productJson(id: 9)], totalSize: 1),
          ]),
        );

        await flow.loadPage(tester);
        await flow.loadPage(tester, offset: 2);

        expect(flow.adapter.requests.map((request) => request.query['offset']), <String?>['1', '2']);
        expect(flow.products.sellerProductModel!.products!.map((product) => product.id), <int?>[1, 2]);
        expect(flow.products.sellerProductModel!.offset, 2);

        await flow.loadPage(tester);

        expect(flow.products.sellerProductModel!.products!.map((product) => product.id), <int?>[9]);
      });

      testWidgets('may be an empty page, which is an answer and not a failure', (WidgetTester tester) async {
        final _ProductsFlow flow =
            await _ProductsFlow.pump(tester, ScriptedAdapter.always(_pageOf(<Map<String, Object?>>[])));

        await flow.loadPage(tester);

        expect(flow.products.sellerProductModel, isNotNull);
        expect(flow.products.sellerProductModel!.products, isEmpty);
        expect(FlowHarness.shown(tester), isEmpty);
      });
    });

    group('a refusal', () {
      testWidgets('is shown in the server\'s words and leaves the list without a page', (WidgetTester tester) async {
        final _ProductsFlow flow = await _ProductsFlow.pump(tester, ScriptedAdapter.always(permissionRefusal()));

        await flow.loadPage(tester);

        expect(FlowHarness.shown(tester), <String>[permissionRefusalText]);
        expect(flow.products.sellerProductModel, isNull);
        expect(flow.products.isLoading, isFalse);
      });

      testWidgets('keeps the pages already on screen when a later page is refused', (WidgetTester tester) async {
        final _ProductsFlow flow = await _ProductsFlow.pump(
          tester,
          ScriptedAdapter.inOrder(<ScriptedAnswer>[
            _pageOf(<Map<String, Object?>>[productJson()], totalSize: 40),
            permissionRefusal(),
          ]),
        );

        await flow.loadPage(tester);
        await flow.loadPage(tester, offset: 2);

        expect(FlowHarness.shown(tester), <String>[permissionRefusalText]);
        expect(flow.products.sellerProductModel!.products!.map((product) => product.id), <int?>[7]);
      });
    });

    group('a transport failure', () {
      for (final MapEntry<String, (ScriptedAnswer, String)> failure in <String, (ScriptedAnswer, String)>{
        'no signal': (ScriptedAnswer.offline(), _enNoInternet),
        'a connection that never completes': (ScriptedAnswer.timeout(), _enTimeout),
        'a server that crashed': (crashedServer, _enServerError),
      }.entries) {
        testWidgets('(${failure.key}) is shown to the seller, throws nothing, and can be retried',
            (WidgetTester tester) async {
          final _ProductsFlow flow = await _ProductsFlow.pump(
            tester,
            ScriptedAdapter.inOrder(<ScriptedAnswer>[
              failure.value.$1,
              _pageOf(<Map<String, Object?>>[productJson()])
            ]),
          );

          await flow.loadPage(tester);

          expect(FlowHarness.shown(tester), <String>[failure.value.$2]);
          expect(flow.products.sellerProductModel, isNull);
          expect(flow.products.isLoading, isFalse, reason: 'the screen is not left waiting');

          await FlowHarness.dismissToast(tester);
          await flow.loadPage(tester);

          expect(flow.adapter.requests, hasLength(2));
          expect(flow.adapter.requests.last.query, flow.adapter.requests.first.query,
              reason: 'the retry asks for the same page');
          expect(flow.products.sellerProductModel!.products!.single.id, 7);
        });
      }
    });
  });

  group('deleting a product', () {
    testWidgets('is a POST to the product\'s own address, with the method the API reads in the body',
        (WidgetTester tester) async {
      final _ProductsFlow flow = await _ProductsFlow.pump(
        tester,
        ScriptedAdapter.always(ScriptedAnswer.json(<String, Object?>{'message': 'successfully product deleted!'})),
      );

      await flow.delete(tester);

      expect(flow.adapter.only.method, 'POST');
      expect(flow.adapter.only.path, _deletePath);
      expect(flow.adapter.only.rawQuery, isEmpty);
      expect(flow.adapter.only.fields, <String, Object?>{'_method': 'delete'});
      FlowHarness.expectSignedIn(flow.adapter.only);
    });

    testWidgets('that was accepted is told to the seller and closes the screen it was started from',
        (WidgetTester tester) async {
      final _ProductsFlow flow = await _ProductsFlow.pump(
        tester,
        ScriptedAdapter.always(ScriptedAnswer.json(<String, Object?>{'message': 'successfully product deleted!'})),
      );

      await flow.delete(tester);

      expect(FlowHarness.shown(tester), <String>[_enDeleted]);
      expect(FlowHarness.screenIsOpen(tester), isFalse);
    });

    testWidgets('that the server refuses is shown in its words and leaves the screen open',
        (WidgetTester tester) async {
      final _ProductsFlow flow = await _ProductsFlow.pump(tester, ScriptedAdapter.always(permissionRefusal()));

      await flow.delete(tester);

      expect(FlowHarness.shown(tester), <String>[permissionRefusalText]);
      expect(FlowHarness.screenIsOpen(tester), isTrue);
    });

    testWidgets('survives a transport failure, leaves the screen open, and sends the same delete again on retry',
        (WidgetTester tester) async {
      final _ProductsFlow flow = await _ProductsFlow.pump(
        tester,
        ScriptedAdapter.inOrder(<ScriptedAnswer>[
          ScriptedAnswer.offline(),
          ScriptedAnswer.json(<String, Object?>{'message': 'successfully product deleted!'}),
        ]),
      );

      await flow.delete(tester);

      expect(FlowHarness.shown(tester), <String>[_enNoInternet]);
      expect(FlowHarness.screenIsOpen(tester), isTrue);

      await FlowHarness.dismissToast(tester);
      await flow.delete(tester);

      expect(flow.adapter.requests.map((request) => request.path), <String>[_deletePath, _deletePath]);
      expect(FlowHarness.shown(tester), <String>[_enDeleted]);
      expect(FlowHarness.screenIsOpen(tester), isFalse);
    });
  });

  group('switching a product on or off', () {
    ScriptedAdapter serverThatRemembersTheStatus() {
      int status = 1;

      return ScriptedAdapter.routes(<String, ScriptedServer>{
        'GET $_detailsPath': (_) => ScriptedAnswer.json(productJson(status: status)),
        'POST $_statusPath': (RecordedRequest request) {
          status = request.fields['status']! as int;
          return ScriptedAnswer.json(<String, Object?>{'success': 'Status update successfully'});
        },
      });
    }

    testWidgets('reads the product by its id with a GET', (WidgetTester tester) async {
      final _ProductsFlow flow = await _ProductsFlow.pump(tester, serverThatRemembersTheStatus());

      await flow.loadDetails(tester);

      expect(flow.adapter.only.method, 'GET');
      expect(flow.adapter.only.path, _detailsPath);
      expect(flow.adapter.only.rawQuery, isEmpty);
      FlowHarness.expectSignedIn(flow.adapter.only);
      expect(flow.details.productDetails!.name, 'Rose Serum');
      expect(flow.details.productDetails!.status, 1);
    });

    testWidgets('is a POST of the product and the status it should have, with the method the API reads',
        (WidgetTester tester) async {
      final _ProductsFlow flow = await _ProductsFlow.pump(tester, serverThatRemembersTheStatus());
      await flow.loadDetails(tester);

      await flow.switchStatus(tester, status: 0);

      final RecordedRequest request = flow.adapter.requests[1];
      expect(request.method, 'POST');
      expect(request.path, _statusPath);
      expect(request.rawQuery, isEmpty);
      expect(request.fields, <String, Object?>{'id': 7, 'status': 0, '_method': 'put'});
      FlowHarness.expectSignedIn(request);
    });

    testWidgets('that was accepted is told to the seller and shows on the product, which is read again',
        (WidgetTester tester) async {
      final _ProductsFlow flow = await _ProductsFlow.pump(tester, serverThatRemembersTheStatus());
      await flow.loadDetails(tester);

      await flow.switchStatus(tester, status: 0);

      expect(FlowHarness.shown(tester), <String>[_enStatusUpdated]);
      expect(
        flow.adapter.requests.map((request) => '${request.method} ${request.path}'),
        <String>['GET $_detailsPath', 'POST $_statusPath', 'GET $_detailsPath'],
        reason: 'the screen must show what the server now says',
      );
      expect(flow.details.productDetails!.status, 0);
    });

    testWidgets('that the server refuses is shown in its words and leaves the product as it was',
        (WidgetTester tester) async {
      final _ProductsFlow flow = await _ProductsFlow.pump(
        tester,
        ScriptedAdapter.inOrder(<ScriptedAnswer>[
          ScriptedAnswer.json(productJson()),
          messageRefusal('Invalid product.'),
        ]),
      );
      await flow.loadDetails(tester);

      await flow.switchStatus(tester, status: 0);

      expect(FlowHarness.shown(tester), <String>['Invalid product.']);
      expect(flow.details.productDetails!.status, 1);
      expect(flow.adapter.requests, hasLength(2), reason: 'nothing is read again after a refusal');
    });

    testWidgets('survives a transport failure and leaves the product as it was', (WidgetTester tester) async {
      final _ProductsFlow flow = await _ProductsFlow.pump(
        tester,
        ScriptedAdapter.inOrder(<ScriptedAnswer>[ScriptedAnswer.json(productJson()), ScriptedAnswer.timeout()]),
      );
      await flow.loadDetails(tester);

      await flow.switchStatus(tester, status: 0);

      expect(FlowHarness.shown(tester), <String>[_enTimeout]);
      expect(flow.details.productDetails!.status, 1);
    });

    testWidgets('that cannot be reached for the product details is shown in the server\'s words',
        (WidgetTester tester) async {
      final _ProductsFlow flow = await _ProductsFlow.pump(
          tester, ScriptedAdapter.always(errorsRefusal('product', 'Product not found.', status: 404)));

      await flow.loadDetails(tester);

      expect(FlowHarness.shown(tester), <String>['Product not found.']);
      expect(flow.details.productDetails, isNull);
      expect(flow.details.isLoading, isFalse);
    });
  });
}
