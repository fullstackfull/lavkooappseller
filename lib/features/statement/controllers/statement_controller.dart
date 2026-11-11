import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/statement/domain/models/statement_models.dart';
import 'package:syriacosmeticsmanger/features/statement/domain/services/statement_service_interface.dart';
import 'package:syriacosmeticsmanger/helper/api_checker.dart';

/// The seller's account, line by line.
///
/// The filter narrows the list and the range totals; it never touches the
/// account balances, which the server keeps whole for exactly that reason.
class StatementController with ChangeNotifier {
  final StatementServiceInterface statementServiceInterface;
  StatementController({required this.statementServiceInterface});

  StatementModel? _statement;
  StatementModel? get statement => _statement;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isExporting = false;
  bool get isExporting => _isExporting;

  String? _entryType;
  String? get entryType => _entryType;

  String? _status;
  String? get status => _status;

  DateTime? _from;
  DateTime? get from => _from;

  DateTime? _to;
  DateTime? get to => _to;

  List<StatementEntryModel> get entries => _statement?.entries ?? const <StatementEntryModel>[];
  StatementSummaryModel get summary => _statement?.summary ?? const StatementSummaryModel();

  Future<void> getStatement({
    String? entryType,
    String? status,
    DateTime? from,
    DateTime? to,
    bool clearEntryType = false,
    bool clearStatus = false,
    bool clearDates = false,
  }) async {
    if (clearEntryType) {
      _entryType = null;
    } else if (entryType != null) {
      _entryType = entryType;
    }
    if (clearStatus) {
      _status = null;
    } else if (status != null) {
      _status = status;
    }
    if (clearDates) {
      _from = null;
      _to = null;
    } else {
      if (from != null) _from = from;
      if (to != null) _to = to;
    }

    _isLoading = true;
    notifyListeners();

    final dynamic response = await statementServiceInterface.getStatement(
      entryType: _entryType,
      status: _status,
      from: _asDate(_from),
      to: _asDate(_to),
    );

    if (response is ApiResponse && response.response?.statusCode == 200 && response.response?.data is Map) {
      _statement = StatementModel.fromJson(Map<String, dynamic>.from(response.response!.data));
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Downloads the statement and returns where it was saved, or null when it
  /// could not be produced — the caller reports either outcome, because a
  /// download that silently does nothing looks the same as one that failed.
  Future<String?> exportStatement() async {
    _isExporting = true;
    notifyListeners();

    String? savedPath;
    final dynamic response = await statementServiceInterface.exportStatement(
      entryType: _entryType,
      status: _status,
      from: _asDate(_from),
      to: _asDate(_to),
    );

    if (response is ApiResponse && response.response?.statusCode == 200 && response.response?.data is List<int>) {
      savedPath = await _save(List<int>.from(response.response!.data as List<int>), 'statement.csv');
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }

    _isExporting = false;
    notifyListeners();
    return savedPath;
  }

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
      debugPrint('Statement export could not be saved: $e');
      return null;
    }
  }

  /// The server takes plain calendar dates; sending a timestamp invites a
  /// mismatch between what was asked for and what comes back.
  String? _asDate(DateTime? moment) => moment == null
      ? null
      : '${moment.year.toString().padLeft(4, '0')}-'
          '${moment.month.toString().padLeft(2, '0')}-'
          '${moment.day.toString().padLeft(2, '0')}';
}
