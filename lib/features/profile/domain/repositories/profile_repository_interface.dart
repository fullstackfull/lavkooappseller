import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:syriacosmeticsmanger/features/profile/domain/models/profile_body.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/profile/domain/models/profile_info.dart';
import 'package:syriacosmeticsmanger/interface/repository_interface.dart';

abstract class ProfileRepositoryInterface implements RepositoryInterface{
  Future<ApiResponse> getSellerInfo();
  Future<http.StreamedResponse> updateProfile(ProfileInfoModel userInfoModel, ProfileBody seller,  File? file, String token, String password);
  Future<ApiResponse> deleteUserAccount();
}