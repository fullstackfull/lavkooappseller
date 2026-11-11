import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/features/profile/domain/models/profile_body.dart';
import 'package:syriacosmeticsmanger/data/model/response/response_model.dart';
import 'package:syriacosmeticsmanger/features/bank_info/domain/services/bank_info_service_interface.dart';
import 'package:syriacosmeticsmanger/features/profile/domain/models/profile_info.dart';

class BankInfoController extends ChangeNotifier {
  final BankInfoServiceInterface bankInfoServiceInterface;

  BankInfoController({required this.bankInfoServiceInterface});

  ProfileInfoModel? _bankInfo;
  ProfileInfoModel? get bankInfo => _bankInfo;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _showWarning = true;
  bool get showWarning => _showWarning;

  void setBankInfo(ProfileInfoModel? info) {
    if (info == null) return;
    _bankInfo = info;
    notifyListeners();
  }

  /// The bank details, or an empty set of them.
  ///
  /// Screens read these fields straight off, so handing them a null after a
  /// failed fetch only moves the crash one line down. Empty details render as
  /// empty fields, which is what "we could not load them" should look like.
  ProfileInfoModel get bankInfoOrEmpty => _bankInfo ?? ProfileInfoModel();

  Future<void> getBankInfo(BuildContext context) async {
    final dynamic result = await bankInfoServiceInterface.getBankList();
    // A failed fetch leaves whatever was loaded before in place rather than
    // blanking the screen.
    if (result is ProfileInfoModel) {
      _bankInfo = result;
    }
    notifyListeners();
  }

  Future<ResponseModel?> updateBankInfo(BuildContext context,ProfileInfoModel updateUserModel, ProfileBody seller, String token) async {
    _isLoading = true;
    notifyListeners();
    ResponseModel responseModel = await bankInfoServiceInterface.updateBank(updateUserModel, seller, token);
    _isLoading = false;
    notifyListeners();
    return responseModel;
  }

  String getBankToken() {
    return bankInfoServiceInterface.getBankToken();
  }

  void setWarningValue(bool showWarning, {bool isUpdate = false}) {
    _showWarning = showWarning;
    if(isUpdate) {
      notifyListeners();
    }
  }
}
