

import 'package:flutter/cupertino.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/interface/repository_interface.dart';

abstract class SplashRepositoryInterface implements RepositoryInterface{
  Future<ApiResponse> getConfig();
  Future<dynamic> getBusinessPages(String type);
  void initSharedData();
  String getCurrency();
  void setCurrency(String currencyCode);
  void setShippingType(String shippingType);
  Future<ApiResponse> getShippingTypeList(BuildContext context, String type);
}