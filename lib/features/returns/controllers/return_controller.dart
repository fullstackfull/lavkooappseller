import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/returns/domain/models/return_models.dart';
import 'package:syriacosmeticsmanger/features/returns/domain/services/return_service_interface.dart';
import 'package:syriacosmeticsmanger/helper/api_checker.dart';

/// The goods coming back.
///
/// Every action returns the reason it was refused rather than a bare false. A
/// return that cannot be received because it is already closed is a fact worth
/// telling the seller — "it didn't work" is not something anyone can act on.
class ReturnController with ChangeNotifier {
  final ReturnServiceInterface returnServiceInterface;
  ReturnController({required this.returnServiceInterface});

  ReturnListModel? _list;
  ReturnListModel? get list => _list;

  ReturnShipmentModel? _current;
  ReturnShipmentModel? get current => _current;

  List<ReturnLedgerEntryModel> _ledger = const <ReturnLedgerEntryModel>[];
  List<ReturnLedgerEntryModel> get ledger => _ledger;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isActing = false;
  bool get isActing => _isActing;

  String? _status;
  String? get status => _status;

  List<ReturnShipmentModel> get returns => _list?.returns ?? const <ReturnShipmentModel>[];
  List<String> get statuses => _list?.statuses ?? const <String>[];

  Future<void> getReturns({String? status, bool clearStatus = false}) async {
    if (clearStatus) {
      _status = null;
    } else if (status != null) {
      _status = status;
    }

    _isLoading = true;
    notifyListeners();

    final dynamic response = await returnServiceInterface.getReturns(status: _status);
    if (response is ApiResponse && response.response?.statusCode == 200 && response.response?.data is Map) {
      _list = ReturnListModel.fromJson(Map<String, dynamic>.from(response.response!.data));
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> getReturn(int id) async {
    _isLoading = true;
    notifyListeners();

    final dynamic response = await returnServiceInterface.getReturn(id);
    if (response is ApiResponse && response.response?.statusCode == 200 && response.response?.data is Map) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(response.response!.data);
      _current = data['return'] is Map
          ? ReturnShipmentModel.fromJson(Map<String, dynamic>.from(data['return'] as Map))
          : null;
      _ledger = data['ledger'] is List
          ? (data['ledger'] as List)
              .whereType<Map>()
              .map((row) => ReturnLedgerEntryModel.fromJson(Map<String, dynamic>.from(row)))
              .toList()
          : const <ReturnLedgerEntryModel>[];
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<String?> markInTransit(int id, {String? carrier, String? trackingNumber}) => _act(
        id,
        () => returnServiceInterface.markInTransit(id, carrier: carrier, trackingNumber: trackingNumber),
      );

  Future<String?> receive(int id, {required bool restock}) =>
      _act(id, () => returnServiceInterface.receive(id, restock: restock));

  Future<String?> reject(int id, {required String reason}) =>
      _act(id, () => returnServiceInterface.reject(id, reason: reason));

  /// Runs an action and reloads what the screen shows.
  ///
  /// Returns null on success, or the refusal — which the caller shows in place
  /// rather than as a snackbar over a screen that did not change.
  Future<String?> _act(int id, Future<dynamic> Function() action) async {
    _isActing = true;
    notifyListeners();

    String? refusal;
    final dynamic response = await action();

    if (response is ApiResponse && response.response?.statusCode == 200) {
      await getReturn(id);
      await getReturns();
    } else if (response is ApiResponse) {
      refusal = _refusalFrom(response) ?? response.error?.toString();
      if (refusal == null) ApiChecker.checkApi(response);
    }

    _isActing = false;
    notifyListeners();
    return refusal;
  }

  String? _refusalFrom(ApiResponse response) {
    final dynamic data = response.response?.data;
    if (data is Map && data['errors'] is List && (data['errors'] as List).isNotEmpty) {
      final dynamic first = (data['errors'] as List).first;
      if (first is Map && first['message'] != null) return first['message'].toString();
    }
    return null;
  }
}
