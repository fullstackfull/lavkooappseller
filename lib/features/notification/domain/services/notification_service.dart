import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/data/model/response/response_model.dart';
import 'package:syriacosmeticsmanger/features/notification/domain/repositories/notification_repository_interface.dart';
import 'package:syriacosmeticsmanger/features/notification/domain/services/notification_service_interface.dart';
import 'package:syriacosmeticsmanger/helper/api_checker.dart';

class NotificationService implements NotificationServiceInterface{
  final NotificationRepositoryInterface notificationRepoInterface;
  NotificationService({required this.notificationRepoInterface});


  @override
  Future getNotificationList(int offset) async{
    return await notificationRepoInterface.getList(offset: offset);
  }

  @override
  Future seenNotification(int id) async{
    ApiResponse response = await notificationRepoInterface.seenNotification(id);
    if(response.response?.statusCode == 200) {
        return ResponseModel(true, '');
    }else{
      ApiChecker.checkApi(response);
      // Returned, not dropped: the caller declares a ResponseModel, so falling
      // off the end here crashed on a failure this branch had already handled.
      return ResponseModel(false, '${response.error ?? ''}');
    }
  }
}