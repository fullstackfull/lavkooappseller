import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/barcode_scan_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/cart_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/cart_model.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/repository/cart_repository.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/services/cart_service.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/services/cart_service_interface.dart';
import 'package:syriacosmeticsmanger/features/product/controllers/product_controller.dart';
import 'package:syriacosmeticsmanger/features/product/domain/models/product_model.dart';
import 'package:syriacosmeticsmanger/features/product/domain/services/product_service_interface.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

import 'harness.dart';
import 'scripted_adapter.dart';

/// What `pos/products` answers for one product: the fields the app reads, in the shapes the server sends them.
const Map<String, Object?> productJson = <String, Object?>{
  'id': 7,
  'added_by': 'seller',
  'user_id': 3,
  'name': 'Rose Serum',
  'slug': 'rose-serum',
  'product_type': 'physical',
  'code': 'ABC123',
  'brand_id': 1,
  'category_ids': <Object?>[],
  'unit': 'pc',
  'min_qty': 1,
  'images': <Object?>[],
  'thumbnail': 'rose.png',
  'colors_formatted': <Object?>[],
  'attributes': <Object?>[],
  'choice_options': <Object?>[],
  'variation': <Object?>[],
  'digital_product_file_types': <Object?>[],
  'unit_price': 25.5,
  'purchase_price': 10,
  'tax': 5,
  'tax_model': 'exclude',
  'tax_type': 'percent',
  'discount': 2,
  'discount_type': 'flat',
  'current_stock': 12,
  'status': 1,
  'reviews_count': 0,
  'average_review': 0,
};

ScriptedAnswer oneProduct([Map<String, Object?> product = productJson]) => ScriptedAnswer.json(product);

ScriptedAnswer ambiguity(List<Map<String, Object?>> candidates, {String message = 'Server words for the ambiguity.'}) =>
    ScriptedAnswer.json(
      <String, Object?>{
        'errors': <Object?>[
          <String, Object?>{'code': 'ambiguous_code', 'message': message, 'candidates': candidates},
        ],
      },
      status: 409,
    );

ScriptedAnswer countryRefused([String message = 'The country must be one of the configured storefront countries.']) =>
    ScriptedAnswer.json(
      <String, Object?>{
        'errors': <Object?>[
          <String, Object?>{'code': 'country', 'message': message},
        ],
      },
      status: 422,
    );

Map<String, Object?> candidate(int id, String name, String country) =>
    <String, Object?>{'id': id, 'name': name, 'country': country};

/// A controller that remembers the products the scan added instead of running the whole cart.
class RecordingCartController extends CartController {
  RecordingCartController() : super(cartServiceInterface: _UnusedCartService());

  final List<CartModel> added = <CartModel>[];

  @override
  void addToCart(BuildContext context, CartModel cartModel,
      {bool decreaseQuantity = false, bool updateToCart = false}) {
    added.add(cartModel);
  }
}

class RecordingProductController extends ProductController {
  RecordingProductController() : super(productServiceInterface: _UnusedProductService());

  final List<Product> initialised = <Product>[];

  @override
  void initData(Product product, int? minimumOrderQuantity, BuildContext context) {
    initialised.add(product);
  }
}

class _UnusedCartService implements CartServiceInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('the scan does not use ${invocation.memberName}');
}

class _UnusedProductService implements ProductServiceInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('the scan does not use ${invocation.memberName}');
}

/// The page the seller lands on when the sheet opens the product list, as far as these tests care.
const String productListStandIn = 'the product list page';

/// The scan as the app runs it: the real controller, service and repository, a scripted server instead of the network, and the
/// app (real themes and language files) around it.
class ScanFixture {
  ScanFixture._({required this.adapter, required this.scanner, required this.cart, required this.products});

  final ScriptedAdapter adapter;
  final BarcodeScanController scanner;
  final RecordingCartController cart;
  final RecordingProductController products;

  static Future<ScanFixture> pump(
    WidgetTester tester, {
    required ScriptedAdapter adapter,
    bool? storefrontsEnabled,
    Map<String, Object> stored = const <String, Object>{},
    Locale locale = PosScanHarness.english,
    Size screen = PosScanHarness.phone,
    double textScale = 1.0,
  }) async {
    PosScanHarness.useScreen(tester, screen);

    SharedPreferences.setMockInitialValues(stored);
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final DioClient client = DioClient(
      AppConstants.baseUrl,
      Dio()..httpClientAdapter = adapter,
      loggingInterceptor: LoggingInterceptor(),
      sharedPreferences: preferences,
    );
    final CartRepository repository = storefrontsEnabled == null
        ? CartRepository(dioClient: client, sharedPreferences: preferences)
        : CartRepository(dioClient: client, sharedPreferences: preferences, storefrontsEnabled: storefrontsEnabled);

    final RecordingCartController cart = RecordingCartController();
    final RecordingProductController products = RecordingProductController();
    final BarcodeScanController scanner = BarcodeScanController(
      cartServiceInterface: CartService(cartRepositoryInterface: repository),
      productListPage: (BuildContext context) => const Scaffold(body: Center(child: Text(productListStandIn))),
    );

    await tester.pumpWidget(await PosScanHarness.app(
      tester,
      locale: locale,
      textScale: textScale,
      providers: [
        ChangeNotifierProvider<CartController>.value(value: cart),
        ChangeNotifierProvider<ProductController>.value(value: products),
      ],
      home: const Scaffold(body: SizedBox.expand()),
    ));

    addTearDown(cart.dispose);
    addTearDown(products.dispose);
    addTearDown(scanner.dispose);

    return ScanFixture._(adapter: adapter, scanner: scanner, cart: cart, products: products);
  }

  /// A scan the sheet started when the seller tapped runs on the test's own clock, so the clock is moved on until it is done.
  Future<void> letTheScanFinish(WidgetTester tester) async {
    for (int step = 0; step < 10; step++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Scans [code] the way the scanner screen does after it reads one, and lets the screen settle on what the seller would see.
  /// A scan that throws fails the test; [scanThatThrows] is for the one that is expected to.
  Future<void> scan(WidgetTester tester, String code, {String? country}) async {
    await tester.runAsync(() => scanner.getProductFromScan(Get.context!, code, country: country));
    await _showWhatTheSellerSees(tester);
  }

  /// Scans [code] and hands back what the scan threw, or null when it threw nothing.
  Future<Object?> scanThatThrows(WidgetTester tester, String code, {String? country}) async {
    Object? thrown;
    await tester.runAsync(() async {
      try {
        await scanner.getProductFromScan(Get.context!, code, country: country);
      } catch (error) {
        thrown = error;
      }
    });
    await _showWhatTheSellerSees(tester);

    return thrown;
  }

  /// A snack bar is shown for a moment and then gone, so the screen is stepped to the moment it is on show rather than settled.
  Future<void> _showWhatTheSellerSees(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}
