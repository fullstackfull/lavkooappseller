import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/interface/repository_interface.dart';

abstract class VatRepositoryInterface implements RepositoryInterface {

  Future<ApiResponse> getVatReport(int? limit, int? offset, String? startDate, String? endDate);

}