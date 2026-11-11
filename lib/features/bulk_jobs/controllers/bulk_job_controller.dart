import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/bulk_jobs/domain/models/bulk_job_models.dart';
import 'package:syriacosmeticsmanger/features/bulk_jobs/domain/services/bulk_job_service_interface.dart';
import 'package:syriacosmeticsmanger/features/product/domain/models/product_model.dart';
import 'package:syriacosmeticsmanger/helper/api_checker.dart';

/// Choosing products, changing them together, and reading the receipt.
///
/// The selection is kept as ids rather than as products, so it survives paging
/// and searching: a seller who picks four products, searches for something else
/// and picks two more has chosen six, not two. The chosen products are kept
/// alongside only so the confirmation screen can name them.
class BulkJobController with ChangeNotifier {
  final BulkJobServiceInterface bulkJobServiceInterface;
  BulkJobController({required this.bulkJobServiceInterface});

  final List<Product> _products = <Product>[];
  List<Product> get products => _products;

  final Map<int, Product> _selected = <int, Product>{};
  List<Product> get selectedProducts => _selected.values.toList();
  List<int> get selectedIds => _selected.keys.toList();
  int get selectedCount => _selected.length;

  bool isSelected(int? id) => id != null && _selected.containsKey(id);

  int _page = 1;
  int _totalSize = 0;
  int get totalSize => _totalSize;
  bool get hasMore => _products.length < _totalSize;

  String _search = '';
  String get search => _search;

  bool _isLoadingProducts = false;
  bool get isLoadingProducts => _isLoadingProducts;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  bool _isLoadingJobs = false;
  bool get isLoadingJobs => _isLoadingJobs;

  bool _isExporting = false;
  bool get isExporting => _isExporting;

  BulkJobListModel? _jobList;
  BulkJobListModel? get jobList => _jobList;

  BulkJobModel? _job;
  BulkJobModel? get job => _job;

  void toggle(Product product) {
    final int? id = product.id;
    if (id == null) return;

    if (_selected.containsKey(id)) {
      _selected.remove(id);
    } else {
      _selected[id] = product;
    }
    notifyListeners();
  }

  /// Adds every product currently loaded, without clearing what was chosen on an
  /// earlier page. "Select all" on a paged list can only honestly mean the rows
  /// the seller can see.
  void selectLoaded() {
    for (final Product product in _products) {
      if (product.id != null) _selected[product.id!] = product;
    }
    notifyListeners();
  }

  void clearSelection() {
    _selected.clear();
    notifyListeners();
  }

  Future<void> getProducts({
    required String sellerId,
    required String languageCode,
    String? search,
    bool reload = true,
  }) async {
    if (reload) {
      _page = 1;
      _products.clear();
    } else if (!hasMore || _isLoadingProducts) {
      return;
    }

    if (search != null) _search = search;

    _isLoadingProducts = true;
    notifyListeners();

    final dynamic response = await bulkJobServiceInterface.getSellerProductList(
      sellerId: sellerId,
      offset: _page,
      languageCode: languageCode,
      search: _search,
    );

    if (response is ApiResponse && response.response?.statusCode == 200 && response.response?.data is Map) {
      final ProductModel page = ProductModel.fromJson(Map<String, dynamic>.from(response.response!.data));
      _totalSize = page.totalSize ?? 0;
      _products.addAll(page.products ?? <Product>[]);
      _page++;
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }

    _isLoadingProducts = false;
    notifyListeners();
  }

  /// Submits a price change and reads the receipt back.
  ///
  /// Returns the finished job, or null when the request itself was refused. The
  /// caller shows the receipt either way — a bulk change that silently does
  /// nothing is indistinguishable from one that failed.
  Future<BulkJobModel?> submitPriceUpdate({
    required String mode,
    required num value,
    num? discount,
    String? discountType,
  }) =>
      _submit(() => bulkJobServiceInterface.submitPriceUpdate(
            productIds: selectedIds,
            mode: mode,
            value: value,
            discount: discount,
            discountType: discountType,
          ));

  Future<BulkJobModel?> submitStockUpdate({
    required String mode,
    required int value,
    String? note,
  }) =>
      _submit(() => bulkJobServiceInterface.submitStockUpdate(
            productIds: selectedIds,
            mode: mode,
            value: value,
            note: note,
          ));

  Future<void> getBulkJobs({int offset = 1}) async {
    _isLoadingJobs = true;
    notifyListeners();

    final dynamic response = await bulkJobServiceInterface.getBulkJobs(offset: offset);
    if (response is ApiResponse && response.response?.statusCode == 200 && response.response?.data is Map) {
      _jobList = BulkJobListModel.fromJson(Map<String, dynamic>.from(response.response!.data));
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }

    _isLoadingJobs = false;
    notifyListeners();
  }

  Future<BulkJobModel?> getBulkJob(int id, {bool notify = true}) async {
    final dynamic response = await bulkJobServiceInterface.getBulkJob(id);

    if (response is ApiResponse && response.response?.statusCode == 200 && response.response?.data is Map) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(response.response!.data);
      _job = BulkJobModel.fromJson(Map<String, dynamic>.from(data['job'] as Map));
      if (notify) notifyListeners();
      return _job;
    }

    if (response is ApiResponse) ApiChecker.checkApi(response);
    return null;
  }

  /// Downloads the refused rows and returns where they were saved, or null when
  /// the file could not be produced.
  Future<String?> downloadFailures(int id) async {
    _isExporting = true;
    notifyListeners();

    String? savedPath;
    final dynamic response = await bulkJobServiceInterface.downloadFailures(id);

    if (response is ApiResponse && response.response?.statusCode == 200 && response.response?.data is List<int>) {
      savedPath = await _save(List<int>.from(response.response!.data as List<int>), 'bulk-job-$id-failures.csv');
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }

    _isExporting = false;
    notifyListeners();
    return savedPath;
  }

  Future<BulkJobModel?> _submit(Future<dynamic> Function() send) async {
    _isSubmitting = true;
    _job = null;
    notifyListeners();

    BulkJobModel? result;
    final dynamic response = await send();

    if (response is ApiResponse && (response.response?.statusCode == 202 || response.response?.statusCode == 200) && response.response?.data is Map) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(response.response!.data);
      result = BulkJobModel.fromJson(Map<String, dynamic>.from(data['job'] as Map));
      result = await _awaitCompletion(result);
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }

    _job = result;
    _isSubmitting = false;
    notifyListeners();
    return result;
  }

  /// Waits for the job to finish, within reason.
  ///
  /// A queue worker usually finishes a bulk pass in seconds, but the screen must
  /// not hang on one that does not. After the attempts run out the job is
  /// returned as it stands and the receipt shows it still running — which is the
  /// truth, and the job list will show the outcome later.
  Future<BulkJobModel> _awaitCompletion(BulkJobModel job) async {
    BulkJobModel current = job;

    for (int attempt = 0; attempt < 10 && current.isRunning; attempt++) {
      await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      final BulkJobModel? refreshed = await getBulkJob(current.id, notify: false);
      if (refreshed == null) break;
      current = refreshed;
    }

    return current;
  }

  /// Writes the file somewhere the seller can find it, without overwriting an
  /// earlier download of the same job.
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
      debugPrint('Bulk failure list could not be saved: $e');
      return null;
    }
  }
}
