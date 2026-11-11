import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/reports/domain/models/report_models.dart';
import 'package:syriacosmeticsmanger/features/reports/domain/services/report_service_interface.dart';
import 'package:syriacosmeticsmanger/helper/api_checker.dart';

/// The seller's reports.
///
/// Each report keeps its own period, because a seller looking at this month's
/// orders and this year's products is doing something reasonable, not something
/// inconsistent. Each also keeps the period it *asked* for, so the chips move on
/// tap rather than waiting for the response to echo them back.
class ReportController with ChangeNotifier {
  final ReportServiceInterface reportServiceInterface;
  ReportController({required this.reportServiceInterface});

  OrderReportModel? _orderReport;
  OrderReportModel? get orderReport => _orderReport;

  ProductReportModel? _productReport;
  ProductReportModel? get productReport => _productReport;

  StockReportModel? _stockReport;
  StockReportModel? get stockReport => _stockReport;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _orderPeriod = 'this_month';
  String get orderPeriod => _orderPeriod;

  String _productPeriod = 'this_year';
  String get productPeriod => _productPeriod;

  String _stockSort = 'asc';
  String get stockSort => _stockSort;

  int? _stockCategoryId;
  int? get stockCategoryId => _stockCategoryId;

  DateTime? _customFrom;
  DateTime? get customFrom => _customFrom;

  DateTime? _customTo;
  DateTime? get customTo => _customTo;

  Future<void> getOrderReport({String? dateType, DateTime? from, DateTime? to}) async {
    if (dateType != null) _orderPeriod = dateType;
    if (from != null) _customFrom = from;
    if (to != null) _customTo = to;

    await _load(
      () => reportServiceInterface.getOrderReport(
        dateType: _orderPeriod,
        from: _asDate(_customFrom),
        to: _asDate(_customTo),
        offset: 1,
      ),
      (data) => _orderReport = OrderReportModel.fromJson(data),
    );
  }

  Future<void> getProductReport({String? dateType, DateTime? from, DateTime? to}) async {
    if (dateType != null) _productPeriod = dateType;
    if (from != null) _customFrom = from;
    if (to != null) _customTo = to;

    await _load(
      () => reportServiceInterface.getProductReport(
        dateType: _productPeriod,
        from: _asDate(_customFrom),
        to: _asDate(_customTo),
        offset: 1,
      ),
      (data) => _productReport = ProductReportModel.fromJson(data),
    );
  }

  Future<void> getStockReport({String? sort, int? categoryId, bool clearCategory = false}) async {
    if (sort != null) _stockSort = sort;
    if (clearCategory) {
      _stockCategoryId = null;
    } else if (categoryId != null) {
      _stockCategoryId = categoryId;
    }

    await _load(
      () => reportServiceInterface.getStockReport(
        sort: _stockSort,
        categoryId: _stockCategoryId,
        offset: 1,
      ),
      (data) => _stockReport = StockReportModel.fromJson(data),
    );
  }

  bool _isExporting = false;
  bool get isExporting => _isExporting;

  /// Downloads an export and hands it to whatever opens that file type.
  ///
  /// Returns the saved path, or null when it could not be produced — the caller
  /// reports either outcome, because a download that silently does nothing is
  /// indistinguishable from one that failed.
  Future<String?> downloadExport({
    required String uri,
    required String fileName,
    Map<String, dynamic>? queryParameters,
  }) async {
    _isExporting = true;
    notifyListeners();

    String? savedPath;
    final dynamic response = await reportServiceInterface.downloadExport(uri, queryParameters ?? <String, dynamic>{});

    if (response is ApiResponse && response.response?.statusCode == 200 && response.response?.data is List<int>) {
      savedPath = await _save(List<int>.from(response.response!.data as List<int>), fileName);
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }

    _isExporting = false;
    notifyListeners();
    return savedPath;
  }

  /// Writes the bytes somewhere the seller can find them, without overwriting an
  /// earlier export of the same report.
  Future<String?> _save(List<int> bytes, String fileName) async {
    try {
      Directory directory = Directory('/storage/emulated/0/Download');
      if (!Platform.isAndroid || !await directory.exists()) {
        directory = await getApplicationDocumentsDirectory();
      }

      final int dot = fileName.lastIndexOf('.');
      final String stem = dot > 0 ? fileName.substring(0, dot) : fileName;
      final String extension = dot > 0 ? fileName.substring(dot) : '';

      String candidate = '${directory.path}/$fileName';
      int suffix = 1;
      while (await File(candidate).exists()) {
        candidate = '${directory.path}/$stem($suffix)$extension';
        suffix++;
      }

      await File(candidate).writeAsBytes(bytes);
      return candidate;
    } catch (e) {
      debugPrint('Report export could not be saved: $e');
      return null;
    }
  }

  /// Runs a fetch and keeps whatever was already on screen if it fails.
  ///
  /// Blanking a report because one refresh was rejected is worse than showing
  /// the figures from a minute ago, and the failure is reported either way.
  Future<void> _load(Future<dynamic> Function() fetch, void Function(Map<String, dynamic>) assign) async {
    _isLoading = true;
// Called from initState of the report screens; notifying mid-build asserts.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }

    final dynamic response = await fetch();
    if (response is ApiResponse && response.response?.statusCode == 200 && response.response?.data is Map) {
      assign(Map<String, dynamic>.from(response.response!.data));
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// The server takes plain calendar dates; a timestamp would be read as one
  /// anyway, and sending the time invites a mismatch between what was asked for
  /// and what the period echoes back.
  String? _asDate(DateTime? moment) => moment == null
      ? null
      : '${moment.year.toString().padLeft(4, '0')}-'
          '${moment.month.toString().padLeft(2, '0')}-'
          '${moment.day.toString().padLeft(2, '0')}';
}