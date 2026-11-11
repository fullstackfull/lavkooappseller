import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';

abstract class ReturnRepositoryInterface {
  Future<ApiResponse> getReturns({String? status, int offset = 1});

  Future<ApiResponse> getReturn(int id);

  Future<ApiResponse> markInTransit(int id, {String? carrier, String? trackingNumber});

  /// `restock` is decided here rather than when the return was opened: nobody
  /// knows whether goods are sellable until they are looked at.
  Future<ApiResponse> receive(int id, {required bool restock});

  Future<ApiResponse> reject(int id, {required String reason});
}
