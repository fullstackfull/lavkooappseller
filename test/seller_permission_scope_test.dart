import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:syriacosmeticsmanger/features/security/controllers/seller_permission_controller.dart';
import 'package:syriacosmeticsmanger/features/security/domain/models/seller_permission_scope.dart';
import 'package:syriacosmeticsmanger/features/security/domain/seller_permission_source.dart';
import 'package:syriacosmeticsmanger/features/security/seller_permission_config.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

/// What the signed-in role may use, as `GET api/v3/seller/seller-center/security/me` answers it (K-08).
///
/// The rule is read here on its own, without a screen and without a network, because what it decides is which entries a staff
/// member is shown. It decides nothing about what they can REACH: the server gates all 53 of its `seller_can` declarations for
/// every caller, and a staff member who knows the URL gets the same 403 as one who was shown no button. That is why every
/// unreadable answer below leaves the app showing everything rather than nothing.
class _AnsweringAdapter implements HttpClientAdapter {
  _AnsweringAdapter({required this.body, this.statusCode = 200});

  final String body;
  final int statusCode;
  final List<Uri> asked = <Uri>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    asked.add(options.uri);

    return ResponseBody.fromString(body, statusCode, headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

DioClient _clientAnswering(SharedPreferences preferences, _AnsweringAdapter adapter) {
  final DioClient client = DioClient(
    AppConstants.baseUrl,
    Dio(),
    loggingInterceptor: LoggingInterceptor(),
    sharedPreferences: preferences,
  );
  client.dio!.httpClientAdapter = adapter;
  return client;
}

Future<SharedPreferences> _preferences() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return SharedPreferences.getInstance();
}

/// The entries of the "more" screen that are open to whoever holds a credential of the shop, because the routes behind them
/// carry no `seller_can` and no `seller_owner`.
const List<SellerScreen> _openToEveryone = <SellerScreen>[
  SellerScreen.profile,
  SellerScreen.settings,
  SellerScreen.vatManagement,
];

SellerPermissionScope _scopeOf(String principalType, List<String> permissions, {String? role}) =>
    SellerPermissionScope.fromPrincipal(<String, dynamic>{
      'principal_type': principalType,
      'seller_id': 1,
      'staff_id': principalType == 'staff' ? 7 : null,
      'role': role,
      'permissions': permissions,
      'market_scope': 'unrestricted',
      'allowed_markets': null,
      'storefronts_enabled': false,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The catalogue of the backend, in the order `SellerPermissionService::catalog()` lists it. The server answers the keys in
  /// this order, and a key the app spells differently is a key it would read as unknown and so as not held.
  const List<String> catalogue = <String>[
    'products.view',
    'products.manage',
    'orders.view',
    'orders.manage',
    'inventory.manage',
    'promotions.manage',
    'finance.view',
    'payouts.request',
    'reviews.view',
    'shop_settings.manage',
    'staff.manage',
  ];

  group('the permission keys', () {
    test('are the eleven of the catalogue, spelled and ordered as the server spells and orders them', () {
      expect(SellerPermission.values.map((SellerPermission p) => p.key).toList(), catalogue);
    });

    test('a key the app has never heard of parses as nothing, and is not read as every key', () {
      expect(SellerPermission.parse('something.new'), isNull);
      expect(SellerPermission.parse(null), isNull);
      expect(SellerPermission.parse(7), isNull);
      expect(SellerPermission.parse('products.view'), SellerPermission.productsView);
    });
  });

  group('the scope as the server answers it', () {
    test('the owner holds every permission, every entry and every owner-only entry', () {
      final SellerPermissionScope scope = _scopeOf('owner', catalogue);

      expect(scope.isOwner, isTrue);
      expect(scope.isStaff, isFalse);
      expect(scope.role, isNull);
      for (final SellerPermission permission in SellerPermission.values) {
        expect(scope.holds(permission), isTrue, reason: permission.key);
      }
      for (final SellerScreen screen in SellerScreen.values) {
        expect(scope.allows(screen), isTrue, reason: screen.name);
      }
    });

    test('a staff member is shown the entries their two keys open, and no others', () {
      final SellerPermissionScope scope = _scopeOf('staff', <String>['products.view', 'orders.view'], role: 'Order clerk');

      expect(scope.isStaff, isTrue);
      expect(scope.isOwner, isFalse);
      expect(scope.role, 'Order clerk');

      expect(scope.allows(SellerScreen.products), isTrue, reason: 'products.view');
      expect(scope.allows(SellerScreen.restock), isTrue, reason: 'products.view');
      expect(scope.allows(SellerScreen.returns), isTrue, reason: 'orders.view');
      expect(scope.allows(SellerScreen.controlTower), isTrue, reason: 'orders.view');
      expect(scope.allows(SellerScreen.inbox), isTrue, reason: 'orders.view');
      expect(scope.allows(SellerScreen.orderReport), isTrue, reason: 'orders.view');
      expect(scope.allows(SellerScreen.productReport), isTrue, reason: 'products.view');
      expect(scope.allows(SellerScreen.analytics), isTrue, reason: 'orders.view');
      expect(scope.allows(SellerScreen.inventory), isTrue, reason: 'products.view, which the stock list also accepts');

      expect(scope.allows(SellerScreen.addProduct), isFalse, reason: 'products.manage only');
      expect(scope.allows(SellerScreen.pointOfSale), isFalse, reason: 'orders.manage only');
      expect(scope.allows(SellerScreen.refund), isFalse, reason: 'orders.manage only');
      expect(scope.allows(SellerScreen.deliveryMan), isFalse, reason: 'orders.manage only');
      expect(scope.allows(SellerScreen.coupons), isFalse, reason: 'promotions.manage only');
      expect(scope.allows(SellerScreen.clearanceSale), isFalse, reason: 'promotions.manage only');
      expect(scope.allows(SellerScreen.reviews), isFalse, reason: 'reviews.view only');
      expect(scope.allows(SellerScreen.wallet), isFalse, reason: 'finance.view only');
      expect(scope.allows(SellerScreen.statement), isFalse, reason: 'finance.view only');
      expect(scope.allows(SellerScreen.payouts), isFalse, reason: 'finance.view only');
      expect(scope.allows(SellerScreen.bankInformation), isFalse, reason: 'finance.view only');
      expect(scope.allows(SellerScreen.myShop), isFalse, reason: 'shop_settings.manage only');
      expect(scope.allows(SellerScreen.securityCentre), isFalse, reason: 'staff.manage only');
      expect(scope.allows(SellerScreen.verification), isFalse, reason: 'the owner\'s own, and no role is given it');
    });

    test('the security centre is shown to the one permission that can grant every other, and to nobody else', () {
      expect(_scopeOf('staff', <String>['staff.manage'], role: 'Manager').allows(SellerScreen.securityCentre), isTrue);
      expect(_scopeOf('staff', catalogue.where((String key) => key != 'staff.manage').toList())
          .allows(SellerScreen.securityCentre), isFalse);
      expect(_scopeOf('owner', catalogue).allows(SellerScreen.securityCentre), isTrue);
    });

    test('the shop\'s standing with the marketplace is the owner\'s, and no role is given it', () {
      expect(_scopeOf('staff', catalogue, role: 'Everything').allows(SellerScreen.verification), isFalse);
      expect(_scopeOf('owner', catalogue).allows(SellerScreen.verification), isTrue);
    });

    test('a role that grants nothing is shown only the entries that need no permission', () {
      final SellerPermissionScope scope = _scopeOf('staff', <String>[], role: 'Observer');

      expect(scope.permissions, isEmpty, reason: 'an empty list IS an answer, and is never read as no limit');
      for (final SellerScreen screen in SellerScreen.values) {
        expect(scope.allows(screen), _openToEveryone.contains(screen), reason: screen.name);
      }
    });

    test('a key the app has never heard of is dropped, and is not a key the role lacks', () {
      final SellerPermissionScope scope = _scopeOf('staff', <String>['products.view', 'orders.export', 'PRODUCTS.MANAGE']);

      expect(scope.permissions, <SellerPermission>{SellerPermission.productsView});
      expect(scope.allows(SellerScreen.addProduct), isFalse, reason: 'products.manage was never granted in a spelling the server uses');
    });
  });

  group('an answer the app could not read', () {
    test('no answer at all hides nothing, because the server refuses what the role may not reach anyway', () {
      const SellerPermissionScope scope = SellerPermissionScope.unrestricted();

      expect(scope.read, isFalse);
      expect(scope.permissions, isNull);
      for (final SellerScreen screen in SellerScreen.values) {
        expect(scope.allows(screen), isTrue, reason: screen.name);
      }
    });

    test('a null body, an empty answer and a permissions member that is no list all hide nothing', () {
      for (final Map<String, dynamic>? body in <Map<String, dynamic>?>[
        null,
        <String, dynamic>{},
        <String, dynamic>{'permissions': 'orders.view'},
        <String, dynamic>{'permissions': 7},
      ]) {
        final SellerPermissionScope scope = SellerPermissionScope.fromPrincipal(body);

        expect(scope.permissions, isNull, reason: '$body');
        expect(scope.allows(SellerScreen.securityCentre), isTrue, reason: '$body');
        expect(scope.allows(SellerScreen.verification), isTrue, reason: '$body');
      }
    });

    test('a staff member whose permissions could not be read is still not shown the owner\'s own entries', () {
      final SellerPermissionScope scope = SellerPermissionScope.fromPrincipal(<String, dynamic>{
        'principal_type': 'staff',
        'permissions': null,
      });

      expect(scope.isStaff, isTrue);
      expect(scope.permissions, isNull);
      expect(scope.allows(SellerScreen.verification), isFalse, reason: 'principal_type alone settles an owner-only entry');
      expect(scope.allows(SellerScreen.securityCentre), isTrue, reason: 'and nothing else is narrowed on an answer that was not read');
    });

    test('a principal type the app has never heard of is neither owner nor staff, and shows the app as it was', () {
      final SellerPermissionScope scope = SellerPermissionScope.fromPrincipal(<String, dynamic>{
        'principal_type': 'api_key',
        'permissions': <dynamic>['orders.view'],
      });

      expect(scope.isOwner, isFalse);
      expect(scope.isStaff, isFalse);
      expect(scope.allows(SellerScreen.verification), isTrue, reason: 'nothing says this caller is not the owner');
      expect(scope.allows(SellerScreen.statement), isFalse, reason: 'but the keys that were read are still the keys that were read');
    });
  });

  group('the scope is asked of the server', () {
    test('a build whose role screens are off asks nothing, and hides nothing', () async {
      final _AnsweringAdapter adapter = _AnsweringAdapter(body: '{"principal_type":"staff","permissions":[]}');
      final SellerPermissionController controller = SellerPermissionController(
        source: SellerPermissionSource(_clientAnswering(await _preferences(), adapter)),
        enabled: false,
      );

      await controller.refresh();

      expect(adapter.asked, isEmpty);
      expect(controller.scope.read, isFalse);
      expect(controller.scope.allows(SellerScreen.securityCentre), isTrue);
    });

    test('a build with the role screens on asks the who-am-I route and takes the answer', () async {
      final _AnsweringAdapter adapter = _AnsweringAdapter(
        body: '{"principal_type":"staff","role":"Warehouse","permissions":["inventory.manage","orders.view"]}',
      );
      final SellerPermissionController controller = SellerPermissionController(
        source: SellerPermissionSource(_clientAnswering(await _preferences(), adapter)),
        enabled: true,
      );
      int notifications = 0;
      controller.addListener(() => notifications++);

      await controller.refresh();

      expect(adapter.asked.single.path, AppConstants.sellerPrincipalUri);
      expect(controller.scope.role, 'Warehouse');
      expect(controller.scope.allows(SellerScreen.inventory), isTrue);
      expect(controller.scope.allows(SellerScreen.securityCentre), isFalse);
      expect(notifications, 1, reason: 'the screens are told once the answer is in');
    });

    test('a server that does not know the route leaves the app as it always was', () async {
      final _AnsweringAdapter adapter = _AnsweringAdapter(statusCode: 404, body: '{"message":"not found"}');
      final SellerPermissionController controller = SellerPermissionController(
        source: SellerPermissionSource(_clientAnswering(await _preferences(), adapter)),
        enabled: true,
      );

      await controller.refresh();

      expect(adapter.asked, isNotEmpty);
      expect(controller.scope.read, isFalse);
      for (final SellerScreen screen in SellerScreen.values) {
        expect(controller.scope.allows(screen), isTrue, reason: screen.name);
      }
    });

    test('a controller made the way the container makes it follows the build flag, and states nothing itself', () async {
      final _AnsweringAdapter adapter = _AnsweringAdapter(body: '{"principal_type":"staff","permissions":[]}');
      final SellerPermissionController controller = SellerPermissionController(
        source: SellerPermissionSource(_clientAnswering(await _preferences(), adapter)),
      );

      await controller.refresh();

      expect(adapter.asked.isEmpty, !SellerPermissionConfig.enabled,
          reason: 'the build with the role screens on asks; the build without them does not');
      expect(controller.scope.read, SellerPermissionConfig.enabled);
    });

    test('a container with no client asks nothing and hides nothing', () async {
      final SellerPermissionController controller = SellerPermissionController(enabled: true);

      await controller.refresh();

      expect(controller.scope.read, isFalse);
    });

    test('what the role that signed out may use goes with the sign-out', () async {
      final SellerPermissionController controller = SellerPermissionController(enabled: true);
      controller.apply(_scopeOf('staff', <String>[], role: 'Observer'));

      expect(controller.scope.allows(SellerScreen.statement), isFalse);

      controller.apply(const SellerPermissionScope.unrestricted());

      expect(controller.scope.read, isFalse);
      expect(controller.scope.allows(SellerScreen.statement), isTrue);
    });
  });

  group('by reading the source', () {
    test('the sign-out hands the scope back, so the next seller on the phone is not shown the last role\'s screens', () {
      final String signOut = File('lib/features/auth/controllers/auth_controller.dart').readAsStringSync();

      expect(signOut, contains('GetIt.instance<SellerPermissionController>().apply(const SellerPermissionScope.unrestricted());'));
    });

    test('Home re-reads the scope with the rest of it, so a permission taken away reaches the screens on the next load', () {
      final String home = File('lib/features/home/screens/home_page_screen.dart').readAsStringSync();

      expect(home, contains('sl<SellerPermissionController>().refresh();'));
    });

    test('no file of the app states whether the role screens are on: the flag is the controller\'s own default', () {
      final List<String> stated = <String>[
        for (final FileSystemEntity entity in Directory('lib').listSync(recursive: true))
          if (entity is File && entity.path.endsWith('.dart'))
            if (RegExp(r'SellerPermissionController\([^)]*enabled:').hasMatch(entity.readAsStringSync())) entity.path,
      ];

      expect(stated, isEmpty);
    });

    test('the container registers one scope for the whole app, so the screen and Home read the same one', () {
      final String container = File('lib/di_container.dart').readAsStringSync();

      expect(container, contains('sl.registerLazySingleton(() => SellerPermissionController(source: SellerPermissionSource(sl())));'));
      expect(container, isNot(contains('registerFactory(() => SellerPermissionController')));
    });

    test('every entry of the more screen that can be hidden is hidden through the scope, and none of them any other way', () {
      final String source = File('lib/features/menu/screens/more_screen.dart').readAsStringSync();
      final Set<String> gated = RegExp(r'SellerScreen\.([A-Za-z]+)')
          .allMatches(source)
          .map((RegExpMatch match) => match.group(1)!)
          .toSet();
      final Set<String> hideable = SellerScreen.values
          .where((SellerScreen entry) => entry.permissions.isNotEmpty || entry.ownerOnly)
          .map((SellerScreen entry) => entry.name)
          .toSet();

      expect(gated, hideable);
    });
  });
}
