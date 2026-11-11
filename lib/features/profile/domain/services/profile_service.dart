import 'dart:io';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_snackbar_widget.dart';
import 'package:syriacosmeticsmanger/features/profile/domain/models/profile_body.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/profile/domain/models/profile_info.dart';
import 'package:syriacosmeticsmanger/features/profile/domain/repositories/profile_repository_interface.dart';
import 'package:syriacosmeticsmanger/features/profile/domain/services/profice_service_interface.dart';
import 'package:syriacosmeticsmanger/helper/api_checker.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';

class ProfileService implements ProfileServiceInterface{
  final ProfileRepositoryInterface profileRepoInterface;
  ProfileService({required this.profileRepoInterface});

  @override
  Future deleteUserAccount() async{
    ApiResponse apiResponse = await profileRepoInterface.deleteUserAccount();
    if(apiResponse.error == 'ongoing_order_left' || apiResponse.error == 'admin_commission_not_paid' || apiResponse.error == 'delivery_man_transaction_left'){
      return apiResponse;
    } else if (apiResponse.response?.statusCode == 200) {
      Map map = apiResponse.response!.data;
      String? message = map ['message'];
      showCustomSnackBarWidget(message, Get.context!, isToaster: true, isError: false);
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
  Future getSellerInfo() {
    return profileRepoInterface.getSellerInfo();
  }


  @override
  Future updateProfile(ProfileInfoModel userInfoModel, ProfileBody seller, File? file, String token, String password) {
    return profileRepoInterface.updateProfile(userInfoModel, seller, file, token, password);
  }

}