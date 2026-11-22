import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/features/addProduct/controllers/add_product_controller.dart';
import 'package:syriacosmeticsmanger/features/addProduct/controllers/add_product_image_controller.dart';
import 'package:syriacosmeticsmanger/features/addProduct/controllers/digital_product_controller.dart';
import 'package:syriacosmeticsmanger/features/addProduct/controllers/variation_controller.dart';
import 'package:syriacosmeticsmanger/features/addProduct/domain/models/add_product_model.dart';
import 'package:syriacosmeticsmanger/features/addProduct/domain/repository/add_product_repository.dart';
import 'package:syriacosmeticsmanger/features/addProduct/domain/services/add_product_service.dart';
import 'package:syriacosmeticsmanger/features/auth/controllers/auth_controller.dart';
import 'package:syriacosmeticsmanger/features/auth/domain/services/auth_service_interface.dart';
import 'package:syriacosmeticsmanger/features/product/domain/models/product_model.dart';
import 'package:syriacosmeticsmanger/features/splash/controllers/splash_controller.dart';
import 'package:syriacosmeticsmanger/features/splash/domain/models/config_model.dart';
import 'package:syriacosmeticsmanger/features/splash/domain/services/splash_service_interface.dart';

import 'support/fixtures.dart';
import 'support/flow_harness.dart';
import 'support/scripted_adapter.dart';

const String _addPath = '/api/v3/seller/products/add';
const String _updatePath = '/api/v3/seller/products/update/7';
const String _attributesPath = '/api/v1/attributes';

const String _enNoInternet = 'No internet connection';
const String _enAddFailed = 'Product add failed';
const String _validationText = 'The unit price field is required.';

class _TokenOnlyAuthService implements AuthServiceInterface {
  @override
  String getUserToken() => FlowHarness.sessionToken;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('saving a product does not use ${invocation.memberName}');
}

class _UnusedSplashService implements SplashServiceInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('saving a product does not use ${invocation.memberName}');
}

/// The splash controller as the app has it once the config is read: the one fact a saved product depends on, which is
/// whether the marketplace runs brands.
class _ConfiguredSplashController extends SplashController {
  _ConfiguredSplashController({required this.brands}) : super(serviceInterface: _UnusedSplashService());

  final bool brands;

  @override
  ConfigModel? get configModel => ConfigModel(brandSetting: brands ? '1' : '0');
}

/// A server that answers the attribute list the screen reads first, and answers every save with the next of [saves]; a
/// save the script has no answer for fails loudly.
ScriptedAdapter _server(List<ScriptedAnswer> saves) {
  int next = 0;
  return ScriptedAdapter((RecordedRequest request) {
    if (request.method == 'GET' && request.path == _attributesPath) {
      return ScriptedAnswer.json(<Object?>[]);
    }
    if (next >= saves.length) {
      throw StateError('The script has no answer for save ${next + 1}: ${request.method} ${request.uri}');
    }
    return saves[next++];
  });
}

ScriptedAnswer get _saved => ScriptedAnswer.json(<String, Object?>{'message': 'Product added successfully'});

/// The product the seller filled the form in with, and what the form keeps beside it.
Product _product({int? id}) => Product(
      id: id,
      productType: 'physical',
      code: 'ABC123',
      unit: 'pc',
      brandId: 4,
      categoryIds: <CategoryIds>[CategoryIds(id: '12', position: 0), CategoryIds(id: '34', position: 1)],
      unitPrice: 25.5,
      discount: 2,
      discountType: 'flat',
      taxModel: 'exclude',
      taxIds: <int?>[1],
      currentStock: 12,
      shippingCost: 3,
      multiplyWithQuantity: 0,
      minimumOrderQty: 1,
      metaTitle: 'Rose Serum',
      metaDescription: 'A serum made of roses.',
    );

AddProductModel _form() => AddProductModel(
      titleList: <String>['Rose Serum', 'سيروم الورد'],
      descriptionList: <String>['<p>A serum made of roses.</p>', '<p>سيروم مصنوع من الورد.</p>'],
      languageList: <String?>['en', 'ar'],
      colorCodeList: <String?>[],
    );

class _SaveFlow {
  _SaveFlow._(this.adapter, this.controller, this.routes);

  final ScriptedAdapter adapter;
  final AddProductController controller;
  final RouteLog routes;

  static Future<_SaveFlow> pump(WidgetTester tester, ScriptedAdapter adapter, {bool brands = true}) async {
    final DioClient client = await FlowHarness.client(adapter);
    final AddProductService service = AddProductService(shopRepoInterface: AddProductRepository(dioClient: client));
    final AddProductController controller = AddProductController(shopServiceInterface: service);
    final AddProductImageController images = AddProductImageController(shopServiceInterface: service);
    final DigitalProductController digital = DigitalProductController(addProductServiceInterface: service);
    final VariationController variations = VariationController(addProductServiceInterface: service);
    final RouteLog routes = RouteLog();

    await FlowHarness.pump(
      tester,
      observers: <NavigatorObserver>[routes],
      providers: [
        ChangeNotifierProvider<AddProductController>.value(value: controller),
        ChangeNotifierProvider<AddProductImageController>.value(value: images),
        ChangeNotifierProvider<DigitalProductController>.value(value: digital),
        ChangeNotifierProvider<VariationController>.value(value: variations),
        ChangeNotifierProvider<AuthController>(
            create: (_) => AuthController(authServiceInterface: _TokenOnlyAuthService())),
        ChangeNotifierProvider<SplashController>(create: (_) => _ConfiguredSplashController(brands: brands)),
      ],
    );

    // The form reads the attributes when it opens, which is what gives it the colour attribute a save reads.
    await FlowHarness.call(tester, () => variations.getAttributeList(Get.context!, null, 'en'));
    adapter.requests.clear();

    addTearDown(controller.dispose);
    addTearDown(images.dispose);
    addTearDown(digital.dispose);
    addTearDown(variations.dispose);

    return _SaveFlow._(adapter, controller, routes);
  }

  /// The save, run as the form's button runs it. A save that succeeds replaces the whole stack with the product list,
  /// a screen that needs the rest of the app to build, so no frame is drawn after it: what it did is read from the state
  /// and from the routes it pushed.
  Future<void> saveWithoutDrawing(WidgetTester tester, {required bool isAdd}) async {
    await tester.runAsync(() => controller.addProduct(
          Get.context!,
          _product(id: isAdd ? null : 7),
          _form(),
          'rose.png',
          'meta.png',
          isAdd,
          <String?>['serum', 'rose'],
        ));
  }

  Future<void> save(WidgetTester tester, {required bool isAdd}) => FlowHarness.call(
        tester,
        () => controller.addProduct(
          Get.context!,
          _product(id: isAdd ? null : 7),
          _form(),
          'rose.png',
          'meta.png',
          isAdd,
          <String?>['serum', 'rose'],
        ),
      );
}

void main() {
  group('adding a product', () {
    testWidgets('is a POST to the add address, signed in, with the form\'s fields in the keys the API reads',
        (WidgetTester tester) async {
      final _SaveFlow flow = await _SaveFlow.pump(tester, _server(<ScriptedAnswer>[_saved]));

      await flow.saveWithoutDrawing(tester, isAdd: true);

      final RecordedRequest request = flow.adapter.only;
      expect(request.method, 'POST');
      expect(request.path, _addPath);
      expect(request.rawQuery, isEmpty);
      FlowHarness.expectSignedIn(request);
      expect(request.fields, containsPair('name', jsonEncode(<String>['Rose Serum', 'سيروم الورد'])));
      expect(
          request.fields,
          containsPair(
              'description', jsonEncode(<String>['<p>A serum made of roses.</p>', '<p>سيروم مصنوع من الورد.</p>'])));
      expect(request.fields, containsPair('lang', jsonEncode(<String>['en', 'ar'])));
      expect(request.fields, containsPair('unit_price', 25.5));
      expect(request.fields, containsPair('discount', 2));
      expect(request.fields, containsPair('discount_type', 'flat'));
      expect(request.fields, containsPair('tax_ids', jsonEncode(<int>[1])));
      expect(request.fields, containsPair('tax_model', 'exclude'));
      expect(request.fields, containsPair('category_id', '12'));
      expect(request.fields, containsPair('sub_category_id', '34'));
      expect(request.fields, containsPair('unit', 'pc'));
      expect(request.fields, containsPair('brand_id', 4));
      expect(request.fields, containsPair('current_stock', 12));
      expect(request.fields, containsPair('shipping_cost', 3));
      expect(request.fields, containsPair('minimum_order_qty', 1));
      expect(request.fields, containsPair('code', 'ABC123'));
      expect(request.fields, containsPair('product_type', 'physical'));
      expect(request.fields, containsPair('thumbnail', 'rose.png'));
      expect(request.fields, containsPair('meta_image', 'meta.png'));
      expect(request.fields, containsPair('tags', jsonEncode(<String>['serum', 'rose'])));
      expect(request.fields.keys, isNot(contains('_method')), reason: 'a new product is not an update');
      expect(request.fields.keys, isNot(contains('id')));
    });

    testWidgets('leaves the brand out when the marketplace runs without brands', (WidgetTester tester) async {
      final _SaveFlow flow = await _SaveFlow.pump(tester, _server(<ScriptedAnswer>[_saved]), brands: false);

      await flow.saveWithoutDrawing(tester, isAdd: true);

      expect(flow.adapter.only.fields, containsPair('brand_id', null));
    });

    testWidgets('that was accepted leaves the form behind and goes to the product list', (WidgetTester tester) async {
      final _SaveFlow flow = await _SaveFlow.pump(tester, _server(<ScriptedAnswer>[_saved]));
      final int openedBefore = flow.routes.pushed.length;
      flow.controller.productCode.text = 'ABC123';
      flow.controller.titleControllerList.add(TextEditingController(text: 'Rose Serum'));
      flow.controller.descriptionControllerList.add(TextEditingController(text: 'A serum made of roses.'));

      await flow.saveWithoutDrawing(tester, isAdd: true);

      expect(flow.controller.isLoading, isFalse);
      expect(flow.routes.pushed.length, openedBefore + 1, reason: 'the product list was pushed');
      expect(flow.routes.removed, hasLength(2), reason: 'the form and what was under it were removed from the stack');
      expect(flow.controller.titleControllerList, isEmpty, reason: 'the next form starts empty');
      expect(flow.controller.descriptionControllerList, isEmpty);
      expect(flow.controller.productCode.text, isEmpty);
    });

    testWidgets('that the server refuses keeps what the seller typed in the form', (WidgetTester tester) async {
      final _SaveFlow flow =
          await _SaveFlow.pump(tester, _server(<ScriptedAnswer>[errorsRefusal('unit_price', _validationText)]));
      flow.controller.productCode.text = 'ABC123';
      flow.controller.titleControllerList.add(TextEditingController(text: 'Rose Serum'));

      await flow.save(tester, isAdd: true);

      expect(flow.controller.productCode.text, 'ABC123');
      expect(flow.controller.titleControllerList.single.text, 'Rose Serum');
    });

    testWidgets('that the server refuses is shown in its words, then as a failed add, and keeps the form',
        (WidgetTester tester) async {
      final _SaveFlow flow =
          await _SaveFlow.pump(tester, _server(<ScriptedAnswer>[errorsRefusal('unit_price', _validationText)]));
      final int openedBefore = flow.routes.pushed.length;

      await flow.save(tester, isAdd: true);

      expect(FlowHarness.shown(tester), <String>[_validationText], reason: 'the server\'s reason is first');
      await FlowHarness.dismissToast(tester);
      expect(FlowHarness.shown(tester), <String>[_enAddFailed]);
      expect(FlowHarness.screenIsOpen(tester), isTrue, reason: 'the seller keeps the form to correct it');
      expect(flow.routes.pushed.length, openedBefore, reason: 'nothing was pushed');
      expect(flow.controller.isLoading, isFalse, reason: 'the save button is usable again');
    });

    testWidgets('survives a transport failure, keeps the form, and sends the same product again on retry',
        (WidgetTester tester) async {
      final _SaveFlow flow = await _SaveFlow.pump(tester, _server(<ScriptedAnswer>[ScriptedAnswer.offline(), _saved]));

      await flow.save(tester, isAdd: true);

      expect(FlowHarness.shown(tester), <String>[_enNoInternet]);
      expect(FlowHarness.screenIsOpen(tester), isTrue);
      expect(flow.controller.isLoading, isFalse);

      await FlowHarness.dismissToast(tester);
      await FlowHarness.dismissToast(tester);
      await flow.saveWithoutDrawing(tester, isAdd: true);

      expect(flow.adapter.requests, hasLength(2));
      expect(flow.adapter.requests.last.fields, flow.adapter.requests.first.fields,
          reason: 'the retry is the same product');
      expect(flow.controller.isLoading, isFalse);
    });
  });

  group('updating a product', () {
    testWidgets('is a POST to the product\'s own update address, with the method and the id the API reads',
        (WidgetTester tester) async {
      final _SaveFlow flow = await _SaveFlow.pump(tester, _server(<ScriptedAnswer>[_saved]));

      await flow.saveWithoutDrawing(tester, isAdd: false);

      final RecordedRequest request = flow.adapter.only;
      expect(request.method, 'POST');
      expect(request.path, _updatePath);
      FlowHarness.expectSignedIn(request);
      expect(request.fields, containsPair('_method', 'put'));
      expect(request.fields, containsPair('id', 7));
      expect(request.fields, containsPair('name', jsonEncode(<String>['Rose Serum', 'سيروم الورد'])));
      expect(request.fields, containsPair('unit_price', 25.5));
      expect(request.fields, containsPair('current_stock', 12));
    });

    testWidgets('that the server refuses is shown in its words and keeps the form', (WidgetTester tester) async {
      final _SaveFlow flow =
          await _SaveFlow.pump(tester, _server(<ScriptedAnswer>[errorsRefusal('unit_price', _validationText)]));

      await flow.save(tester, isAdd: false);

      expect(FlowHarness.shown(tester), <String>[_validationText]);
      expect(FlowHarness.screenIsOpen(tester), isTrue);
      expect(flow.controller.isLoading, isFalse);
    });
  });
}
