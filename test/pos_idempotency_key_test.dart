import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/pending_pos_order.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/place_order_body.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/pos_idempotency_key.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/repository/cart_repository.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

/// Answers every request with an order number and keeps what it was asked.
class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);

    return ResponseBody.fromString('{"order_id": 7}', 200, headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Future<({CartRepository repository, _RecordingAdapter adapter})> _repository() async {
  SharedPreferences.setMockInitialValues(<String, Object>{AppConstants.token: 'a-real-looking-session-token-value'});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final Dio dio = Dio();
  final _RecordingAdapter adapter = _RecordingAdapter();
  dio.httpClientAdapter = adapter;
  final DioClient client = DioClient(AppConstants.baseUrl, dio, loggingInterceptor: LoggingInterceptor(), sharedPreferences: preferences);

  return (repository: CartRepository(dioClient: client, sharedPreferences: preferences), adapter: adapter);
}

PlaceOrderBody _sale() => PlaceOrderBody(cart: <dynamic>[].cast(), orderAmount: 1500, userId: 0, paymentMethod: 'cash');

/// K-06: a sale is sent with one key and replayed from the outbox under the same one. The server answers a second submission of a key with the first order and debits the wallet once; an earlier
/// version sent no key, so a sale whose request had reached the server but whose answer had not reached the device was recorded a second time when the connection came back.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the key of a sale', () {
    test('is a random version 4 UUID', () {
      for (int i = 0; i < 200; i++) {
        final String key = PosIdempotencyKey.generate();

        expect(PosIdempotencyKey.isValid(key), isTrue, reason: key);
        expect(key.length, 36);
      }
    });

    test('is never the same for two sales', () {
      final Random random = Random(11);
      final Set<String> keys = <String>{for (int i = 0; i < 10000; i++) PosIdempotencyKey.generate(random: random)};

      expect(keys.length, 10000);
    });

    test('is what the server reads from the header named Idempotency-Key', () {
      expect(PosIdempotencyKey.header, 'Idempotency-Key');
    });

    test('is valid only when it is a UUID', () {
      expect(PosIdempotencyKey.isValid(null), isFalse);
      expect(PosIdempotencyKey.isValid(''), isFalse);
      expect(PosIdempotencyKey.isValid('sale-1'), isFalse);
      expect(PosIdempotencyKey.isValid('123e4567-e89b-12d3-a456-426614174000'), isFalse, reason: 'version 1, not 4');
    });
  });

  group('a sale sent to the server', () {
    test('carries its key in the header, and keeps the credential and the other headers', () async {
      final env = await _repository();

      await env.repository.placeOrder(_sale(), idempotencyKey: '9f2c1d3e-5b7a-4c8d-8e1f-0a2b3c4d5e6f');

      final RequestOptions sent = env.adapter.requests.single;
      expect(sent.path, endsWith(AppConstants.placeOrderUri));
      expect(sent.headers['Idempotency-Key'], '9f2c1d3e-5b7a-4c8d-8e1f-0a2b3c4d5e6f');
      expect(sent.headers['Authorization'], 'Bearer a-real-looking-session-token-value');
      expect(sent.headers['Content-Type'], isNotNull);
    });

    test('is replayed under the same key, whatever the body is read back as', () async {
      final env = await _repository();
      final String key = PosIdempotencyKey.generate();

      await env.repository.placeOrder(_sale(), idempotencyKey: key);
      await env.repository.placeOrderRaw(<String, dynamic>{'order_amount': 1500, 'cart': <dynamic>[]}, idempotencyKey: key);

      expect(env.adapter.requests.map((RequestOptions request) => request.headers['Idempotency-Key']).toList(), <String>[key, key]);
    });

    test('without a key sends no header at all', () async {
      final env = await _repository();

      await env.repository.placeOrder(_sale());
      await env.repository.placeOrderRaw(<String, dynamic>{'order_amount': 1500});

      for (final RequestOptions request in env.adapter.requests) {
        expect(request.headers.containsKey('Idempotency-Key'), isFalse);
      }
    });
  });

  group('a sale in the outbox', () {
    final PendingPosOrder order = PendingPosOrder(
      id: '42',
      body: <String, dynamic>{'order_amount': 1500, 'cart': <dynamic>[]},
      createdAt: DateTime.utc(2026, 11, 18, 10, 30),
      orderAmount: 1500,
      customerName: 'Walk-In Customer',
      idempotencyKey: '9f2c1d3e-5b7a-4c8d-8e1f-0a2b3c4d5e6f',
    );

    test('keeps its key through the disk and through a failed replay', () {
      final PendingPosOrder? restored = PendingPosOrder.decode(order.encode());

      expect(restored!.idempotencyKey, '9f2c1d3e-5b7a-4c8d-8e1f-0a2b3c4d5e6f');
      expect(order.copyWith(attempts: 3, lastError: 'timeout').idempotencyKey, '9f2c1d3e-5b7a-4c8d-8e1f-0a2b3c4d5e6f');
    });

    test('that an earlier version queued has no key until its first replay', () {
      final Map<String, dynamic> stored = order.toJson()..remove('idempotency_key');

      expect(PendingPosOrder.fromJson(stored).idempotencyKey, isNull);
      expect(PendingPosOrder.fromJson(stored).copyWith(idempotencyKey: PosIdempotencyKey.generate()).idempotencyKey, isNotNull);
    });
  });

  group('the code of the seller app', () {
    String code(String path) => File(path).readAsStringSync();

    test('the cart controller makes one key for a sale and sends it and queues it', () {
      final String cart = code('lib/features/pos/controllers/cart_controller.dart');

      expect('PosIdempotencyKey.generate()'.allMatches(cart).length, 1, reason: 'one key for one sale');
      expect(cart, contains('cartServiceInterface.placeOrder(placeOrderBody, idempotencyKey: idempotencyKey)'));
      expect(cart, contains('_handleOfflineOrder(context, placeOrderBody, idempotencyKey)'));
      expect(cart, contains('idempotencyKey: idempotencyKey,'));
    });

    test('the outbox replays a sale under the key it was first sent with and keys a sale that has none before it is sent', () {
      final String outbox = code('lib/features/pos/controllers/offline_sales_controller.dart');

      expect(outbox, contains('placeOrderRaw(order.body, idempotencyKey: order.idempotencyKey, storefront: order.storefront)'));
      expect(outbox, contains('order.idempotencyKey == null'));
    });
  });
}
