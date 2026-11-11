
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/interface/repository_interface.dart';

abstract class BarcodeRepositoryInterface implements RepositoryInterface{
  Future<ApiResponse> barCodeDownLoad(int? id, int quantity);
}