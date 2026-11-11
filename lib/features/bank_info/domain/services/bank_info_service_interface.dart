import 'package:syriacosmeticsmanger/features/profile/domain/models/profile_body.dart';
import 'package:syriacosmeticsmanger/features/profile/domain/models/profile_info.dart';

abstract class BankInfoServiceInterface {
  Future<dynamic> getBankList();
  Future<dynamic> updateBank(ProfileInfoModel userInfoModel, ProfileBody seller, String token);
  String getBankToken();
}