import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/offline_sales_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/pending_pos_order.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/pos_idempotency_key.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/repository/cart_repository.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/services/cart_service.dart';
import 'package:syriacosmeticsmanger/features/storefront/controllers/seller_market_controller.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/storefront_config.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

import 'support/market_support.dart';
import 'support/recording_adapter.dart';

const String _storageKey = 'offline_pos_orders';
const String _sellerA = 'seller-a';
const String _sellerB = 'seller-b';

/// What the outbox writes for a sale, and has always written: a build that names no market writes nothing more.
const List<String> _keysWrittenBeforeTheMarket = <String>['id', 'body', 'created_at', 'order_amount', 'customer_name', 'attempts', 'last_error', 'idempotency_key', 'seller_id'];

/// A server that records every request and answers a sale with an order number, or, when it is told to, with an error.
class _SalesServer extends RecordingAdapter {
  int status = 200;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    await super.fetch(options, requestStream, cancelFuture);

    return ResponseBody.fromString('{"order_id": 7}', status, headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    });
  }
}

/// The counter as the seller meets it: the real client of the app over a server that records what it is sent, the real cart service and repository, the real outbox over real preferences in memory, and the real
/// controller of the market. Who is signed in is said by [seller] and by the token of the client, which a test changes together.
class _Counter {
  _Counter._(this.preferences, this.server, this.client, this.market, this.outbox, this._signedIn);

  final SharedPreferences preferences;
  final _SalesServer server;
  final DioClient client;
  final SellerMarketController market;
  final OfflineSalesController outbox;
  final _Seller _signedIn;

  static Future<_Counter> open({
    Map<String, Object> stored = const <String, Object>{},
    List<PendingPosOrder> queue = const <PendingPosOrder>[],
    bool? storefrontsEnabled = true,
    String? seller = _sellerA,
  }) async {
    final SharedPreferences preferences = await preferencesWith(<String, Object>{
      AppConstants.token: 'token-of-a',
      _storageKey: queue.map((PendingPosOrder sale) => sale.encode()).toList(),
      ...stored,
    });
    final _SalesServer server = _SalesServer();
    final DioClient client = storefrontsEnabled == null ? _containerClient(preferences, server) : clientOn(preferences, server, storefrontsEnabled: storefrontsEnabled);
    final _Seller signedIn = _Seller(seller);
    final OfflineSalesController outbox = _outbox(preferences, client, signedIn, storefrontsEnabled: storefrontsEnabled);

    return _Counter._(preferences, server, client, controllerOn(preferences, enabled: storefrontsEnabled ?? StorefrontConfig.enabled), outbox, signedIn);
  }

  static DioClient _containerClient(SharedPreferences preferences, _SalesServer server) {
    final DioClient client = DioClient(AppConstants.baseUrl, Dio(), loggingInterceptor: LoggingInterceptor(), sharedPreferences: preferences);
    client.dio!.httpClientAdapter = server;

    return client;
  }

  /// The outbox as the container makes it when [storefrontsEnabled] is null, which is with nothing said of the market; and the same outbox after the app has started again.
  static OfflineSalesController _outbox(SharedPreferences preferences, DioClient client, _Seller signedIn, {required bool? storefrontsEnabled}) {
    final CartService service = CartService(cartRepositoryInterface: CartRepository(dioClient: client, sharedPreferences: preferences));

    return storefrontsEnabled == null
        ? (OfflineSalesController(cartServiceInterface: service, sharedPreferences: preferences, hasSession: () => true, signedInSellerId: () => signedIn.id)..loadFromStorage())
        : (OfflineSalesController(cartServiceInterface: service, sharedPreferences: preferences, hasSession: () => true, signedInSellerId: () => signedIn.id, storefrontsEnabled: storefrontsEnabled)..loadFromStorage());
  }

  /// The app started again on the same disk, with the same session.
  OfflineSalesController restarted({bool? storefrontsEnabled = true}) => _outbox(preferences, client, _signedIn, storefrontsEnabled: storefrontsEnabled);

  /// Another seller signs in, with a session of their own.
  void signIn(String seller, {required String token}) {
    _signedIn.id = seller;
    client.updateAuthToken(token);
  }

  /// A sale rung up while the connection was down.
  Future<PendingPosOrder> ringUp(String key) => outbox.enqueue(
        orderBody: <String, dynamic>{'user_id': 0, 'cart': <String>[key]},
        orderAmount: 25,
        customerName: 'Layla',
        idempotencyKey: key,
      );

  /// Every request that sent a sale, as it left the app.
  List<RecordedRequest> get salesSent => server.requests.where((RecordedRequest request) => request.uri.path.endsWith(AppConstants.placeOrderUri)).toList();

  List<Object?> get marketsSent => salesSent.map((RecordedRequest request) => request.header(AppConstants.storefrontHeader)).toList();

  List<Object?> get keysSent => salesSent.map((RecordedRequest request) => request.header(PosIdempotencyKey.header)).toList();

  List<Object?> get credentialsSent => salesSent.map((RecordedRequest request) => request.header('Authorization')).toList();

  /// What the disk holds, whoever is signed in.
  List<PendingPosOrder> get stored => (preferences.getStringList(_storageKey) ?? <String>[]).map(PendingPosOrder.decode).whereType<PendingPosOrder>().toList();

  List<String?> get storedKeys => stored.map((PendingPosOrder sale) => sale.idempotencyKey).toList();

  /// The entries as the disk holds them, before anything reads them.
  List<Map<String, dynamic>> get storedRecords => (preferences.getStringList(_storageKey) ?? <String>[]).map((String raw) => jsonDecode(raw) as Map<String, dynamic>).toList();
}

/// Whoever is signed in, whom a test changes at once.
class _Seller {
  _Seller(this.id);

  String? id;
}

PendingPosOrder _sale(String key, {String? seller = _sellerA, String? storefront}) => PendingPosOrder(
      id: key,
      body: <String, dynamic>{'user_id': 0, 'cart': <String>[key]},
      createdAt: DateTime(2026, 11, 19, 10),
      orderAmount: 25,
      customerName: 'Layla',
      idempotencyKey: key,
      sellerId: seller,
      storefront: storefront,
    );

/// A sale the way an earlier version wrote it: no market on it, and nothing else that this change added.
PendingPosOrder _saleWrittenBeforeTheMarket(String key, {String? seller = _sellerA}) => PendingPosOrder.fromJson(_sale(key, seller: seller).toJson()..remove('storefront'));

/// K-03.3 and K-06.2, the market half: a sale rung up offline is the only record of money taken at the counter in one market, and the request that replays it goes where the sale was taken, whatever
/// market the seller works in by then. Run on the real client of the app over a server that records what it is sent, with the real cart service, repository, outbox and controller of the market. The groups
/// that say whether storefronts are on say it to the client and to the outbox, so they run the same in every build; the last group makes both as the container makes them, and follows the build flag.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a sale queued while storefronts are on', () {
    test('is replayed in the market it was queued in, after the seller has switched to another, and the next request names the market of the seller again', () async {
      final _Counter counter = await _Counter.open();
      await counter.market.choose(MarketScope.saudiArabia);
      final PendingPosOrder queued = await counter.ringUp('sale-1');

      await counter.market.choose(MarketScope.kuwait);
      final int synced = await counter.outbox.syncPending();
      await counter.client.get('/api/v3/seller/orders');

      expect(queued.storefront, 'SA');
      expect(synced, 1);
      expect(counter.marketsSent, <Object?>['SA'], reason: 'the sale was taken in Saudi Arabia, and the seller works in Kuwait when it is sent');
      expect(counter.keysSent, <Object?>['sale-1']);
      expect(counter.credentialsSent, <Object?>['Bearer token-of-a']);
      expect(counter.server.last.header(AppConstants.storefrontHeader), 'KW', reason: 'the request that follows it is the seller\'s, and names the market the seller works in');
      expect(counter.outbox.pending, isEmpty);
      expect(counter.storedKeys, isEmpty);
    });

    test('is replayed in its own market whichever one the seller works in when it is sent, for every market', () async {
      for (final MarketScope taken in MarketScope.gccMarkets) {
        for (final MarketScope working in MarketScope.gccMarkets) {
          final _Counter counter = await _Counter.open();
          await counter.market.choose(taken);
          await counter.ringUp('sale-1');
          await counter.market.choose(working);

          await counter.outbox.syncPending();

          expect(counter.marketsSent, <Object?>[taken.countryCode], reason: 'taken in ${taken.countryCode}, sent from ${working.countryCode}');
        }
      }
    });

    test('keeps the market it was taken in when two sales are taken in two markets, and each goes to its own, in the order they were queued', () async {
      final _Counter counter = await _Counter.open();
      await counter.market.choose(MarketScope.saudiArabia);
      await counter.ringUp('sale-sa');
      await counter.market.choose(MarketScope.kuwait);
      await counter.ringUp('sale-kw');
      await counter.market.choose(MarketScope.unitedArabEmirates);

      final int synced = await counter.outbox.syncPending();

      expect(synced, 2);
      expect(counter.keysSent, <Object?>['sale-sa', 'sale-kw']);
      expect(counter.marketsSent, <Object?>['SA', 'KW']);
    });

    test('was taken in the default market when the seller had chosen none, and keeps it', () async {
      for (final Object? stored in <Object?>[null, 7, 'XX', 'ALL']) {
        final _Counter counter = await _Counter.open(stored: <String, Object>{if (stored != null) AppConstants.storefrontCountry: stored});
        final PendingPosOrder queued = await counter.ringUp('sale-1');
        await counter.market.choose(MarketScope.kuwait);

        await counter.outbox.syncPending();

        expect(queued.storefront, 'SA', reason: 'the request that failed named the default market: $stored');
        expect(counter.marketsSent, <Object?>['SA'], reason: '$stored');
      }
    });

    test('writes its market on the disk, and the app that starts again replays it there', () async {
      final _Counter counter = await _Counter.open();
      await counter.market.choose(MarketScope.bahrain);
      await counter.ringUp('sale-1');

      expect(counter.storedRecords.single['storefront'], 'BH');
      expect(counter.stored.single.storefront, 'BH');

      await counter.market.choose(MarketScope.oman);
      final OfflineSalesController started = counter.restarted();

      expect(started.pending.single.storefront, 'BH');
      expect(await started.syncPending(), 1);
      expect(counter.marketsSent, <Object?>['BH']);
    });

    test('is written with one key more than it had before the market was kept, and that key is the market', () async {
      final _Counter counter = await _Counter.open();

      await counter.ringUp('sale-1');

      expect(counter.storedRecords.single.keys, unorderedEquals(<String>[..._keysWrittenBeforeTheMarket, 'storefront']));
      expect(counter.storedRecords.single['storefront'], 'SA', reason: 'the default market, as no other was chosen');
    });

    test('keeps its market through a replay that failed, and goes to it when the replay that follows is sent from another market', () async {
      final _Counter counter = await _Counter.open();
      await counter.market.choose(MarketScope.qatar);
      await counter.ringUp('sale-1');
      counter.server.status = 500;
      await counter.outbox.syncPending();
      expect(counter.outbox.pending.single.attempts, 1);
      expect(counter.stored.single.storefront, 'QA', reason: 'a failed attempt is written on the sale, and its market with it');

      counter.server.status = 200;
      await counter.market.choose(MarketScope.kuwait);
      final int synced = await counter.outbox.syncPending();

      expect(synced, 1);
      expect(counter.marketsSent, <Object?>['QA', 'QA']);
      expect(counter.keysSent, <Object?>['sale-1', 'sale-1']);
    });
  });

  group('a sale queued before the market was kept', () {
    test('has none, and is replayed under the market the seller works in when it is sent, as every sale was before', () async {
      final _Counter counter = await _Counter.open(queue: <PendingPosOrder>[_saleWrittenBeforeTheMarket('old')], stored: <String, Object>{AppConstants.storefrontCountry: 'KW'});
      expect(counter.outbox.pending.single.storefront, isNull);
      expect(counter.storedRecords.single.containsKey('storefront'), isFalse);
      await counter.market.choose(MarketScope.unitedArabEmirates);

      final int synced = await counter.outbox.syncPending();

      expect(synced, 1);
      expect(counter.marketsSent, <Object?>['AE'], reason: 'the request names no storefront of its own, and the client names the one the seller works in');
      expect(counter.keysSent, <Object?>['old']);
    });

    test('is queued by a build with storefronts off, and a build with storefronts on that reads it makes up no market for it: it is replayed under the market the seller works in when it is sent', () async {
      final _Counter off = await _Counter.open(storefrontsEnabled: false);
      await off.ringUp('sale-1');
      final _Counter on = await _Counter.open(queue: off.stored, stored: <String, Object>{AppConstants.storefrontCountry: 'SA'});
      await on.market.choose(MarketScope.oman);

      expect(on.outbox.pending.single.storefront, isNull);
      expect(await on.outbox.syncPending(), 1);

      expect(on.marketsSent, <Object?>['OM']);
    });
  });

  group('a sale of a seller', () {
    test('replays only under that seller and that market: another seller\'s session does not send it, and the seller\'s own session sends it in the market it was taken in', () async {
      final _Counter counter = await _Counter.open(queue: <PendingPosOrder>[_sale('a-1', storefront: 'SA')], stored: <String, Object>{AppConstants.storefrontCountry: 'SA'});
      counter.signIn(_sellerB, token: 'token-of-b');
      await counter.market.choose(MarketScope.kuwait);

      final int syncedUnderB = await counter.outbox.syncPending();

      expect(syncedUnderB, 0);
      expect(counter.salesSent, isEmpty, reason: 'sent now, the server would record the money A took under B');
      expect(counter.storedKeys, <String?>['a-1']);
      expect(counter.stored.single.storefront, 'SA');

      counter.signIn(_sellerA, token: 'token-of-a-again');
      final int syncedUnderA = await counter.outbox.syncPending();

      expect(syncedUnderA, 1);
      expect(counter.keysSent, <Object?>['a-1']);
      expect(counter.credentialsSent, <Object?>['Bearer token-of-a-again'], reason: 'under the session of the seller who took it');
      expect(counter.marketsSent, <Object?>['SA'], reason: 'in the market it was taken in, while the seller works in Kuwait');
      expect(counter.storedKeys, isEmpty);
    });

    test('two sellers who took sales in two markets each send their own, in their own market, whoever signs in first and whatever market is chosen', () async {
      final _Counter counter = await _Counter.open(
        queue: <PendingPosOrder>[_sale('a-sa', storefront: 'SA'), _sale('b-kw', seller: _sellerB, storefront: 'KW'), _sale('a-ae', storefront: 'AE')],
        stored: <String, Object>{AppConstants.storefrontCountry: 'QA'},
      );
      counter.signIn(_sellerB, token: 'token-of-b');

      expect(await counter.outbox.syncPending(), 1);
      expect(counter.keysSent, <Object?>['b-kw']);
      expect(counter.marketsSent, <Object?>['KW']);
      expect(counter.credentialsSent, <Object?>['Bearer token-of-b']);

      counter.signIn(_sellerA, token: 'token-of-a-again');
      await counter.market.choose(MarketScope.bahrain);

      expect(await counter.outbox.syncPending(), 2);
      expect(counter.keysSent, <Object?>['b-kw', 'a-sa', 'a-ae']);
      expect(counter.marketsSent, <Object?>['KW', 'SA', 'AE']);
      expect(counter.credentialsSent, <Object?>['Bearer token-of-b', 'Bearer token-of-a-again', 'Bearer token-of-a-again']);
      expect(counter.storedKeys, isEmpty);
    });
  });

  group('while storefronts are off', () {
    test('a sale is written exactly as it always was, with no market on it, and is sent with no storefront, whatever market is stored', () async {
      final _Counter counter = await _Counter.open(storefrontsEnabled: false, stored: <String, Object>{AppConstants.storefrontCountry: 'KW'});

      final PendingPosOrder queued = await counter.ringUp('sale-1');
      await counter.outbox.syncPending();

      expect(queued.storefront, isNull);
      expect(counter.marketsSent, <Object?>[null]);
      expect(counter.salesSent.single.headers.containsKey(AppConstants.storefrontHeader.toLowerCase()), isFalse);
    });

    test('the entry has the keys it always had, and none more', () async {
      final _Counter counter = await _Counter.open(storefrontsEnabled: false, stored: <String, Object>{AppConstants.storefrontCountry: 'KW'});

      await counter.ringUp('sale-1');

      expect(counter.storedRecords.single.keys, unorderedEquals(_keysWrittenBeforeTheMarket));
    });

    test('an entry that names a market, written by a build that had storefronts on, keeps it: the market a sale was taken in is a fact of the sale', () async {
      final _Counter counter = await _Counter.open(storefrontsEnabled: false, queue: <PendingPosOrder>[_sale('a-1', storefront: 'KW')]);

      await counter.outbox.syncPending();

      expect(counter.marketsSent, <Object?>['KW']);
    });
  });

  group('a client and an outbox made as the container makes them, which is with nothing said of the market', () {
    test('follow the build flag together: a sale keeps the market it was taken in when storefronts are on, and has none when they are off', () async {
      final _Counter counter = await _Counter.open(storefrontsEnabled: null, stored: <String, Object>{AppConstants.storefrontCountry: 'AE'});

      final PendingPosOrder queued = await counter.ringUp('sale-1');
      await counter.preferences.setString(AppConstants.storefrontCountry, 'KW');
      final int synced = await counter.outbox.syncPending();

      expect(synced, 1);
      expect(queued.storefront, StorefrontConfig.enabled ? 'AE' : isNull);
      expect(counter.marketsSent, <Object?>[StorefrontConfig.enabled ? 'AE' : null], reason: 'taken in the United Arab Emirates, sent from Kuwait when storefronts are on, and no storefront named when they are off');
    });

    test('write the entry with the market when storefronts are on, and exactly as it always was when they are off', () async {
      final _Counter counter = await _Counter.open(storefrontsEnabled: null, stored: <String, Object>{AppConstants.storefrontCountry: 'AE'});

      await counter.ringUp('sale-1');

      expect(counter.storedRecords.single.keys, unorderedEquals(<String>[..._keysWrittenBeforeTheMarket, if (StorefrontConfig.enabled) 'storefront']));
    });
  });
}
