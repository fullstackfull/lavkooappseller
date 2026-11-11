import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';

abstract class StatementRepositoryInterface {
  Future<ApiResponse> getStatement({String? entryType, String? status, String? from, String? to, int offset = 1});

  /// The same lines as a file, so a payout can be reconciled in a spreadsheet
  /// rather than on a phone screen.
  Future<ApiResponse> exportStatement({String? entryType, String? status, String? from, String? to});
}
