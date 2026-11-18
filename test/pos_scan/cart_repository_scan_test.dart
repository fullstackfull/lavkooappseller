import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/exception/api_error_handler.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/error_response.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/product_scan_refusal_model.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/repository/cart_repository.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/services/cart_service.dart';
import 'package:syriacosmeticsmanger/features/storefront/storefront_config.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

import 'support/scripted_adapter.dart';

const String _scanUrl = '${AppConstants.baseUrl}/api/v3/seller/pos/products';

Future<CartRepository> _repository(
  ScriptedAdapter adapter, {
  Map<String, Object> stored = const <String, Object>{},
  bool? storefrontsEnabled,
}) async {
  SharedPreferences.setMockInitialValues(stored);
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final Dio dio = Dio()..httpClientAdapter = adapter;
  final DioClient client = DioClient(
    AppConstants.baseUrl,
    dio,
    loggingInterceptor: LoggingInterceptor(),
    sharedPreferences: preferences,
  );

  return storefrontsEnabled == null
      ? CartRepository(dioClient: client, sharedPreferences: preferences)
      : CartRepository(dioClient: client, sharedPreferences: preferences, storefrontsEnabled: storefrontsEnabled);
}

const Map<String, Object?> _product = <String, Object?>{
  'id': 7,
  'name': 'Rose Serum',
  'code': 'ABC123',
  'unit_price': 25.5
};

ScriptedAnswer get _oneProduct => ScriptedAnswer.json(_product);

ScriptedAnswer get _ambiguity => ScriptedAnswer.json(<String, Object?>{
      'errors': <Object?>[
        <String, Object?>{
          'code': 'ambiguous_code',
          'message': 'The scanned code matches more than one product.',
          'candidates': <Object?>[
            <String, Object?>{'id': 1, 'name': 'Serum A', 'country': 'SA'},
            <String, Object?>{'id': 2, 'name': 'Serum B', 'country': 'KW'},
          ],
        },
      ],
    }, status: 409);

ScriptedAnswer get _countryRefused => ScriptedAnswer.json(<String, Object?>{
      'errors': <Object?>[
        <String, Object?>{
          'code': 'country',
          'message': 'The country must be one of the configured storefront countries.'
        },
      ],
    }, status: 422);

/// What the app's own error handler says about the same failure, as a value two runs can be compared on.
Object? _normalized(Object? error) => error is ErrorResponse ? error.toJson() : error;

Future<Object?> _outcomeOf(Future<Object?> Function() run) async {
  try {
    return await run();
  } catch (error) {
    return 'threw ${error.runtimeType}';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the request while storefronts are off (today\'s build)', () {
    test('the storefront flag is off by default, and so is the repository that follows it', () async {
      expect(StorefrontConfig.enabled, isFalse);
    });

    test('is the request this app has always sent: the code and nothing else', () async {
      final ScriptedAdapter adapter = ScriptedAdapter.always(_oneProduct);
      final CartRepository repository = await _repository(adapter);

      await repository.getProductFromScan('ABC123');

      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.uri.toString(), '$_scanUrl?code=ABC123');
      expect(adapter.requests.single.rawQuery, 'code=ABC123');
    });

    test('sends no country however the seller\'s stored market looks', () async {
      for (final Object stored in <Object>['AE', 'KW', 'ae', 'US', '', 7]) {
        final ScriptedAdapter adapter = ScriptedAdapter.always(_oneProduct);
        final CartRepository repository =
            await _repository(adapter, stored: <String, Object>{AppConstants.storefrontCountry: stored});

        await repository.getProductFromScan('ABC123');

        expect(adapter.requests.single.uri.toString(), '$_scanUrl?code=ABC123', reason: 'stored: $stored');
        expect(adapter.requests.single.uri.queryParameters.containsKey('country'), isFalse, reason: 'stored: $stored');
      }
    });

    test('says exactly the same with the flag named off', () async {
      final ScriptedAdapter implicit = ScriptedAdapter.always(_oneProduct);
      final ScriptedAdapter named = ScriptedAdapter.always(_oneProduct);
      const Map<String, Object> stored = <String, Object>{AppConstants.storefrontCountry: 'QA'};

      await (await _repository(implicit, stored: stored)).getProductFromScan('ABC123');
      await (await _repository(named, stored: stored, storefrontsEnabled: false)).getProductFromScan('ABC123');

      expect(named.requests.single.uri.toString(), implicit.requests.single.uri.toString());
    });

    test('a scan that was cancelled still asks for the code "null", as it does today', () async {
      final ScriptedAdapter adapter = ScriptedAdapter.always(ScriptedAnswer.json(<Object?>[]));
      final CartRepository repository = await _repository(adapter);

      await repository.getProductFromScan(null);

      expect(adapter.requests.single.uri.toString(), '$_scanUrl?code=null');
    });
  });

  group('the request while storefronts are on', () {
    test('names the market the seller works in', () async {
      for (final String market in <String>['SA', 'AE', 'KW', 'QA', 'BH', 'OM']) {
        final ScriptedAdapter adapter = ScriptedAdapter.always(_oneProduct);
        final CartRepository repository = await _repository(
          adapter,
          stored: <String, Object>{AppConstants.storefrontCountry: market},
          storefrontsEnabled: true,
        );

        await repository.getProductFromScan('ABC123');

        expect(adapter.requests.single.uri.toString(), '$_scanUrl?code=ABC123&country=$market');
      }
    });

    test('names the default market while the seller has not chosen one, as the storefront header does', () async {
      final ScriptedAdapter adapter = ScriptedAdapter.always(_oneProduct);
      final CartRepository repository = await _repository(adapter, storefrontsEnabled: true);

      await repository.getProductFromScan('ABC123');

      expect(adapter.requests.single.uri.toString(), '$_scanUrl?code=ABC123&country=SA');
    });

    test('never sends a country the app does not know: a stored value that names no market is the default market',
        () async {
      for (final Object stored in <Object>['US', '', 'Kuwait', 7]) {
        final ScriptedAdapter adapter = ScriptedAdapter.always(_oneProduct);
        final CartRepository repository = await _repository(
          adapter,
          stored: <String, Object>{AppConstants.storefrontCountry: stored},
          storefrontsEnabled: true,
        );

        await repository.getProductFromScan('ABC123');

        expect(adapter.requests.single.uri.queryParameters['country'], 'SA', reason: 'stored: $stored');
      }
    });

    test('sends the country in upper case even when it was stored in lower case', () async {
      final ScriptedAdapter adapter = ScriptedAdapter.always(_oneProduct);
      final CartRepository repository = await _repository(
        adapter,
        stored: <String, Object>{AppConstants.storefrontCountry: 'kw'},
        storefrontsEnabled: true,
      );

      await repository.getProductFromScan('ABC123');

      expect(adapter.requests.single.uri.queryParameters['country'], 'KW');
    });

    test('sends one country, once', () async {
      final ScriptedAdapter adapter = ScriptedAdapter.always(_oneProduct);
      final CartRepository repository = await _repository(adapter, storefrontsEnabled: true);

      await repository.getProductFromScan('ABC123');

      expect(adapter.requests.single.uri.queryParametersAll['country'], <String>['SA']);
      expect(adapter.requests.single.uri.queryParametersAll['code'], <String>['ABC123']);
    });
  });

  group('a country the seller chose for this scan', () {
    test('goes on the request, ahead of the market the seller works in', () async {
      final ScriptedAdapter adapter = ScriptedAdapter.always(_oneProduct);
      final CartRepository repository = await _repository(
        adapter,
        stored: <String, Object>{AppConstants.storefrontCountry: 'KW'},
        storefrontsEnabled: true,
      );

      await repository.getProductFromScan('ABC123', country: 'AE');

      expect(adapter.requests.single.uri.toString(), '$_scanUrl?code=ABC123&country=AE');
    });

    test('goes on the request while storefronts are off too, because only a server that speaks countries asks for it',
        () async {
      final ScriptedAdapter adapter = ScriptedAdapter.always(_oneProduct);
      final CartRepository repository = await _repository(adapter);

      await repository.getProductFromScan('ABC123', country: 'AE');

      expect(adapter.requests.single.uri.toString(), '$_scanUrl?code=ABC123&country=AE');
    });

    test('the service passes it through, and passes nothing when nothing was chosen', () async {
      final ScriptedAdapter chosen = ScriptedAdapter.always(_oneProduct);
      final ScriptedAdapter notChosen = ScriptedAdapter.always(_oneProduct);

      await CartService(cartRepositoryInterface: await _repository(chosen)).getProductFromScan('ABC123', country: 'BH');
      await CartService(cartRepositoryInterface: await _repository(notChosen)).getProductFromScan('ABC123');

      expect(chosen.requests.single.uri.toString(), '$_scanUrl?code=ABC123&country=BH');
      expect(notChosen.requests.single.uri.toString(), '$_scanUrl?code=ABC123');
    });
  });

  group('what the server answers', () {
    test('one product is handed over untouched, as a success', () async {
      final CartRepository repository = await _repository(ScriptedAdapter.always(_oneProduct));

      final ApiResponse response = await repository.getProductFromScan('ABC123');

      expect(response.error, isNull);
      expect(response.response?.statusCode, 200);
      expect(response.response?.data, _product);
    });

    test('an empty list is handed over untouched, as a success with nothing in it', () async {
      final CartRepository repository = await _repository(ScriptedAdapter.always(ScriptedAnswer.json(<Object?>[])));

      final ApiResponse response = await repository.getProductFromScan('ABC123');

      expect(response.error, isNull);
      expect(response.response?.statusCode, 200);
      expect(response.response?.data, isA<List<dynamic>>());
      expect(response.response?.data, isEmpty);
    });

    test('409 ambiguous_code arrives as the ambiguity, with its candidates and no response', () async {
      final CartRepository repository = await _repository(ScriptedAdapter.always(_ambiguity));

      final ApiResponse response = await repository.getProductFromScan('ABC123');

      expect(response.response, isNull);
      expect(response.error, isA<AmbiguousScanCodeError>());
      final AmbiguousScanCodeError ambiguity = response.error as AmbiguousScanCodeError;
      expect(
          ambiguity.candidates.map((ScanCandidateModel candidate) => candidate.name), <String>['Serum A', 'Serum B']);
      expect(ambiguity.spansCountries, isTrue);
    });

    test('422 country arrives as the refusal, with the server\'s own words', () async {
      final CartRepository repository = await _repository(ScriptedAdapter.always(_countryRefused));

      final ApiResponse response = await repository.getProductFromScan('ABC123');

      expect(response.response, isNull);
      expect(response.error, isA<ScanCountryRefusedError>());
      expect((response.error as ScanCountryRefusedError).serverMessage,
          'The country must be one of the configured storefront countries.');
    });

    test('every other failure reaches the app error handler untouched', () async {
      final List<({String label, ScriptedAnswer answer, DioException equivalent})> failures =
          <({String label, ScriptedAnswer answer, DioException equivalent})>[
        _failure('409 with another code', 409, <String, Object?>{
          'errors': <Object?>[
            <String, Object?>{'code': 'conflict', 'message': 'Busy.'}
          ]
        }),
        _failure('422 with another code', 422, <String, Object?>{
          'errors': <Object?>[
            <String, Object?>{'code': 'code', 'message': 'The code is required.'}
          ]
        }),
        _failure('409 that is not an error list', 409, <String, Object?>{'message': 'Busy.'}),
        _failure('401', 401, <String, Object?>{'message': 'Unauthenticated.'}),
        _failure('403', 403, <String, Object?>{'message': 'Forbidden.'}),
        _failure('404', 404, <String, Object?>{'message': 'Not found.'}),
        _failure('429', 429, <String, Object?>{'message': 'Slow down.'}),
        _failure('500 with a message', 500, <String, Object?>{'message': 'Boom.'}),
        _failure('500 with a web page', 500, '<html>Boom</html>'),
        _failure('503', 503, <String, Object?>{'message': 'Back soon.'}),
        _failure('400', 400, <String, Object?>{
          'errors': <Object?>[
            <String, Object?>{'code': 'x', 'message': 'Bad.'}
          ]
        }),
        // The handler reads an error list out of any other status, and a page that is not JSON makes it throw: both are kept.
        _failure('409 with a web page', 409, '<html>Conflict</html>'),
        _failure('422 with a web page', 422, '<html>Invalid</html>'),
      ];

      for (final failure in failures) {
        final CartRepository repository = await _repository(ScriptedAdapter.always(failure.answer));

        final Object? viaRepository =
            await _outcomeOf(() async => _normalized((await repository.getProductFromScan('ABC123')).error));
        final Object? viaHandler =
            await _outcomeOf(() async => _normalized(ApiErrorHandler.getMessage(failure.equivalent)));

        expect(viaRepository, viaHandler, reason: failure.label);
      }
    });

    test('no signal reaches the app error handler as it always did', () async {
      final CartRepository repository = await _repository(ScriptedAdapter.offline());

      final ApiResponse response = await repository.getProductFromScan('ABC123');

      expect(response.response, isNull);
      expect(response.error, 'no_internet_connection');
    });
  });
}

({String label, ScriptedAnswer answer, DioException equivalent}) _failure(String label, int status, Object? body) {
  final RequestOptions options = RequestOptions(path: '/api/v3/seller/pos/products');
  return (
    label: label,
    answer: body is String ? ScriptedAnswer.page(body, status: status) : ScriptedAnswer.json(body, status: status),
    equivalent: DioException.badResponse(
      statusCode: status,
      requestOptions: options,
      response: Response<dynamic>(requestOptions: options, statusCode: status, data: body),
    ),
  );
}
