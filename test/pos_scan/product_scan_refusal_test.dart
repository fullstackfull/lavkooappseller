import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/error_response.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/product_scan_refusal_model.dart';

/// The two answers of `GET api/v3/seller/pos/products` that are neither a product nor an empty list, and the app knows
/// what to do with: 409 `ambiguous_code` and 422 `country`. Everything else is the business of the app's error handler,
/// exactly as before.
DioException _answered(int status, Object? body) {
  final RequestOptions options = RequestOptions(path: '/api/v3/seller/pos/products');
  return DioException.badResponse(
    statusCode: status,
    requestOptions: options,
    response: Response<dynamic>(requestOptions: options, statusCode: status, data: body),
  );
}

Map<String, Object?> _ambiguous({Object? candidates = _unset, String? message = 'More than one product.'}) =>
    <String, Object?>{
      'errors': <Object?>[
        <String, Object?>{
          'code': 'ambiguous_code',
          'message': message,
          if (!identical(candidates, _unset)) 'candidates': candidates,
        },
      ],
    };

const Object _unset = Object();

void main() {
  group('409 ambiguous_code', () {
    test('names the candidates with their id, name and country, and keeps the server message', () {
      final ProductScanRefusal? refusal = ProductScanRefusal.fromException(_answered(
        409,
        _ambiguous(candidates: <Object?>[
          <String, Object?>{'id': 1, 'name': 'Rose Serum 30 ml', 'country': 'SA'},
          <String, Object?>{'id': 2, 'name': 'Rose Serum 50 ml', 'country': 'KW'},
        ]),
      ));

      expect(refusal, isA<AmbiguousScanCodeError>());
      final AmbiguousScanCodeError ambiguity = refusal! as AmbiguousScanCodeError;
      expect(ambiguity.candidates.map((ScanCandidateModel candidate) => candidate.id), <int?>[1, 2]);
      expect(ambiguity.candidates.map((ScanCandidateModel candidate) => candidate.name),
          <String>['Rose Serum 30 ml', 'Rose Serum 50 ml']);
      expect(ambiguity.candidates.map((ScanCandidateModel candidate) => candidate.country), <String?>['SA', 'KW']);
      expect(ambiguity.serverMessage, 'More than one product.');
    });

    test('is still an ErrorResponse, so the app error handler reads its message as it reads any other', () {
      final ProductScanRefusal refusal =
          ProductScanRefusal.fromException(_answered(409, _ambiguous(candidates: <Object?>[])))!;

      expect(refusal, isA<ErrorResponse>());
      expect(refusal.errors!.first.code, 'ambiguous_code');
      expect(refusal.errors!.first.message, 'More than one product.');
    });

    test('without a candidates list it is still an ambiguity, with nobody to choose from', () {
      final AmbiguousScanCodeError ambiguity =
          ProductScanRefusal.fromException(_answered(409, _ambiguous()))! as AmbiguousScanCodeError;

      expect(ambiguity.candidates, isEmpty);
      expect(ambiguity.spansCountries, isFalse);
    });

    test('a candidates value that is not a list is no candidates', () {
      for (final Object? candidates in <Object?>[
        null,
        'SA',
        7,
        <String, Object?>{'id': 1}
      ]) {
        final AmbiguousScanCodeError ambiguity =
            ProductScanRefusal.fromException(_answered(409, _ambiguous(candidates: candidates)))!
                as AmbiguousScanCodeError;

        expect(ambiguity.candidates, isEmpty, reason: '$candidates');
      }
    });

    test('reads a candidate that is thin or oddly typed instead of failing on it', () {
      final AmbiguousScanCodeError ambiguity = ProductScanRefusal.fromException(_answered(
        409,
        _ambiguous(candidates: <Object?>[
          'not a candidate',
          7,
          null,
          <String, Object?>{'id': '12', 'name': 99, 'country': ' kw '},
          <String, Object?>{'name': '  '},
          <String, Object?>{'id': 3.0, 'name': 'Toner', 'country': ''},
        ]),
      ))! as AmbiguousScanCodeError;

      expect(ambiguity.candidates, hasLength(3));
      expect(ambiguity.candidates[0].id, 12);
      expect(ambiguity.candidates[0].name, '99');
      expect(ambiguity.candidates[0].country, 'kw');
      expect(ambiguity.candidates[1].id, isNull);
      expect(ambiguity.candidates[1].name, '');
      expect(ambiguity.candidates[1].country, isNull);
      expect(ambiguity.candidates[2].id, 3);
      expect(ambiguity.candidates[2].country, isNull);
    });

    test('a candidate is a market only when its country is one of the six, in any spelling', () {
      const List<String?> known = <String?>['SA', 'ae', ' Kw ', 'QA', 'bh', 'OM'];
      for (final String? country in known) {
        expect(ScanCandidateModel(id: 1, name: 'x', country: country).marketCode, isNotNull, reason: '$country');
      }
      expect(const ScanCandidateModel(id: 1, name: 'x', country: ' kw ').marketCode, 'KW');
      for (final String? country in <String?>[null, '', 'US', 'KWT', 'Kuwait']) {
        expect(ScanCandidateModel(id: 1, name: 'x', country: country).marketCode, isNull, reason: '$country');
      }
    });

    test('spans countries when at least two different markets hold a candidate', () {
      ScanCandidateModel candidate(String? country) => ScanCandidateModel(id: 1, name: 'x', country: country);

      expect(
          AmbiguousScanCodeError(
              errors: const <Errors>[],
              candidates: <ScanCandidateModel>[candidate('SA'), candidate('KW')]).spansCountries,
          isTrue);
      expect(
          AmbiguousScanCodeError(
              errors: const <Errors>[],
              candidates: <ScanCandidateModel>[candidate('SA'), candidate('sa')]).spansCountries,
          isFalse);
      expect(
          AmbiguousScanCodeError(
              errors: const <Errors>[],
              candidates: <ScanCandidateModel>[candidate('SA'), candidate(null)]).spansCountries,
          isFalse);
      expect(
          AmbiguousScanCodeError(
              errors: const <Errors>[],
              candidates: <ScanCandidateModel>[candidate('SA'), candidate('US')]).spansCountries,
          isFalse);
      expect(
          AmbiguousScanCodeError(errors: const <Errors>[], candidates: <ScanCandidateModel>[candidate('SA')])
              .spansCountries,
          isFalse);
    });
  });

  group('422 country', () {
    test('carries the message the server already translated', () {
      final ProductScanRefusal? refusal = ProductScanRefusal.fromException(_answered(422, <String, Object?>{
        'errors': <Object?>[
          <String, Object?>{
            'code': 'country',
            'message': 'The country must be one of the configured storefront countries.'
          },
        ],
      }));

      expect(refusal, isA<ScanCountryRefusedError>());
      expect(refusal!.serverMessage, 'The country must be one of the configured storefront countries.');
      expect(refusal, isA<ErrorResponse>());
    });

    test('a blank or missing message reads as no message, so the caller can use its own', () {
      for (final Object? message in <Object?>[null, '', '   ']) {
        final ProductScanRefusal? refusal = ProductScanRefusal.fromException(_answered(422, <String, Object?>{
          'errors': <Object?>[
            <String, Object?>{'code': 'country', 'message': message},
          ],
        }));

        expect(refusal, isA<ScanCountryRefusedError>(), reason: '$message');
        expect(refusal!.serverMessage, isNull, reason: '$message');
      }
    });
  });

  group('everything else is left to the app error handler', () {
    test('a 409 or a 422 that says something else', () {
      expect(
          ProductScanRefusal.fromException(_answered(409, <String, Object?>{
            'errors': <Object?>[
              <String, Object?>{'code': 'conflict', 'message': 'x'}
            ]
          })),
          isNull);
      expect(
          ProductScanRefusal.fromException(_answered(422, <String, Object?>{
            'errors': <Object?>[
              <String, Object?>{'code': 'code', 'message': 'x'}
            ]
          })),
          isNull);
    });

    test('the right code under the wrong status', () {
      expect(ProductScanRefusal.fromException(_answered(422, _ambiguous(candidates: <Object?>[]))), isNull);
      expect(
          ProductScanRefusal.fromException(_answered(409, <String, Object?>{
            'errors': <Object?>[
              <String, Object?>{'code': 'country', 'message': 'x'}
            ]
          })),
          isNull);
      for (final int status in <int>[400, 401, 403, 404, 429, 500, 503]) {
        expect(ProductScanRefusal.fromException(_answered(status, _ambiguous(candidates: <Object?>[]))), isNull,
            reason: '$status');
      }
    });

    test('a body that is not the shape of an error list', () {
      for (final Object? body in <Object?>[
        null,
        '<html>conflict</html>',
        <Object?>[],
        <String, Object?>{},
        <String, Object?>{'errors': null},
        <String, Object?>{'errors': 'country'},
        <String, Object?>{'errors': <Object?>[]},
        <String, Object?>{
          'errors': <Object?>['ambiguous_code']
        },
        <String, Object?>{
          'errors': <Object?>[
            <String, Object?>{'code': 7}
          ]
        },
        <String, Object?>{'message': 'ambiguous_code'},
      ]) {
        expect(ProductScanRefusal.fromException(_answered(409, body)), isNull, reason: '$body');
        expect(ProductScanRefusal.fromException(_answered(422, body)), isNull, reason: '$body');
      }
    });

    test('a failure with no answer, and things that are not a Dio failure at all', () {
      final RequestOptions options = RequestOptions(path: '/x');

      expect(ProductScanRefusal.fromException(DioException.connectionError(requestOptions: options, reason: 'offline')),
          isNull);
      expect(
          ProductScanRefusal.fromException(
              DioException.connectionTimeout(timeout: const Duration(seconds: 1), requestOptions: options)),
          isNull);
      expect(ProductScanRefusal.fromException(const SocketException('offline')), isNull);
      expect(ProductScanRefusal.fromException(StateError('x')), isNull);
      expect(ProductScanRefusal.fromException('ambiguous_code'), isNull);
    });
  });
}
