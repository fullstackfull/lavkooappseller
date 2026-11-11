import 'package:http/http.dart' as http;
import 'package:syriacosmeticsmanger/features/profile/domain/models/profile_body.dart';
import 'package:syriacosmeticsmanger/features/profile/domain/models/profile_info.dart';
import 'package:syriacosmeticsmanger/interface/repository_interface.dart';

abstract class BankInfoRepositoryInterface implements RepositoryInterface{
  Future<http.StreamedResponse> updateBank(ProfileInfoModel userInfoModel, ProfileBody seller, String token);
  String getBankToken();
}