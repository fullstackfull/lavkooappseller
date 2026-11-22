import 'package:dio/dio.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/error_response.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';

/// One product a scanned code could stand for, as the server names it in the answer that refuses to pick one.
class ScanCandidateModel {
  const ScanCandidateModel({required this.id, required this.name, required this.country});

  factory ScanCandidateModel.fromJson(Map<dynamic, dynamic> json) {
    final Object? rawId = json['id'];
    final String country = (json['country']?.toString() ?? '').trim();

    return ScanCandidateModel(
      id: rawId is num ? rawId.toInt() : int.tryParse(rawId?.toString() ?? ''),
      name: (json['name']?.toString() ?? '').trim(),
      country: country.isEmpty ? null : country,
    );
  }

  final int? id;
  final String name;
  final String? country;

  /// The upper-case code of the GCC market the product belongs to, or null when the server named no country the app knows.
  String? get marketCode => MarketScope.fromCountryCode(country)?.countryCode;
}

/// The answers of `GET api/v3/seller/pos/products` that are neither a product nor an empty list and that this app knows
/// what to do about. A refusal is an [ErrorResponse], so the app's error handler still reads its message like any other.
sealed class ProductScanRefusal extends ErrorResponse {
  ProductScanRefusal({required super.errors});

  static const int _ambiguousStatus = 409;
  static const String _ambiguousCode = 'ambiguous_code';
  static const int _countryStatus = 422;
  static const String _countryCode = 'country';

  /// The message the server wrote, which it has already translated, or null when it wrote none.
  String? get serverMessage {
    final String? message = errors?.firstOrNull?.message?.trim();
    return message == null || message.isEmpty ? null : message;
  }

  /// The refusal [exception] stands for, or null for every other failure: those stay with the app's error handler.
  static ProductScanRefusal? fromException(Object exception) {
    if (exception is! DioException) {
      return null;
    }

    final int? status = exception.response?.statusCode;
    final Object? body = exception.response?.data;
    if (body is! Map || body['errors'] is! List) {
      return null;
    }

    final List<dynamic> errors = body['errors'] as List<dynamic>;
    if (errors.isEmpty || errors.first is! Map) {
      return null;
    }

    final Map<dynamic, dynamic> first = errors.first as Map<dynamic, dynamic>;
    final Object? code = first['code'];
    final Object? message = first['message'];
    final List<Errors> readableErrors = <Errors>[
      Errors(code: code is String ? code : null, message: message?.toString()),
    ];

    if (status == _ambiguousStatus && code == _ambiguousCode) {
      final Object? candidates = first['candidates'];
      return AmbiguousScanCodeError(
        errors: readableErrors,
        candidates: <ScanCandidateModel>[
          if (candidates is List)
            for (final Object? candidate in candidates)
              if (candidate is Map) ScanCandidateModel.fromJson(candidate),
        ],
      );
    }

    if (status == _countryStatus && code == _countryCode) {
      return ScanCountryRefusedError(errors: readableErrors);
    }

    return null;
  }
}

/// 409 `ambiguous_code`: more than one of the seller's products answers to the scanned value.
final class AmbiguousScanCodeError extends ProductScanRefusal {
  AmbiguousScanCodeError({required super.errors, required this.candidates});

  final List<ScanCandidateModel> candidates;

  /// True when at least two of the GCC markets each hold a candidate, so naming a country settles the scan.
  bool get spansCountries =>
      candidates.map((ScanCandidateModel candidate) => candidate.marketCode).whereType<String>().toSet().length > 1;
}

/// 422 `country`: the server does not know the market the scan named. Nothing a retry would change.
final class ScanCountryRefusedError extends ProductScanRefusal {
  ScanCountryRefusedError({required super.errors});
}
