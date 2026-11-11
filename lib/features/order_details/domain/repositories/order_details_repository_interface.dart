import 'dart:io';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/order_details/domain/models/order_setup_model.dart';
import 'package:syriacosmeticsmanger/interface/repository_interface.dart';

abstract class OrderDetailsRepositoryInterface implements RepositoryInterface{
  Future<ApiResponse> setUpOrder(OrderSetupModel orderSetUpModel);
  Future<ApiResponse> getOrderDetails(String orderID);
  Future<ApiResponse> getOrderStatusList(String type);
  Future<ApiResponse> uploadAfterSellDigitalProduct(File? filePath, String token, String orderId);
  Future<HttpClientResponse> productDownload(String url);
  Future<dynamic> getOrderInvoice(String orderID);

  /// What the order is worth to this seller, and every recorded event on it.
  Future<ApiResponse> getOrderBreakdown(String orderID);

}