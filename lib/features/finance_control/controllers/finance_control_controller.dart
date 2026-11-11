import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/finance_control/domain/models/finance_control_models.dart';
import 'package:syriacosmeticsmanger/features/finance_control/domain/services/finance_control_service_interface.dart';
import 'package:syriacosmeticsmanger/helper/api_checker.dart';

/// The seller's own view of the marketplace's arithmetic.
///
/// The reconciliation and the price history load together because the screen
/// shows them together. The simulation does not: it answers a question the
/// seller has to ask first, and running it on open would put a number on screen
/// that nobody asked for and that means nothing until they type a price.
class FinanceControlController with ChangeNotifier {
  final FinanceControlServiceInterface financeControlServiceInterface;
  FinanceControlController({required this.financeControlServiceInterface});

  ReconciliationModel? _reconciliation;
  ReconciliationModel? get reconciliation => _reconciliation;

  List<PriceChangeModel> _priceChanges = const <PriceChangeModel>[];
  List<PriceChangeModel> get priceChanges => _priceChanges;

  FeeSimulationModel? _simulation;
  FeeSimulationModel? get simulation => _simulation;

  PricingPolicyModel? _pricingPolicy;
  PricingPolicyModel? get pricingPolicy => _pricingPolicy;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSavingPolicy = false;
  bool get isSavingPolicy => _isSavingPolicy;

  bool _isSimulating = false;
  bool get isSimulating => _isSimulating;

  String? _from;
  String? get from => _from;

  String? _to;
  String? get to => _to;

  Future<void> load({String? from, String? to}) async {
    _isLoading = true;
    _from = from ?? _from;
    _to = to ?? _to;
    notifyListeners();

    await Future.wait([_loadReconciliation(), _loadPriceChanges(), _loadPricingPolicy()]);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadPricingPolicy() async {
    final dynamic response = await financeControlServiceInterface.getPricingPolicy();

    if (response is ApiResponse && response.response?.statusCode == 200 && response.response?.data is Map) {
      _pricingPolicy = PricingPolicyModel.fromJson(Map<String, dynamic>.from(response.response!.data));
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }
  }

  /// Set the floor, then read it back rather than trusting what was sent.
  ///
  /// The server decides what the policy now is — including the coverage counts,
  /// which are the part a seller actually needs to see after switching one on.
  Future<bool> savePricingPolicy({double? minMarginPercent, double? minPrice, required bool enforce}) async {
    _isSavingPolicy = true;
    notifyListeners();

    final dynamic response = await financeControlServiceInterface.savePricingPolicy({
      'min_margin_percent': minMarginPercent,
      'min_price': minPrice,
      'enforce': enforce,
    });

    final bool ok = response is ApiResponse && response.response?.statusCode == 200;

    if (!ok && response is ApiResponse) {
      ApiChecker.checkApi(response);
    } else if (ok) {
      await _loadPricingPolicy();
    }

    _isSavingPolicy = false;
    notifyListeners();

    return ok;
  }

  Future<void> _loadReconciliation() async {
    final dynamic response =
        await financeControlServiceInterface.getReconciliation(from: _from, to: _to);

    if (_ok(response) && response.response?.data is Map) {
      _reconciliation =
          ReconciliationModel.fromJson(Map<String, dynamic>.from(response.response!.data));
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }
  }

  Future<void> _loadPriceChanges({int? productId}) async {
    final dynamic response = await financeControlServiceInterface.getPriceChanges(productId: productId);

    if (_ok(response) && response.response?.data is Map) {
      final List rows = response.response!.data['changes'] as List? ?? const [];
      _priceChanges = rows
          .whereType<Map>()
          .map((e) => PriceChangeModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }
  }

  Future<void> loadPriceChangesFor(int productId) async {
    await _loadPriceChanges(productId: productId);
    notifyListeners();
  }

  Future<void> simulate(Map<String, dynamic> query) async {
    _isSimulating = true;
    // Cleared first: a stale answer sitting under a changed price is a
    // confident reply to a question nobody asked.
    _simulation = null;
    notifyListeners();

    final dynamic response = await financeControlServiceInterface.simulateFee(query);

    if (_ok(response) && response.response?.data is Map) {
      _simulation = FeeSimulationModel.fromJson(Map<String, dynamic>.from(response.response!.data));
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }

    _isSimulating = false;
    notifyListeners();
  }

  bool _ok(dynamic response) => response is ApiResponse && response.response?.statusCode == 200;
}
