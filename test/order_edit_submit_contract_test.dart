import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/order_edit/domain/models/order_edit_submit_result.dart';

/// `POST /api/v3/seller/orders/edit-order-submit`.
///
/// The backend answers an edit it refuses (a product out of stock, an order
/// that is no longer editable) with HTTP 200 and `status: error`, exactly as it
/// answers a saved edit with HTTP 200 and `status: success`. The screen used to
/// read only the status code, so a refused edit closed the screen as if it had
/// been saved and the seller never saw why nothing changed.
ApiResponse _answer(Object? body, {int statusCode = 200}) {
  return ApiResponse.withSuccess(Response<dynamic>(
    requestOptions: RequestOptions(path: '/api/v3/seller/orders/edit-order-submit'),
    statusCode: statusCode,
    data: body,
  ));
}

OrderEditSubmitResult _parse(Object? body, {int statusCode = 200}) {
  return OrderEditSubmitResult.fromApiResponse(_answer(body, statusCode: statusCode));
}

void main() {
  group('order edit submit contract', () {
    test('a refused edit is not a saved one, and carries the server message', () {
      final OrderEditSubmitResult result = _parse(<String, dynamic>{
        'status': 'error',
        'message': 'Out of stock',
        'request': <String, dynamic>{'order_id': '100123', 'products': '[]'},
      });

      expect(result.isRefused, isTrue);
      expect(result.isSaved, isFalse);
      expect(result.message, 'Out of stock');
    });

    test('the status is compared without regard to case or padding', () {
      for (final String status in <String>['ERROR', 'Error', ' error ']) {
        final OrderEditSubmitResult result = _parse(<String, dynamic>{'status': status, 'message': 'Refused'});

        expect(result.isRefused, isTrue, reason: 'status "$status"');
        expect(result.isSaved, isFalse, reason: 'status "$status"');
      }
    });

    test('a refusal without a usable message is still a refusal, with no message to show', () {
      final List<Map<String, dynamic>> bodies = <Map<String, dynamic>>[
        <String, dynamic>{'status': 'error'},
        <String, dynamic>{'status': 'error', 'message': null},
        <String, dynamic>{'status': 'error', 'message': ''},
        <String, dynamic>{'status': 'error', 'message': '   '},
        <String, dynamic>{'status': 'error', 'message': <String>['not', 'a', 'string']},
      ];

      for (final Map<String, dynamic> body in bodies) {
        final OrderEditSubmitResult result = _parse(body);

        expect(result.isRefused, isTrue, reason: '$body');
        expect(result.isSaved, isFalse, reason: '$body');
        expect(result.message, isNull, reason: '$body');
      }
    });

    test('a saved edit is saved', () {
      final OrderEditSubmitResult result = _parse(<String, dynamic>{
        'status': 'success',
        'message': 'Order edited successfully',
        'request': <String, dynamic>{'order_id': '100123', 'products': '[]'},
      });

      expect(result.isSaved, isTrue);
      expect(result.isRefused, isFalse);
      expect(result.message, isNull);
    });

    test('a 200 body with no status, which is what servers before the refusals send, is saved', () {
      final List<Object?> bodies = <Object?>[
        <String, dynamic>{'message': 'Order edited successfully'},
        <String, dynamic>{'status': null},
        <String, dynamic>{},
      ];

      for (final Object? body in bodies) {
        final OrderEditSubmitResult result = _parse(body);

        expect(result.isSaved, isTrue, reason: '$body');
        expect(result.isRefused, isFalse, reason: '$body');
      }
    });

    test('a body that is not a JSON object never throws, and is treated as it always was: saved', () {
      final List<Object?> bodies = <Object?>[
        null,
        '',
        '   ',
        'not json',
        '<html><body>Bad gateway</body></html>',
        '{"status": "error", "message": ',
        '[]',
        '["status", "error"]',
        <dynamic>[],
        42,
        true,
      ];

      for (final Object? body in bodies) {
        OrderEditSubmitResult? result;
        expect(() => result = _parse(body), returnsNormally, reason: 'body: $body');

        expect(result?.isSaved, isTrue, reason: 'body: $body');
        expect(result?.isRefused, isFalse, reason: 'body: $body');
      }
    });

    test('a JSON body that arrives as a string, because nothing labelled it JSON, is still read', () {
      final OrderEditSubmitResult refused = _parse('  {"status":"error","message":"Out of stock"}\n');
      expect(refused.isRefused, isTrue);
      expect(refused.message, 'Out of stock');

      final OrderEditSubmitResult saved = _parse('{"status":"success","message":"Order edited successfully"}');
      expect(saved.isSaved, isTrue);
    });

    test('an answer that is not an HTTP 200 is neither saved nor refused, so the usual error handling shows it', () {
      final List<OrderEditSubmitResult> results = <OrderEditSubmitResult>[
        OrderEditSubmitResult.fromApiResponse(ApiResponse.withError('no_internet_connection')),
        // Dio throws for 4xx and 5xx; a successful non-200 (201, 204) used to
        // reach the error handler too, and must keep doing so.
        _parse(<String, dynamic>{'status': 'success'}, statusCode: 201),
        _parse(null, statusCode: 204),
      ];

      for (final OrderEditSubmitResult result in results) {
        expect(result.outcome, OrderEditSubmitOutcome.failed);
        expect(result.isSaved, isFalse);
        expect(result.isRefused, isFalse);
      }
    });
  });
}
