import 'package:syriacosmeticsmanger/features/bulk_jobs/domain/repositories/bulk_job_repository_interface.dart';
import 'package:syriacosmeticsmanger/features/bulk_jobs/domain/services/bulk_job_service_interface.dart';
import 'package:syriacosmeticsmanger/features/product/domain/models/filter_model.dart';
import 'package:syriacosmeticsmanger/features/product/domain/repositories/product_repository_interface.dart';

class BulkJobService implements BulkJobServiceInterface {
  final BulkJobRepositoryInterface bulkJobRepoInterface;
  final ProductRepositoryInterface productRepoInterface;
  BulkJobService({required this.bulkJobRepoInterface, required this.productRepoInterface});

  @override
  Future getBulkJobs({int offset = 1}) => bulkJobRepoInterface.getBulkJobs(offset: offset);

  @override
  Future getBulkJob(int id) => bulkJobRepoInterface.getBulkJob(id);

  @override
  Future submitPriceUpdate({
    required List<int> productIds,
    required String mode,
    required num value,
    num? discount,
    String? discountType,
  }) =>
      bulkJobRepoInterface.submitPriceUpdate(
        productIds: productIds,
        mode: mode,
        value: value,
        discount: discount,
        discountType: discountType,
      );

  @override
  Future submitStockUpdate({
    required List<int> productIds,
    required String mode,
    required int value,
    String? note,
  }) =>
      bulkJobRepoInterface.submitStockUpdate(productIds: productIds, mode: mode, value: value, note: note);

  @override
  Future downloadFailures(int id) => bulkJobRepoInterface.downloadFailures(id);

  @override
  Future getSellerProductList({
    required String sellerId,
    required int offset,
    required String languageCode,
    required String search,
    FilterModel? filterModel,
  }) =>
      productRepoInterface.getSellerProductList(
        sellerId: sellerId,
        offset: offset,
        languageCode: languageCode,
        search: search,
        filterModel: filterModel,
      );
}
