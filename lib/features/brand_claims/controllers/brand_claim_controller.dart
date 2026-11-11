import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/brand_claims/domain/models/brand_claim_models.dart';
import 'package:syriacosmeticsmanger/features/brand_claims/domain/services/brand_claim_service_interface.dart';
import 'package:syriacosmeticsmanger/helper/api_checker.dart';

/// Where the shop stands on brands, and how to do something about it.
///
/// Exposure and claims are loaded together because they answer one question
/// between them: exposure says which brands are a problem, and the claims say
/// what has already been done about each. Shown separately they would make a
/// seller hold the join in their head.
class BrandClaimController with ChangeNotifier {
  final BrandClaimServiceInterface brandClaimServiceInterface;
  BrandClaimController({required this.brandClaimServiceInterface});

  List<BrandExposureModel> _exposure = const <BrandExposureModel>[];
  List<BrandExposureModel> get exposure => _exposure;

  List<BrandClaimModel> _claims = const <BrandClaimModel>[];
  List<BrandClaimModel> get claims => _claims;

  /// Whether the marketplace is refusing listings yet or only reporting them.
  /// Two different situations, and the screen says which.
  bool _enforcing = false;
  bool get enforcing => _enforcing;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  List<BrandExposureModel> get brandsNeedingAction =>
      _exposure.where((brand) => brand.needsAction).toList();

  BrandClaimModel? claimFor(int brandId) {
    for (final BrandClaimModel claim in _claims) {
      if (claim.brandId == brandId) return claim;
    }
    return null;
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    await Future.wait([_loadExposure(), _loadClaims()]);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadExposure() async {
    final dynamic response = await brandClaimServiceInterface.getExposure();

    if (_ok(response) && response.response?.data is Map) {
      final Map data = response.response!.data as Map;
      _enforcing = data['enforcing'] == true;
      _exposure = (data['brands'] as List?)
              ?.whereType<Map>()
              .map((e) => BrandExposureModel.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const <BrandExposureModel>[];
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }
  }

  Future<void> _loadClaims() async {
    final dynamic response = await brandClaimServiceInterface.getClaims();

    if (_ok(response) && response.response?.data is Map) {
      _claims = (response.response!.data['claims'] as List?)
              ?.whereType<Map>()
              .map((e) => BrandClaimModel.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const <BrandClaimModel>[];
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }
  }

  Future<BrandClaimModel?> saveClaim({
    required int brandId,
    required String claimType,
    String? statement,
    String? expiresAt,
  }) async {
    _isBusy = true;
    notifyListeners();

    final dynamic response = await brandClaimServiceInterface.saveClaim({
      'brand_id': brandId,
      'claim_type': claimType,
      if (statement != null && statement.isNotEmpty) 'statement': statement,
      if (expiresAt != null && expiresAt.isNotEmpty) 'expires_at': expiresAt,
    });

    BrandClaimModel? saved;

    if (response is ApiResponse &&
        (response.response?.statusCode == 200 || response.response?.statusCode == 201) &&
        response.response?.data is Map) {
      saved = BrandClaimModel.fromJson(
          Map<String, dynamic>.from(response.response!.data['claim'] as Map));
      await _loadClaims();
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }

    _isBusy = false;
    notifyListeners();
    return saved;
  }

  Future<bool> attachDocument(int claimId, String documentType, MultipartFile file) async {
    _isBusy = true;
    notifyListeners();

    final dynamic response =
        await brandClaimServiceInterface.attachDocument(claimId, documentType, file);
    final bool ok = response is ApiResponse &&
        (response.response?.statusCode == 200 || response.response?.statusCode == 201);

    if (ok) {
      await _loadClaims();
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }

    _isBusy = false;
    notifyListeners();
    return ok;
  }

  Future<bool> removeDocument(int claimId, int documentId) =>
      _act(() => brandClaimServiceInterface.removeDocument(claimId, documentId));

  Future<bool> submit(int claimId) => _act(() => brandClaimServiceInterface.submit(claimId));

  Future<bool> withdraw(int claimId) => _act(() => brandClaimServiceInterface.withdraw(claimId));

  Future<bool> _act(Future<dynamic> Function() call) async {
    _isBusy = true;
    notifyListeners();

    final dynamic response = await call();
    final bool ok = _ok(response);

    if (ok) {
      // Both, not just the claims: submitting or withdrawing can change whether
      // the seller may list, and a stale exposure list would contradict the
      // claim the seller just changed.
      await Future.wait([_loadExposure(), _loadClaims()]);
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }

    _isBusy = false;
    notifyListeners();
    return ok;
  }

  bool _ok(dynamic response) => response is ApiResponse && response.response?.statusCode == 200;
}
