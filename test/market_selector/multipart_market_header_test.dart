import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/features/addProduct/domain/models/image_model.dart';
import 'package:syriacosmeticsmanger/features/addProduct/domain/repository/add_product_repository.dart';
import 'package:syriacosmeticsmanger/features/auth/controllers/auth_controller.dart';
import 'package:syriacosmeticsmanger/features/auth/domain/models/register_model.dart';
import 'package:syriacosmeticsmanger/features/auth/domain/repositories/auth_repository.dart';
import 'package:syriacosmeticsmanger/features/auth/domain/services/auth_service_interface.dart';
import 'package:syriacosmeticsmanger/features/bank_info/domain/repositories/bank_info_repository.dart';
import 'package:syriacosmeticsmanger/features/chat/domain/models/message_body.dart';
import 'package:syriacosmeticsmanger/features/chat/domain/repositories/chat_repository.dart';
import 'package:syriacosmeticsmanger/features/delivery_man/domain/model/delivery_man_body.dart';
import 'package:syriacosmeticsmanger/features/delivery_man/domain/repositories/delivery_man_repository.dart';
import 'package:syriacosmeticsmanger/features/order_details/domain/repositories/order_details_repository.dart';
import 'package:syriacosmeticsmanger/features/profile/domain/models/profile_body.dart';
import 'package:syriacosmeticsmanger/features/profile/domain/models/profile_info.dart';
import 'package:syriacosmeticsmanger/features/profile/domain/repositories/profile_repository.dart';
import 'package:syriacosmeticsmanger/features/shop/domain/models/shop_model.dart';
import 'package:syriacosmeticsmanger/features/shop/domain/repositories/shop_repository.dart';
import 'package:syriacosmeticsmanger/features/storefront/controllers/seller_market_controller.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

import 'support/market_support.dart';
import 'support/recording_adapter.dart';

const String _token = 'dummy-session-token-for-the-tests';

class _NoAuthService extends Fake implements AuthServiceInterface {}

/// The session of the seller, as the sites that read their credential from the provider find it.
class _SignedInAuthController extends AuthController {
  _SignedInAuthController() : super(authServiceInterface: _NoAuthService());

  @override
  String getUserToken() => _token;
}

typedef _Call = Future<Object?> Function(DioClient client, SharedPreferences preferences);

/// One of the sites that build an upload of their own, with what it sent before the market was named: the credential of the seller,
/// unless it is the one that is sent before anyone has signed in.
class _Site {
  const _Site(this.name, this.call, {this.signedIn = true});

  final String name;
  final _Call call;
  final bool signedIn;

  /// What the site sent as the credential before the market was named.
  String? get authorization => signedIn ? 'Bearer $_token' : null;

  /// The names of the headers the site sent before the market was named: the type of the body, and the credential when it has one.
  Set<String> get namesBefore => <String>{'content-type', if (signedIn) 'authorization'};
}

Set<String> _namesOf(http.BaseRequest request) => request.headers.keys.map((String name) => name.toLowerCase()).toSet();

final List<_Site> _sites = <_Site>[
  _Site(
    'the bank details',
    (DioClient client, SharedPreferences preferences) => BankInfoRepository(dioClient: client, sharedPreferences: preferences).updateBank(
      ProfileInfoModel(bankName: 'Bank', branch: 'Branch', holderName: 'Holder', accountNo: '1', phone: '500000000'),
      ProfileBody(fName: 'First', lName: 'Last'),
      _token,
    ),
  ),
  _Site(
    'the registration',
    (DioClient client, SharedPreferences preferences) => AuthRepository(dioClient: client, sharedPreferences: preferences).registration(
      null,
      null,
      null,
      null,
      RegisterModel(
        fName: 'First',
        lName: 'Last',
        phone: '500000000',
        email: 'seller@example.invalid',
        password: 'dummy-password-for-the-tests',
        confirmPassword: 'dummy-password-for-the-tests',
        shopName: 'Shop',
        shopAddress: 'Street',
        businessTin: '1',
      ),
      null,
    ),
    signedIn: false,
  ),
  _Site(
    'the profile',
    (DioClient client, SharedPreferences preferences) => ProfileRepository(dioClient: client, sharedPreferences: preferences).updateProfile(
      ProfileInfoModel(fName: 'First', lName: 'Last', phone: '500000000'),
      ProfileBody(),
      null,
      _token,
      '',
    ),
  ),
  _Site(
    'the delivery man',
    (DioClient client, SharedPreferences preferences) => DeliveryManRepository(dioClient: client).addNewDeliveryMan(
      null,
      <XFile?>[],
      DeliveryManBody(
        fName: 'First',
        lName: 'Last',
        address: 'Street',
        phone: '500000000',
        email: 'driver@example.invalid',
        countryCode: '+966',
        identityNumber: '1',
        identityType: 'passport',
        password: 'dummy-password-for-the-tests',
        confirmPassword: 'dummy-password-for-the-tests',
      ),
      _token,
    ),
  ),
  _Site(
    'the chat message',
    (DioClient client, SharedPreferences preferences) => ChatRepository(dioClient: client).sendMessage(
      MessageBody(sellerId: 1, message: 'Hello'),
      'customer',
      <XFile?>[],
      null,
    ),
  ),
  _Site(
    'the file after a sale',
    (DioClient client, SharedPreferences preferences) =>
        OrderDetailsRepository(dioClient: client).uploadAfterSellDigitalProduct(null, _token, '100'),
  ),
  _Site(
    'the shop',
    (DioClient client, SharedPreferences preferences) => ShopRepository(dioClient: client, sharedPreferences: preferences).updateShop(
      ShopModel(name: 'Shop', address: 'Street', contact: '500000000'),
      null,
      null,
      null,
      null,
    ),
  ),
  _Site(
    'the product image',
    (DioClient client, SharedPreferences preferences) => AddProductRepository(dioClient: client).addImage(
      Get.context!,
      ImageModel(type: 'main', color: '', image: XFile('product.png')),
      false,
    ),
  ),
  _Site(
    'the digital product file',
    (DioClient client, SharedPreferences preferences) => AddProductRepository(dioClient: client).uploadDigitalProduct(null, _token),
  ),
];

/// Mounts the app around the sites that find the seller's credential and their way to a screen through the provider and the
/// navigator.
Future<void> _mountApp(WidgetTester tester) {
  return tester.pumpWidget(
    ChangeNotifierProvider<AuthController>(
      create: (_) => _SignedInAuthController(),
      child: MaterialApp(navigatorKey: navigatorKey, home: const SizedBox.shrink()),
    ),
  );
}

/// Runs [call] with package:http answering for itself, and returns the one request it sent.
Future<http.BaseRequest> _requestSentBy(WidgetTester tester, Future<Object?> Function() call) async {
  final List<http.BaseRequest> sent = <http.BaseRequest>[];
  await tester.runAsync(
    () => http.runWithClient(
      call,
      () => MockClient((http.Request request) async {
        sent.add(request);
        return http.Response('{}', 200);
      }),
    ),
  );
  expect(sent, hasLength(1));
  return sent.single;
}

/// Every upload the app makes with package:http builds its own headers, because that package never meets the interceptors of the
/// client. So each of them takes its headers from the client, which is what keeps the market it names the market of every other request.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the headers the client makes for an upload', () {
    test('are the credential and the storefront of the market the seller works in', () async {
      final SharedPreferences preferences = await preferencesWith(<String, Object>{AppConstants.storefrontCountry: 'KW'});
      final DioClient client = clientOn(preferences, RecordingAdapter());

      expect(client.multipartHeaders(token: _token), <String, String>{
        'Authorization': 'Bearer $_token',
        AppConstants.storefrontHeader: 'KW',
      });
    });

    test('are the storefront alone for an upload made before anyone has signed in', () async {
      final DioClient client = clientOn(await preferencesWith(), RecordingAdapter());

      expect(client.multipartHeaders(), <String, String>{AppConstants.storefrontHeader: 'SA'});
    });

    test('name for each of the six markets the market a request of the same client names, from the moment it is chosen', () async {
      final SharedPreferences preferences = await preferencesWith();
      final RecordingAdapter adapter = RecordingAdapter();
      final DioClient client = clientOn(preferences, adapter);
      final SellerMarketController controller = controllerOn(preferences);

      for (final MarketScope scope in MarketScope.gccMarkets) {
        await controller.choose(scope);
        await client.get('/api/v3/seller/orders');

        expect(client.multipartHeaders(token: _token)[AppConstants.storefrontHeader], scope.countryCode);
        expect(adapter.last.header(AppConstants.storefrontHeader), scope.countryCode);
      }
    });

    test('are exactly the credential while storefronts are off, and nothing at all without one', () async {
      final SharedPreferences preferences = await preferencesWith(<String, Object>{AppConstants.storefrontCountry: 'AE'});
      final DioClient client = clientOn(preferences, RecordingAdapter(), storefrontsEnabled: false);

      expect(client.multipartHeaders(token: _token), <String, String>{'Authorization': 'Bearer $_token'});
      expect(client.multipartHeaders(), isEmpty);
    });
  });

  group('while storefronts are on, every upload', () {
    for (final _Site site in _sites) {
      testWidgets('of ${site.name} names the market of the seller and still sends what it sent before', (WidgetTester tester) async {
        await _mountApp(tester);
        final SharedPreferences preferences = await preferencesWith(<String, Object>{AppConstants.storefrontCountry: 'AE'});
        final DioClient client = clientOn(preferences, RecordingAdapter());

        final http.BaseRequest request = await _requestSentBy(tester, () => site.call(client, preferences));

        expect(request.headers[AppConstants.storefrontHeader], 'AE');
        expect(request.headers['Authorization'], site.authorization);
        expect(request.headers[HttpHeaders.contentTypeHeader], startsWith('multipart/form-data'));
        expect(_namesOf(request), <String>{...site.namesBefore, 'x-storefront'});
      });
    }

    testWidgets('names the market the seller has just moved to', (WidgetTester tester) async {
      await _mountApp(tester);
      final SharedPreferences preferences = await preferencesWith();
      final DioClient client = clientOn(preferences, RecordingAdapter());
      final SellerMarketController controller = controllerOn(preferences);

      final http.BaseRequest before = await _requestSentBy(tester, () => _sites.first.call(client, preferences));
      await tester.runAsync(() => controller.choose(MarketScope.oman));
      final http.BaseRequest after = await _requestSentBy(tester, () => _sites.first.call(client, preferences));

      expect(before.headers[AppConstants.storefrontHeader], 'SA');
      expect(after.headers[AppConstants.storefrontHeader], 'OM');
    });
  });

  group('while storefronts are off, every upload', () {
    for (final _Site site in _sites) {
      testWidgets('of ${site.name} sends what it always sent, and no storefront', (WidgetTester tester) async {
        await _mountApp(tester);
        final SharedPreferences preferences = await preferencesWith(<String, Object>{AppConstants.storefrontCountry: 'AE'});
        final DioClient client = clientOn(preferences, RecordingAdapter(), storefrontsEnabled: false);

        final http.BaseRequest request = await _requestSentBy(tester, () => site.call(client, preferences));

        expect(request.headers.containsKey(AppConstants.storefrontHeader), isFalse);
        expect(request.headers['Authorization'], site.authorization);
        expect(request.headers[HttpHeaders.contentTypeHeader], startsWith('multipart/form-data'));
        expect(_namesOf(request), site.namesBefore);
      });
    }
  });
}
