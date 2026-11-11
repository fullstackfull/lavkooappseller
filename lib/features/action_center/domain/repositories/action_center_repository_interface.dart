import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';

abstract class ActionCenterRepositoryInterface {
  Future<ApiResponse> getInsights({String? severity, int limit = 50});

  Future<ApiResponse> dismiss(int id);
}
