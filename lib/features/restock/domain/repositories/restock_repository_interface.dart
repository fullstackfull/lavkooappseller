
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/product/domain/models/product_model.dart';
import 'package:syriacosmeticsmanger/interface/repository_interface.dart';

abstract class RestockRepositoryInterface<T> extends RepositoryInterface{

  Future<dynamic> getRestockProductList(Map<dynamic, dynamic> data);

  Future<dynamic> getRestockBrandList();

  Future<dynamic> deleteRestockItem(int id);


  Future<ApiResponse> updateRestockProductQuantity(int? productId,int currentStock, List <Variation> variation);

  Future<ApiResponse> updateProductQuantity(int? productId,int currentStock, List <Variation> variation);

}