
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/interface/repository_interface.dart';

abstract class RefundRepositoryInterface implements RepositoryInterface{
  Future<ApiResponse> getRefundReqDetails(int? orderDetailsId);
  Future<ApiResponse> refundStatus(int? refundId , String status, String note);
  Future<ApiResponse> getRefundStatusList(String type);
  Future<ApiResponse> getSingleRefundModel(int? refundId);
  Future<ApiResponse> getRefundList(String? status, String? startDate, String? endDate);
}