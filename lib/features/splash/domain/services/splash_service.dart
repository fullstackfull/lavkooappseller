import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/splash/domain/repositories/splash_repository_interface.dart';
import 'package:syriacosmeticsmanger/features/splash/domain/services/splash_service_interface.dart';
import 'package:syriacosmeticsmanger/helper/api_checker.dart';

class SplashService implements SplashServiceInterface{
  final SplashRepositoryInterface splashRepoInterface;
  SplashService({required this.splashRepoInterface});

  @override
  Future getConfig() {
   return splashRepoInterface.getConfig();
  }

  @override
  Future getBusinessPages(String type) {
    return splashRepoInterface.getBusinessPages(type);
  }

  @override
  String getCurrency() {
    return splashRepoInterface.getCurrency();
  }

  @override
  Future getShippingTypeList(BuildContext context, String type) async{
    ApiResponse apiResponse = await splashRepoInterface.getShippingTypeList(context, type);
    if (apiResponse.response != null && apiResponse.response!.statusCode == 200) {
     return apiResponse;
    } else {
      ApiChecker.checkApi(apiResponse);
      // Returned, not dropped: falling off the end handed the caller a
      // null where it declared an ApiResponse, turning a handled API
      // error into a crash.
      return apiResponse;
    }
  }

  @override
  void initSharedData() {
    return splashRepoInterface.initSharedData();
  }

  @override
  void setCurrency(String currencyCode) {
   return splashRepoInterface.setCurrency(currencyCode);
  }

  @override
  void setShippingType(String shippingType) {
    return splashRepoInterface.setShippingType(shippingType);
  }
}