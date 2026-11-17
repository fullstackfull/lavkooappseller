import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/order_details/controllers/order_details_controller.dart';
import 'package:syriacosmeticsmanger/features/order_details/domain/services/order_details_service_interface.dart';
import 'package:syriacosmeticsmanger/features/order_edit/controllers/order_edit_controller.dart';
import 'package:syriacosmeticsmanger/features/order_edit/domain/models/order_edit_submit_result.dart';
import 'package:syriacosmeticsmanger/features/order_edit/domain/services/order_edit_service_interface.dart';
import 'package:syriacosmeticsmanger/localization/app_localization.dart';

/// What the seller sees when "Update cart" is answered.
///
/// A refused edit comes back as HTTP 200 with `status: error`. The controller
/// used to treat every 200 as saved: it reloaded the order and the screen closed
/// without a word, so the seller believed an edit the server had refused was in.
/// These tests drive the real controller, with the network and the order screen
/// replaced by stand-ins, and look at what ends up on screen.
class _AnsweringOrderEditService implements OrderEditServiceInterface {
  _AnsweringOrderEditService(this.answer);

  final ApiResponse answer;

  @override
  Future<dynamic> editOrderSubmit({required Map<String, dynamic> data}) async => answer;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedOrderDetailsService implements OrderDetailsServiceInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingOrderDetailsController extends OrderDetailsController {
  _RecordingOrderDetailsController() : super(orderDetailsServiceInterface: _UnusedOrderDetailsService());

  final List<String> reloadedOrders = <String>[];

  @override
  Future<void> getOrderDetails(String orderID) async {
    reloadedOrders.add(orderID);
  }
}

class _PreloadedLocalizationDelegate extends LocalizationsDelegate<AppLocalization> {
  const _PreloadedLocalizationDelegate(this.localization);

  final AppLocalization localization;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalization> load(Locale locale) => SynchronousFuture<AppLocalization>(localization);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalization> old) => false;
}

ApiResponse _answered(Object? body) {
  return ApiResponse.withSuccess(Response<dynamic>(
    requestOptions: RequestOptions(path: '/api/v3/seller/orders/edit-order-submit'),
    statusCode: 200,
    data: body,
  ));
}

const Map<String, dynamic> _submission = <String, dynamic>{'order_id': '100123', 'products': '[]'};

void main() {
  late AppLocalization english;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    english = AppLocalization(const Locale('en'));
    await english.load();
  });

  Future<({OrderEditController controller, _RecordingOrderDetailsController orderDetails})> openApp(
    WidgetTester tester,
    ApiResponse answer,
  ) async {
    final _RecordingOrderDetailsController orderDetails = _RecordingOrderDetailsController();
    await tester.pumpWidget(
      ChangeNotifierProvider<OrderDetailsController>.value(
        value: orderDetails,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[_PreloadedLocalizationDelegate(english)],
          supportedLocales: const <Locale>[Locale('en')],
          home: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    final OrderEditController controller =
        OrderEditController(orderEditServiceInterface: _AnsweringOrderEditService(answer));
    return (controller: controller, orderDetails: orderDetails);
  }

  group('order edit submit flow', () {
    testWidgets('a refused edit shows the server message, reloads nothing and is not reported as saved',
        (WidgetTester tester) async {
      final app = await openApp(
        tester,
        _answered(<String, dynamic>{'status': 'error', 'message': 'Out of stock', 'request': _submission}),
      );

      final OrderEditSubmitResult result = await app.controller.editOrderSubmit(_submission);
      await tester.pump();

      expect(result.isSaved, isFalse);
      expect(find.text('Out of stock'), findsOneWidget);
      expect(app.orderDetails.reloadedOrders, isEmpty);
      expect(app.controller.isUpdateCartLoading, isFalse);
    });

    testWidgets('a refusal that carries no message still says something, in the active language',
        (WidgetTester tester) async {
      final app = await openApp(tester, _answered(<String, dynamic>{'status': 'error'}));

      final OrderEditSubmitResult result = await app.controller.editOrderSubmit(_submission);
      await tester.pump();

      final String generic = english.translate('something_went_wrong')!;
      expect(generic, isNot('something_went_wrong'), reason: 'the key must exist in the language file');
      expect(result.isSaved, isFalse);
      expect(find.text(generic), findsOneWidget);
      expect(app.orderDetails.reloadedOrders, isEmpty);
      expect(app.controller.isUpdateCartLoading, isFalse);
    });

    testWidgets('a saved edit reloads the order and shows no error', (WidgetTester tester) async {
      final app = await openApp(
        tester,
        _answered(<String, dynamic>{'status': 'success', 'message': 'Order edited successfully', 'request': _submission}),
      );

      final OrderEditSubmitResult result = await app.controller.editOrderSubmit(_submission);
      await tester.pump();

      expect(result.isSaved, isTrue);
      expect(app.orderDetails.reloadedOrders, <String>['100123']);
      expect(find.byType(SnackBar), findsNothing);
      expect(app.controller.isUpdateCartLoading, isFalse);
    });

    testWidgets('an edit that was not answered at all is reported by the usual error handling, not as saved',
        (WidgetTester tester) async {
      final app = await openApp(tester, ApiResponse.withError('no_internet_connection'));

      final OrderEditSubmitResult result = await app.controller.editOrderSubmit(_submission);
      await tester.pump();

      expect(result.isSaved, isFalse);
      expect(find.text(english.translate('no_internet_connection')!), findsOneWidget);
      expect(app.orderDetails.reloadedOrders, isEmpty);
      expect(app.controller.isUpdateCartLoading, isFalse);
    });
  });
}
