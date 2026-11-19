import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/features/bulk_jobs/controllers/bulk_job_controller.dart';
import 'package:syriacosmeticsmanger/features/bulk_jobs/domain/models/bulk_job_models.dart';
import 'package:syriacosmeticsmanger/features/bulk_jobs/domain/repositories/bulk_job_repository.dart';
import 'package:syriacosmeticsmanger/features/bulk_jobs/domain/services/bulk_job_service.dart';
import 'package:syriacosmeticsmanger/features/inventory/controllers/inventory_controller.dart';
import 'package:syriacosmeticsmanger/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:syriacosmeticsmanger/features/inventory/domain/services/inventory_service.dart';
import 'package:syriacosmeticsmanger/features/inventory/widgets/stock_adjust_sheet.dart';
import 'package:syriacosmeticsmanger/features/product/controllers/product_controller.dart';
import 'package:syriacosmeticsmanger/features/product/domain/models/product_model.dart';
import 'package:syriacosmeticsmanger/features/product/domain/repositories/product_repository.dart';
import 'package:syriacosmeticsmanger/features/product/domain/services/product_service.dart';
import 'package:syriacosmeticsmanger/features/restock/controllers/restock_controller.dart';
import 'package:syriacosmeticsmanger/features/restock/domain/models/restock_brand_model.dart';
import 'package:syriacosmeticsmanger/features/restock/domain/repositories/restock_repository.dart';
import 'package:syriacosmeticsmanger/features/restock/domain/services/restock_service.dart';

import 'support/fixtures.dart';
import 'support/flow_harness.dart';
import 'support/scripted_adapter.dart';

const String _stockOutPath = '/api/v3/seller/products/stock-out-list';
const String _limitStatusPath = '/api/v3/seller/products/stock-limit-status';
const String _quantityPath = '/api/v3/seller/products/quantity-update';
const String _restockBrandsPath = '/api/v3/seller/products/restock-request-brands-list';
const String _restockListPath = '/api/v3/seller/products/restock-request-list';
const String _restockUpdatePath = '/api/v3/seller/products/restock-request-stock-update';
const String _overviewPath = '/api/v3/seller/seller-center/inventory/overview';
const String _movementsPath = '/api/v3/seller/seller-center/inventory/movements';
const String _adjustPath = '/api/v3/seller/seller-center/inventory/products/7/adjust';
const String _bulkStockPath = '/api/v3/seller/seller-center/bulk-jobs/stock';
const String _bulkJobPath = '/api/v3/seller/seller-center/bulk-jobs/9';

const String _enNoInternet = 'No internet connection';
const String _enTimeout = 'Connection timed out. Please try again';
const String _enQuantityUpdated = 'Quantity updated successfully';
const String _updateFailedText = 'Update failed.';
const String _belowZeroText = 'This correction would take the stock below zero.';
const String _deltaRequiredText = 'The delta field is required.';

/// The stock screens as the seller app runs them: the stock-out list and its quantity dialog, the restock requests, and
/// the stock ledger with its correction sheet. The real controllers, services and repositories over the app's own Dio
/// client, with a scripted server instead of the network.
class _StockFlow {
  _StockFlow._(this.adapter, this.products, this.restock, this.inventory, this.bulk);

  final ScriptedAdapter adapter;
  final ProductController products;
  final RestockController restock;
  final InventoryController inventory;
  final BulkJobController bulk;

  static Future<_StockFlow> pump(WidgetTester tester, ScriptedAdapter adapter, {Widget? screen}) async {
    final DioClient client = await FlowHarness.client(adapter);
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final ProductController products = ProductController(
      productServiceInterface:
          ProductService(productRepoInterface: ProductRepository(sharedPreferences: preferences, dioClient: client)),
    );
    final RestockController restock = RestockController(
      restockServiceInterface: RestockService(restockRepositoryInterface: RestockRepository(dioClient: client)),
    );
    final InventoryController inventory = InventoryController(
      inventoryServiceInterface: InventoryService(inventoryRepoInterface: InventoryRepository(dioClient: client)),
    );

    final BulkJobController bulk = BulkJobController(
      bulkJobServiceInterface: BulkJobService(
        bulkJobRepoInterface: BulkJobRepository(dioClient: client),
        productRepoInterface: ProductRepository(sharedPreferences: preferences, dioClient: client),
      ),
    );

    FlowHarness.useScreen(tester);
    await FlowHarness.pump(
      tester,
      screen: screen ?? const Scaffold(body: Text(FlowHarness.openScreenText)),
      providers: [
        ChangeNotifierProvider<ProductController>.value(value: products),
        ChangeNotifierProvider<RestockController>.value(value: restock),
        ChangeNotifierProvider<InventoryController>.value(value: inventory),
      ],
    );

    addTearDown(products.dispose);
    addTearDown(restock.dispose);
    addTearDown(inventory.dispose);
    addTearDown(bulk.dispose);

    return _StockFlow._(adapter, products, restock, inventory, bulk);
  }

  /// The quantities the seller typed in the dialog, one box to a variation, and the total they typed beside them.
  Future<void> updateQuantities(WidgetTester tester, {String medium = '4', String large = '6', int total = 10}) {
    final List<Variation> variations = _variations();
    restock.initVariationController(variations);
    restock.variationQuantityController[0].text = medium;
    restock.variationQuantityController[1].text = large;

    return FlowHarness.call(tester, () => restock.updateProductQuantity(Get.context!, 7, total, variations));
  }

  Future<void> updateRestockQuantities(WidgetTester tester, {String medium = '4', String large = '6', int total = 10}) {
    final List<Variation> variations = _variations();
    restock.initVariationController(variations);
    restock.variationQuantityController[0].text = medium;
    restock.variationQuantityController[1].text = large;

    return FlowHarness.call(tester, () => restock.updateRestockProductQuantity(Get.context!, 7, total, variations));
  }
}

List<Variation> _variations() => <Variation>[
      Variation(type: 'M', sku: 'RS-M', price: 25.0, qty: 0),
      Variation(type: 'L', sku: 'RS-L', price: 27.5, qty: 0),
    ];

/// One bulk job, as `seller-center/bulk-jobs` describes it.
Map<String, Object?> _bulkJobJson({
  String status = 'completed',
  bool finished = true,
  int succeeded = 2,
  int failed = 0,
  List<Object?> failures = const <Object?>[],
}) =>
    <String, Object?>{
      'id': 9,
      'type': 'stock_update',
      'status': status,
      'total': 2,
      'processed': finished ? 2 : 0,
      'succeeded': succeeded,
      'failed': failed,
      'progress': finished ? 100 : 0,
      'is_finished': finished,
      'created_at': '2026-11-12T02:23:28.000000Z',
      'finished_at': finished ? '2026-11-12T02:23:30.000000Z' : null,
      'error': null,
      'failures': failures,
    };

ScriptedAnswer _bulkAccepted(Map<String, Object?> job) =>
    ScriptedAnswer.json(<String, Object?>{'message': 'The change was queued', 'job': job}, status: 202);

ScriptedAnswer _stockOut(List<Map<String, Object?>> products, {int? totalSize}) =>
    ScriptedAnswer.json(productPageJson(products, totalSize: totalSize, limit: 10));

void main() {
  group('the stock-out list', () {
    testWidgets('is a GET of ten products a page, in the language of the screen, signed in',
        (WidgetTester tester) async {
      final _StockFlow flow = await _StockFlow.pump(
          tester, ScriptedAdapter.always(_stockOut(<Map<String, Object?>>[productJson(currentStock: 0)])));

      await FlowHarness.call(tester, () => flow.products.getStockOutProductList(1, 'ar'));

      expect(flow.adapter.only.method, 'GET');
      expect(flow.adapter.only.path, _stockOutPath);
      expect(flow.adapter.only.query, <String, String>{'limit': '10', 'offset': '1'});
      expect(flow.adapter.only.body, isNull);
      expect(flow.adapter.only.headers['lang'], 'ar');
      expect(flow.adapter.only.headers['authorization'], 'Bearer ${FlowHarness.sessionToken}');
    });

    testWidgets('is the list the screen reads: the products that ran out, and how many there are',
        (WidgetTester tester) async {
      final _StockFlow flow = await _StockFlow.pump(
        tester,
        ScriptedAdapter.always(_stockOut(<Map<String, Object?>>[
          productJson(currentStock: 0),
          productJson(id: 8, name: 'Argan Oil', currentStock: 2)
        ], totalSize: 14)),
      );

      expect(flow.products.stockOutProductList, isNull,
          reason: 'nothing is read before the answer, so the screen shows its placeholder');

      await FlowHarness.call(tester, () => flow.products.getStockOutProductList(1, 'en'));

      expect(flow.products.stockOutProductList!.map((product) => product.name), <String?>['Rose Serum', 'Argan Oil']);
      expect(flow.products.stockOutProductList!.map((product) => product.currentStock), <int?>[0, 2]);
      expect(flow.products.stockOutProductPageSize, 14);
      expect(flow.products.isLoading, isFalse);
      expect(FlowHarness.shown(tester), isEmpty);
    });

    testWidgets('adds the next page to the first, and does not ask again for a page it has',
        (WidgetTester tester) async {
      final _StockFlow flow = await _StockFlow.pump(
        tester,
        ScriptedAdapter.inOrder(<ScriptedAnswer>[
          _stockOut(<Map<String, Object?>>[productJson(id: 1, currentStock: 0)], totalSize: 12),
          _stockOut(<Map<String, Object?>>[productJson(id: 2, currentStock: 0)], totalSize: 12),
        ]),
      );

      await FlowHarness.call(tester, () => flow.products.getStockOutProductList(1, 'en'));
      flow.products.setOffset(2);
      await FlowHarness.call(tester, () => flow.products.getStockOutProductList(2, 'en'));
      await FlowHarness.call(tester, () => flow.products.getStockOutProductList(2, 'en'));

      expect(flow.adapter.requests.map((request) => request.query['offset']), <String?>['1', '2']);
      expect(flow.products.stockOutProductList!.map((product) => product.id), <int?>[1, 2]);
    });

    testWidgets('that is refused is shown in the server\'s words, throws nothing, and can be asked for again',
        (WidgetTester tester) async {
      final _StockFlow flow = await _StockFlow.pump(
        tester,
        ScriptedAdapter.inOrder(<ScriptedAnswer>[
          permissionRefusal(),
          _stockOut(<Map<String, Object?>>[productJson(currentStock: 0)])
        ]),
      );

      await FlowHarness.call(tester, () => flow.products.getStockOutProductList(1, 'en'));

      expect(FlowHarness.shown(tester), <String>[permissionRefusalText]);
      expect(flow.products.stockOutProductList, isNull);

      await FlowHarness.dismissToast(tester);
      await FlowHarness.call(tester, () => flow.products.getStockOutProductList(1, 'en', reload: true));

      expect(flow.products.stockOutProductList!.single.id, 7);
    });

    testWidgets('that fails in transport is shown, throws nothing, and can be asked for again',
        (WidgetTester tester) async {
      final _StockFlow flow = await _StockFlow.pump(
        tester,
        ScriptedAdapter.inOrder(<ScriptedAnswer>[
          ScriptedAnswer.timeout(),
          _stockOut(<Map<String, Object?>>[productJson(currentStock: 0)])
        ]),
      );

      await FlowHarness.call(tester, () => flow.products.getStockOutProductList(1, 'en'));

      expect(FlowHarness.shown(tester), <String>[_enTimeout]);
      expect(flow.products.stockOutProductList, isNull);

      await FlowHarness.dismissToast(tester);
      await FlowHarness.call(tester, () => flow.products.getStockOutProductList(1, 'en', reload: true));

      expect(flow.adapter.requests, hasLength(2));
      expect(flow.products.stockOutProductList!.single.id, 7);
    });

    testWidgets('has a banner, which is a GET of the status of the shop\'s stock and shows what it says',
        (WidgetTester tester) async {
      final _StockFlow flow = await _StockFlow.pump(
        tester,
        ScriptedAdapter.always(ScriptedAnswer.json(
            <String, Object?>{'status': 'stock_out', 'product_count': 3, 'product': productJson(currentStock: 0)})),
      );

      await FlowHarness.call(tester, () => flow.products.getStockLimitStatus(Get.context!));

      expect(flow.adapter.only.method, 'GET');
      expect(flow.adapter.only.path, _limitStatusPath);
      expect(flow.products.stockLimitStatus!.status, 'stock_out');
      expect(flow.products.stockLimitStatus!.productCount, 3);
      expect(flow.products.stockLimitStatus!.product!.name, 'Rose Serum');
    });
  });

  group('changing the quantity of a product from the stock-out list', () {
    testWidgets(
        'is a POST of the product, its stock and each variation with the quantity typed, with the method the API reads',
        (WidgetTester tester) async {
      final _StockFlow flow = await _StockFlow.pump(
        tester,
        ScriptedAdapter.inOrder(<ScriptedAnswer>[
          ScriptedAnswer.json(<String, Object?>{'message': 'Product updated successfully'}),
          _stockOut(<Map<String, Object?>>[]),
        ]),
      );

      await flow.updateQuantities(tester, medium: '4', large: '6', total: 10);

      final RecordedRequest request = flow.adapter.requests.first;
      expect(request.method, 'POST');
      expect(request.path, _quantityPath);
      expect(request.rawQuery, isEmpty);
      expect(request.fields, <String, Object?>{
        'product_id': 7,
        'current_stock': 10,
        'variation': <Object?>[
          <String, Object?>{'type': 'M', 'price': 25.0, 'sku': 'RS-M', 'qty': 4},
          <String, Object?>{'type': 'L', 'price': 27.5, 'sku': 'RS-L', 'qty': 6},
        ],
        '_method': 'put',
      });
      FlowHarness.expectSignedIn(request);
    });

    testWidgets('that was accepted is told to the seller, closes the dialog, and reads the stock-out list again',
        (WidgetTester tester) async {
      final _StockFlow flow = await _StockFlow.pump(
        tester,
        ScriptedAdapter.routes(<String, ScriptedServer>{
          'POST $_quantityPath': (_) =>
              ScriptedAnswer.json(<String, Object?>{'message': 'Product updated successfully'}),
          'GET $_stockOutPath': (_) => _stockOut(<Map<String, Object?>>[]),
        }),
      );

      await flow.updateQuantities(tester);

      expect(FlowHarness.shown(tester), <String>[_enQuantityUpdated]);
      expect(FlowHarness.screenIsOpen(tester), isFalse, reason: 'the success handler closed the dialog');
      expect(
        flow.adapter.requests.map((request) => '${request.method} ${request.path}'),
        <String>['POST $_quantityPath', 'GET $_stockOutPath'],
        reason: 'the product is no longer out of stock, so the list must be read again',
      );
      expect(flow.adapter.requests.last.query, <String, String>{'limit': '10', 'offset': '1'});
      expect(flow.products.stockOutProductList, isEmpty, reason: 'the list shows what the server now says');
      expect(flow.restock.isLoading, isFalse);
    });

    testWidgets('that the server refuses is shown in its words, leaves the dialog open, and reads nothing again',
        (WidgetTester tester) async {
      final _StockFlow flow = await _StockFlow.pump(tester, ScriptedAdapter.always(messageRefusal(_updateFailedText)));

      await flow.updateQuantities(tester);

      expect(FlowHarness.shown(tester), <String>[_updateFailedText]);
      expect(FlowHarness.screenIsOpen(tester), isTrue, reason: 'the seller keeps the numbers they typed');
      expect(flow.adapter.requests, hasLength(1));
      expect(flow.restock.isLoading, isFalse, reason: 'the button is usable again');
    });

    testWidgets('survives a transport failure, leaves the dialog open, and sends the same quantities again on retry',
        (WidgetTester tester) async {
      final _StockFlow flow = await _StockFlow.pump(
        tester,
        ScriptedAdapter.inOrder(<ScriptedAnswer>[
          ScriptedAnswer.offline(),
          ScriptedAnswer.json(<String, Object?>{'message': 'Product updated successfully'}),
          _stockOut(<Map<String, Object?>>[]),
        ]),
      );

      await flow.updateQuantities(tester);

      expect(FlowHarness.shown(tester), <String>[_enNoInternet]);
      expect(FlowHarness.screenIsOpen(tester), isTrue);
      expect(flow.restock.isLoading, isFalse);

      await FlowHarness.dismissToast(tester);
      await flow.updateQuantities(tester);

      expect(flow.adapter.requests[1].fields, flow.adapter.requests.first.fields,
          reason: 'the retry is the same change');
      expect(FlowHarness.shown(tester), <String>[_enQuantityUpdated]);
      expect(FlowHarness.screenIsOpen(tester), isFalse);
    });
  });

  group('the restock requests', () {
    testWidgets('read the brands with a GET and the requests with a POST of the filter the screen holds',
        (WidgetTester tester) async {
      final _StockFlow flow = await _StockFlow.pump(
        tester,
        ScriptedAdapter.routes(<String, ScriptedServer>{
          'GET $_restockBrandsPath': (_) => ScriptedAnswer.json(<String, Object?>{
                'brands': <Object?>[
                  <String, Object?>{
                    'id': 4,
                    'name': 'Rose Co',
                    'image': 'r.png',
                    'brand_all_products_count': 5,
                    'product_count': 2
                  },
                ],
              }),
          'POST $_restockListPath': (_) =>
              ScriptedAnswer.json(restockPageJson(<Map<String, Object?>>[restockRowJson()])),
        }),
      );

      await FlowHarness.call(tester, flow.restock.getRestockBrandList);
      await FlowHarness.call(tester, () => flow.restock.getRestockProductList(1));

      expect(flow.adapter.requests.first.method, 'GET');
      expect(flow.adapter.requests.first.path, _restockBrandsPath);
      expect(flow.adapter.requests.last.method, 'POST');
      expect(flow.adapter.requests.last.path, _restockListPath);
      expect(flow.adapter.requests.last.fields, <String, Object?>{
        'brand_ids': jsonEncode(<int>[]),
        'category_id': null,
        'search': null,
        'restock_start_date': null,
        'restock_end_date': null,
        'offset': 1,
      });
      FlowHarness.expectSignedIn(flow.adapter.requests.last);
      expect(flow.restock.brands!.single.name, 'Rose Co');
      expect(flow.restock.restockProductModel!.data!.single.productId, 7);
      expect(flow.restock.restockProductModel!.data!.single.restockProductCustomersCount, 3);
    });

    testWidgets('name the brands the seller ticked', (WidgetTester tester) async {
      final _StockFlow flow = await _StockFlow.pump(
        tester,
        ScriptedAdapter.routes(<String, ScriptedServer>{
          'GET $_restockBrandsPath': (_) => ScriptedAnswer.json(<String, Object?>{
                'brands': <Object?>[
                  <String, Object?>{'id': 4, 'name': 'Rose Co', 'brand_all_products_count': 5, 'product_count': 2},
                  <String, Object?>{'id': 9, 'name': 'Argan Co', 'brand_all_products_count': 1, 'product_count': 1},
                ],
              }),
          'POST $_restockListPath': (_) => ScriptedAnswer.json(restockPageJson(<Map<String, Object?>>[])),
        }),
      );
      await FlowHarness.call(tester, flow.restock.getRestockBrandList);
      flow.restock.checkedToggleBrand(1);

      await FlowHarness.call(tester, () => flow.restock.getRestockProductList(1));

      expect(flow.adapter.requests.last.fields['brand_ids'], jsonEncode(<int>[9]));
    });

    group('changing a quantity', () {
      ScriptedAdapter server(List<ScriptedAnswer> updates) {
        int next = 0;
        return ScriptedAdapter((RecordedRequest request) {
          if (request.path == _restockBrandsPath) {
            return ScriptedAnswer.json(<String, Object?>{'brands': <Object?>[]});
          }
          if (request.path == _restockListPath) return ScriptedAnswer.json(restockPageJson(<Map<String, Object?>>[]));
          return updates[next++];
        });
      }

      testWidgets('is a POST of the product, its stock and the variations as one text, signed in',
          (WidgetTester tester) async {
        final _StockFlow flow = await _StockFlow.pump(
            tester,
            server(<ScriptedAnswer>[
              ScriptedAnswer.json(<String, Object?>{'message': 'ok'})
            ]));
        await FlowHarness.call(tester, flow.restock.getRestockBrandList);
        flow.adapter.requests.clear();

        await flow.updateRestockQuantities(tester, medium: '4', large: '6', total: 10);

        final RecordedRequest request = flow.adapter.requests.first;
        expect(request.method, 'POST');
        expect(request.path, _restockUpdatePath);
        expect(request.rawQuery, isEmpty);
        expect(request.fields.keys, unorderedEquals(<String>['product_id', 'current_stock', 'variation']));
        expect(request.fields['product_id'], 7);
        expect(request.fields['current_stock'], 10);
        expect(
          jsonDecode(request.fields['variation']! as String),
          <Object?>[
            <String, Object?>{'type': 'M', 'price': 25.0, 'sku': 'RS-M', 'qty': 4},
            <String, Object?>{'type': 'L', 'price': 27.5, 'sku': 'RS-L', 'qty': 6},
          ],
        );
        FlowHarness.expectSignedIn(request);
      });

      testWidgets('that was accepted is told to the seller, closes the dialog, and reads the requests again',
          (WidgetTester tester) async {
        final _StockFlow flow = await _StockFlow.pump(
            tester,
            server(<ScriptedAnswer>[
              ScriptedAnswer.json(<String, Object?>{'message': 'ok'})
            ]));
        await FlowHarness.call(tester, flow.restock.getRestockBrandList);
        flow.adapter.requests.clear();

        await flow.updateRestockQuantities(tester);

        expect(FlowHarness.shown(tester), <String>[_enQuantityUpdated]);
        expect(FlowHarness.screenIsOpen(tester), isFalse);
        expect(flow.adapter.requests.map((request) => request.path), <String>[_restockUpdatePath, _restockListPath]);
        expect(flow.restock.restockProductModel!.data, isEmpty, reason: 'the list shows what the server now says');
      });

      testWidgets('that the server refuses is shown in its words and leaves the dialog open',
          (WidgetTester tester) async {
        final _StockFlow flow =
            await _StockFlow.pump(tester, server(<ScriptedAnswer>[messageRefusal(_updateFailedText)]));
        await FlowHarness.call(tester, flow.restock.getRestockBrandList);

        await flow.updateRestockQuantities(tester);

        expect(FlowHarness.shown(tester), <String>[_updateFailedText]);
        expect(FlowHarness.screenIsOpen(tester), isTrue);
        expect(flow.restock.isLoading, isFalse);
      });

      testWidgets('survives a transport failure, leaves the dialog open, and can be sent again',
          (WidgetTester tester) async {
        final _StockFlow flow = await _StockFlow.pump(
          tester,
          server(<ScriptedAnswer>[
            ScriptedAnswer.timeout(),
            ScriptedAnswer.json(<String, Object?>{'message': 'ok'})
          ]),
        );
        await FlowHarness.call(tester, flow.restock.getRestockBrandList);

        await flow.updateRestockQuantities(tester);

        expect(FlowHarness.shown(tester), <String>[_enTimeout]);
        expect(FlowHarness.screenIsOpen(tester), isTrue);
        expect(flow.restock.isLoading, isFalse);

        await FlowHarness.dismissToast(tester);
        await flow.updateRestockQuantities(tester);

        expect(FlowHarness.shown(tester), <String>[_enQuantityUpdated]);
        expect(FlowHarness.screenIsOpen(tester), isFalse);
      });
    });

    // KNOWN DEFECT, not fixed here (this task changes tests only): RestockController.getRestockProductList has no branch for
    // a failed answer, so a refusal or a transport failure is swallowed and the restock screen stays on its placeholder.
    // The test states what the screen should do; it is skipped until the controller does it.
    testWidgets(
        'that fail to load are shown to the seller instead of leaving the screen empty (SKIPPED: known defect, swallowed)',
        (WidgetTester tester) async {
      final _StockFlow flow = await _StockFlow.pump(tester, ScriptedAdapter.always(permissionRefusal()));
      flow.restock.brands = <Brands>[];

      await FlowHarness.call(tester, () => flow.restock.getRestockProductList(1));

      expect(FlowHarness.shown(tester), <String>[permissionRefusalText]);
    }, skip: true);
  });

  group('the stock ledger', () {
    testWidgets('reads the overview with a GET, and the reasons it offers are the server\'s',
        (WidgetTester tester) async {
      final _StockFlow flow =
          await _StockFlow.pump(tester, ScriptedAdapter.always(ScriptedAnswer.json(inventoryOverviewJson())));

      await FlowHarness.call(tester, flow.inventory.getOverview);

      expect(flow.adapter.only.method, 'GET');
      expect(flow.adapter.only.path, _overviewPath);
      expect(flow.adapter.only.rawQuery, isEmpty);
      FlowHarness.expectSignedIn(flow.adapter.only);
      expect(flow.inventory.overview!.unitsOnHand, 600);
      expect(flow.inventory.reasons, contains('damage'));
      expect(flow.inventory.isLoading, isFalse);
    });

    testWidgets('reads the movements of one product and one kind, twenty-five at a time', (WidgetTester tester) async {
      final _StockFlow flow =
          await _StockFlow.pump(tester, ScriptedAdapter.always(ScriptedAnswer.json(inventoryMovementsJson())));

      await FlowHarness.call(tester, () => flow.inventory.getMovements(productId: 7, type: 'adjustment'));

      expect(flow.adapter.only.method, 'GET');
      expect(flow.adapter.only.path, _movementsPath);
      expect(flow.adapter.only.query,
          <String, String>{'limit': '25', 'offset': '1', 'product_id': '7', 'type': 'adjustment'});
      expect(flow.inventory.movements!.movements.single.qtyChange, -2);
      expect(flow.inventory.movements!.movements.single.balanceAfter, 498);
    });

    testWidgets('that is refused is shown in the server\'s words and leaves the ledger as it was',
        (WidgetTester tester) async {
      final _StockFlow flow = await _StockFlow.pump(
        tester,
        ScriptedAdapter.inOrder(<ScriptedAnswer>[ScriptedAnswer.json(inventoryOverviewJson()), permissionRefusal()]),
      );
      await FlowHarness.call(tester, flow.inventory.getOverview);

      await FlowHarness.call(tester, flow.inventory.getOverview);

      expect(FlowHarness.shown(tester), <String>[permissionRefusalText]);
      expect(flow.inventory.overview!.unitsOnHand, 600);
      expect(flow.inventory.isLoading, isFalse);
    });

    testWidgets('that fails in transport is shown, throws nothing, and can be read again', (WidgetTester tester) async {
      final _StockFlow flow = await _StockFlow.pump(
        tester,
        ScriptedAdapter.inOrder(
            <ScriptedAnswer>[ScriptedAnswer.offline(), ScriptedAnswer.json(inventoryOverviewJson())]),
      );

      await FlowHarness.call(tester, flow.inventory.getOverview);

      expect(FlowHarness.shown(tester), <String>[_enNoInternet]);
      expect(flow.inventory.overview, isNull);
      expect(flow.inventory.isLoading, isFalse);

      await FlowHarness.dismissToast(tester);
      await FlowHarness.call(tester, flow.inventory.getOverview);

      expect(flow.inventory.overview!.unitsOnHand, 600);
    });

    group('a correction', () {
      testWidgets('is a POST of the signed change, the reason and the note, to the product\'s own address',
          (WidgetTester tester) async {
        final _StockFlow flow = await _StockFlow.pump(
          tester,
          ScriptedAdapter.inOrder(<ScriptedAnswer>[
            ScriptedAnswer.json(<String, Object?>{'message': 'Stock updated', 'balance_after': 548}),
            ScriptedAnswer.json(inventoryMovementsJson()),
            ScriptedAnswer.json(inventoryOverviewJson()),
          ]),
        );

        final String? refusal = await FlowHarness.call(
            tester, () => flow.inventory.adjust(productId: 7, delta: -2, reason: 'damage', note: 'Broken in transit'));

        expect(refusal, isNull);
        final RecordedRequest request = flow.adapter.requests.first;
        expect(request.method, 'POST');
        expect(request.path, _adjustPath);
        expect(request.rawQuery, isEmpty);
        expect(request.fields, <String, Object?>{'delta': -2, 'reason': 'damage', 'note': 'Broken in transit'});
        FlowHarness.expectSignedIn(request);
      });

      testWidgets('leaves the note out when the seller wrote none', (WidgetTester tester) async {
        final _StockFlow flow = await _StockFlow.pump(
          tester,
          ScriptedAdapter.inOrder(<ScriptedAnswer>[
            ScriptedAnswer.json(<String, Object?>{'message': 'Stock updated'}),
            ScriptedAnswer.json(inventoryMovementsJson()),
            ScriptedAnswer.json(inventoryOverviewJson()),
          ]),
        );

        await FlowHarness.call(tester, () => flow.inventory.adjust(productId: 7, delta: 40, reason: 'found', note: ''));

        expect(flow.adapter.requests.first.fields, <String, Object?>{'delta': 40, 'reason': 'found'});
      });

      testWidgets('that was accepted answers nothing to show, and reads the ledger and the overview again',
          (WidgetTester tester) async {
        final _StockFlow flow = await _StockFlow.pump(
          tester,
          ScriptedAdapter.inOrder(<ScriptedAnswer>[
            ScriptedAnswer.json(<String, Object?>{'message': 'Stock updated'}),
            ScriptedAnswer.json(inventoryMovementsJson(changes: <int>[-2, 5])),
            ScriptedAnswer.json(inventoryOverviewJson(unitsOnHand: 598)),
          ]),
        );

        final String? refusal =
            await FlowHarness.call(tester, () => flow.inventory.adjust(productId: 7, delta: -2, reason: 'damage'));

        expect(refusal, isNull);
        expect(
          flow.adapter.requests.map((request) => '${request.method} ${request.path}'),
          <String>['POST $_adjustPath', 'GET $_movementsPath', 'GET $_overviewPath'],
        );
        expect(flow.inventory.movements!.movements, hasLength(2));
        expect(flow.inventory.overview!.unitsOnHand, 598);
        expect(flow.inventory.isAdjusting, isFalse);
      });

      testWidgets('that fails validation answers the server\'s words, and reads nothing again',
          (WidgetTester tester) async {
        final _StockFlow flow =
            await _StockFlow.pump(tester, ScriptedAdapter.always(errorsRefusal('delta', _deltaRequiredText)));

        final String? refusal =
            await FlowHarness.call(tester, () => flow.inventory.adjust(productId: 7, delta: -2, reason: 'damage'));

        expect(refusal, _deltaRequiredText);
        expect(flow.adapter.requests, hasLength(1));
        expect(flow.inventory.isAdjusting, isFalse);
      });

      // KNOWN DEFECT, not fixed here (this task changes tests only): the 422 the API documents for this refusal reaches the
      // controller as an ErrorResponse object, so adjust() answers "Instance of 'ErrorResponse'" instead of the server's
      // words. The test states what the controller should answer; it is skipped until it does.
      testWidgets('that would take the stock below zero answers the server\'s words (SKIPPED: known defect, 422)',
          (WidgetTester tester) async {
        final _StockFlow flow =
            await _StockFlow.pump(tester, ScriptedAdapter.always(errorsRefusal('stock', _belowZeroText, status: 422)));

        final String? refusal =
            await FlowHarness.call(tester, () => flow.inventory.adjust(productId: 7, delta: -900, reason: 'loss'));

        expect(refusal, _belowZeroText);
        expect(flow.inventory.isAdjusting, isFalse);
      }, skip: true);

      testWidgets('that fails in transport answers a reason, throws nothing, and can be sent again',
          (WidgetTester tester) async {
        final _StockFlow flow = await _StockFlow.pump(
          tester,
          ScriptedAdapter.inOrder(<ScriptedAnswer>[
            ScriptedAnswer.offline(),
            ScriptedAnswer.json(<String, Object?>{'message': 'Stock updated'}),
            ScriptedAnswer.json(inventoryMovementsJson()),
            ScriptedAnswer.json(inventoryOverviewJson()),
          ]),
        );

        final String? refusal =
            await FlowHarness.call(tester, () => flow.inventory.adjust(productId: 7, delta: -2, reason: 'damage'));

        expect(refusal, isNotNull);
        expect(flow.inventory.isAdjusting, isFalse);

        final String? second =
            await FlowHarness.call(tester, () => flow.inventory.adjust(productId: 7, delta: -2, reason: 'damage'));

        expect(second, isNull);
        expect(flow.adapter.requests[1].fields, flow.adapter.requests.first.fields,
            reason: 'the retry is the same correction');
      });
    });
  });

  group('the correction sheet', () {
    const Widget sheet = Scaffold(
      body: SingleChildScrollView(child: StockAdjustSheet(productId: 7, currentStock: 12, productName: 'Rose Serum')),
    );

    Future<_StockFlow> pumpSheet(WidgetTester tester, List<ScriptedAnswer> afterOverview) async {
      final _StockFlow flow = await _StockFlow.pump(
        tester,
        ScriptedAdapter.inOrder(<ScriptedAnswer>[ScriptedAnswer.json(inventoryOverviewJson()), ...afterOverview]),
        screen: sheet,
      );
      await FlowHarness.call(tester, flow.inventory.getOverview);
      flow.adapter.requests.clear();
      return flow;
    }

    Future<void> letTheTapFinish(WidgetTester tester) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      for (int step = 0; step < 6; step++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> fill(WidgetTester tester, {String quantity = '5', String note = ''}) async {
      await tester.enterText(find.byType(TextField).at(0), quantity);
      await tester.tap(find.text('Remove'));
      await tester.pump();
      await tester.tap(find.text('Damage'));
      await tester.pump();
      if (note.isNotEmpty) await tester.enterText(find.byType(TextField).at(1), note);
      await tester.pump();
    }

    testWidgets('sends nothing until a quantity and a reason are chosen', (WidgetTester tester) async {
      final _StockFlow flow = await pumpSheet(tester, <ScriptedAnswer>[]);

      await tester.tap(find.text('Apply'));
      await letTheTapFinish(tester);
      await tester.enterText(find.byType(TextField).at(0), '5');
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await letTheTapFinish(tester);

      expect(flow.adapter.requests, isEmpty);
      expect(find.byType(StockAdjustSheet), findsOneWidget);
    });

    testWidgets(
        'sends the quantity as a negative change when the seller removes stock, with the reason and the note, and closes on success',
        (WidgetTester tester) async {
      final _StockFlow flow = await pumpSheet(tester, <ScriptedAnswer>[
        ScriptedAnswer.json(<String, Object?>{'message': 'Stock updated', 'balance_after': 7}),
        ScriptedAnswer.json(inventoryMovementsJson()),
        ScriptedAnswer.json(inventoryOverviewJson(unitsOnHand: 595)),
      ]);

      await fill(tester, quantity: '5', note: 'Broken in transit');
      await tester.tap(find.text('Apply'));
      await letTheTapFinish(tester);

      expect(flow.adapter.requests.first.method, 'POST');
      expect(flow.adapter.requests.first.path, _adjustPath);
      expect(flow.adapter.requests.first.fields,
          <String, Object?>{'delta': -5, 'reason': 'damage', 'note': 'Broken in transit'});
      expect(
          flow.adapter.requests.map((request) => request.path), <String>[_adjustPath, _movementsPath, _overviewPath]);
      expect(find.byType(StockAdjustSheet), findsNothing,
          reason: 'the sheet closes once the correction is in the ledger');
      expect(flow.inventory.overview!.unitsOnHand, 595);
    });

    testWidgets('sends the quantity as a positive change when the seller adds stock', (WidgetTester tester) async {
      final _StockFlow flow = await pumpSheet(tester, <ScriptedAnswer>[
        ScriptedAnswer.json(<String, Object?>{'message': 'Stock updated'}),
        ScriptedAnswer.json(inventoryMovementsJson()),
        ScriptedAnswer.json(inventoryOverviewJson()),
      ]);

      await tester.enterText(find.byType(TextField).at(0), '9');
      await tester.tap(find.text('Damage'));
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await letTheTapFinish(tester);

      expect(flow.adapter.requests.first.fields['delta'], 9);
    });

    testWidgets(
        'that fails validation shows the server\'s words in the sheet, which stays open for the seller to correct',
        (WidgetTester tester) async {
      final _StockFlow flow = await pumpSheet(tester, <ScriptedAnswer>[errorsRefusal('delta', _deltaRequiredText)]);

      await fill(tester);
      await tester.tap(find.text('Apply'));
      await letTheTapFinish(tester);

      expect(find.text(_deltaRequiredText), findsOneWidget);
      expect(find.byType(StockAdjustSheet), findsOneWidget);
      expect(flow.adapter.requests, hasLength(1), reason: 'nothing is read again after a refusal');

      await tester.enterText(find.byType(TextField).at(0), '4');
      await tester.pump();

      expect(find.text(_deltaRequiredText), findsNothing, reason: 'the words go when the seller changes the number');
    });

    // KNOWN DEFECT, not fixed here (this task changes tests only): the sheet shows "Instance of 'ErrorResponse'" for the 422
    // the API documents for this refusal. The test states what the sheet should show; it is skipped until it does.
    testWidgets(
        'that would take the stock below zero shows the server\'s words in the sheet (SKIPPED: known defect, 422)',
        (WidgetTester tester) async {
      await pumpSheet(tester, <ScriptedAnswer>[errorsRefusal('stock', _belowZeroText, status: 422)]);

      await fill(tester, quantity: '900');
      await tester.tap(find.text('Apply'));
      await letTheTapFinish(tester);

      expect(find.text(_belowZeroText), findsOneWidget);
    }, skip: true);

    // KNOWN DEFECT, not fixed here (this task changes tests only): the sheet shows the key "no_internet_connection" as it
    // came from the error handler, where every other screen shows its translation. The test states what the sheet should
    // show; it is skipped until it does.
    testWidgets('that fails in transport tells the seller so in words (SKIPPED: known defect, untranslated key)',
        (WidgetTester tester) async {
      await pumpSheet(tester, <ScriptedAnswer>[ScriptedAnswer.offline()]);

      await fill(tester);
      await tester.tap(find.text('Apply'));
      await letTheTapFinish(tester);

      expect(find.text(_enNoInternet), findsOneWidget);
    }, skip: true);

    testWidgets('that fails in transport leaves the sheet open and the button usable for another try',
        (WidgetTester tester) async {
      final _StockFlow flow = await pumpSheet(tester, <ScriptedAnswer>[
        ScriptedAnswer.offline(),
        ScriptedAnswer.json(<String, Object?>{'message': 'Stock updated'}),
        ScriptedAnswer.json(inventoryMovementsJson()),
        ScriptedAnswer.json(inventoryOverviewJson()),
      ]);

      await fill(tester);
      await tester.tap(find.text('Apply'));
      await letTheTapFinish(tester);

      expect(find.byType(StockAdjustSheet), findsOneWidget);
      expect(flow.inventory.isAdjusting, isFalse);

      await tester.tap(find.text('Apply'));
      await letTheTapFinish(tester);

      expect(flow.adapter.requests[1].fields, flow.adapter.requests.first.fields,
          reason: 'the second try is the same correction');
      expect(find.byType(StockAdjustSheet), findsNothing);
    });
  });

  group('a bulk stock change', () {
    void choose(_StockFlow flow) {
      flow.bulk.toggle(Product(id: 7, name: 'Rose Serum'));
      flow.bulk.toggle(Product(id: 8, name: 'Argan Oil'));
    }

    testWidgets('is a POST of the products chosen, the mode, the value and the note, signed in',
        (WidgetTester tester) async {
      final _StockFlow flow = await _StockFlow.pump(tester, ScriptedAdapter.always(_bulkAccepted(_bulkJobJson())));
      choose(flow);

      await FlowHarness.call(tester, () => flow.bulk.submitStockUpdate(mode: 'set', value: 25, note: 'Stocktake'));

      expect(flow.adapter.only.method, 'POST');
      expect(flow.adapter.only.path, _bulkStockPath);
      expect(flow.adapter.only.rawQuery, isEmpty);
      expect(flow.adapter.only.fields, <String, Object?>{
        'product_ids': <Object?>[7, 8],
        'mode': 'set',
        'value': 25,
        'note': 'Stocktake',
      });
      FlowHarness.expectSignedIn(flow.adapter.only);
    });

    testWidgets('leaves the note out when the seller wrote none', (WidgetTester tester) async {
      final _StockFlow flow = await _StockFlow.pump(tester, ScriptedAdapter.always(_bulkAccepted(_bulkJobJson())));
      choose(flow);

      await FlowHarness.call(tester, () => flow.bulk.submitStockUpdate(mode: 'set', value: 25));

      expect(flow.adapter.only.fields, <String, Object?>{
        'product_ids': <Object?>[7, 8],
        'mode': 'set',
        'value': 25
      });
    });

    testWidgets('that finished is the receipt the screen reads, and nothing is asked again',
        (WidgetTester tester) async {
      final _StockFlow flow = await _StockFlow.pump(tester, ScriptedAdapter.always(_bulkAccepted(_bulkJobJson())));
      choose(flow);

      final BulkJobModel? receipt =
          await FlowHarness.call(tester, () => flow.bulk.submitStockUpdate(mode: 'set', value: 25));

      expect(receipt!.id, 9);
      expect(receipt.status, 'completed');
      expect(receipt.succeeded, 2);
      expect(flow.bulk.job, same(receipt));
      expect(flow.bulk.isSubmitting, isFalse);
      expect(flow.adapter.requests, hasLength(1));
      expect(FlowHarness.shown(tester), isEmpty);
    });

    testWidgets('that refused some products is a receipt that names each one and why', (WidgetTester tester) async {
      final _StockFlow flow = await _StockFlow.pump(
        tester,
        ScriptedAdapter.always(_bulkAccepted(_bulkJobJson(
          status: 'partial',
          succeeded: 1,
          failed: 1,
          failures: <Object?>[
            <String, Object?>{
              'product_id': 8,
              'name': 'Argan Oil',
              'reason': 'bulk_reason_negative_stock',
              'message': 'The stock cannot go below zero'
            },
          ],
        ))),
      );
      choose(flow);

      final BulkJobModel? receipt =
          await FlowHarness.call(tester, () => flow.bulk.submitStockUpdate(mode: 'set', value: -4));

      expect(receipt!.isPartial, isTrue);
      expect(receipt.failures.single.productId, 8);
      expect(receipt.failures.single.message, 'The stock cannot go below zero');
    });

    testWidgets('that is still running is asked about until it has finished', (WidgetTester tester) async {
      final _StockFlow flow = await _StockFlow.pump(
        tester,
        ScriptedAdapter.routes(<String, ScriptedServer>{
          'POST $_bulkStockPath': (_) => _bulkAccepted(_bulkJobJson(status: 'queued', finished: false, succeeded: 0)),
          'GET $_bulkJobPath': (_) => ScriptedAnswer.json(<String, Object?>{'job': _bulkJobJson()}),
        }),
      );
      choose(flow);

      final BulkJobModel? receipt =
          await FlowHarness.call(tester, () => flow.bulk.submitStockUpdate(mode: 'set', value: 25));

      expect(
        flow.adapter.requests.map((request) => '${request.method} ${request.path}'),
        <String>['POST $_bulkStockPath', 'GET $_bulkJobPath'],
      );
      expect(receipt!.isFinished, isTrue);
      expect(receipt.succeeded, 2);
      expect(flow.bulk.job!.status, 'completed');
    });

    testWidgets('that the server refuses is shown in its words, answers no receipt, and can be sent again',
        (WidgetTester tester) async {
      final _StockFlow flow = await _StockFlow.pump(
        tester,
        ScriptedAdapter.inOrder(<ScriptedAnswer>[permissionRefusal(), _bulkAccepted(_bulkJobJson())]),
      );
      choose(flow);

      final BulkJobModel? refused =
          await FlowHarness.call(tester, () => flow.bulk.submitStockUpdate(mode: 'set', value: 25));

      expect(refused, isNull);
      expect(FlowHarness.shown(tester), <String>[permissionRefusalText]);
      expect(flow.bulk.job, isNull);
      expect(flow.bulk.isSubmitting, isFalse, reason: 'the button the seller pressed is usable again');
      expect(flow.bulk.selectedCount, 2, reason: 'the seller keeps the products they chose');

      await FlowHarness.dismissToast(tester);
      final BulkJobModel? receipt =
          await FlowHarness.call(tester, () => flow.bulk.submitStockUpdate(mode: 'set', value: 25));

      expect(receipt!.succeeded, 2);
      expect(flow.adapter.requests[1].fields, flow.adapter.requests.first.fields,
          reason: 'the retry is the same change');
    });

    testWidgets('that fails in transport is shown, throws nothing, and answers no receipt',
        (WidgetTester tester) async {
      final _StockFlow flow = await _StockFlow.pump(tester, ScriptedAdapter.always(ScriptedAnswer.timeout()));
      choose(flow);

      final BulkJobModel? receipt =
          await FlowHarness.call(tester, () => flow.bulk.submitStockUpdate(mode: 'set', value: 25));

      expect(receipt, isNull);
      expect(FlowHarness.shown(tester), <String>[_enTimeout]);
      expect(flow.bulk.isSubmitting, isFalse);
    });
  });
}
