import 'package:syriacosmeticsmanger/features/product/domain/models/filter_model.dart';

abstract class BulkJobServiceInterface {
  Future getBulkJobs({int offset = 1});

  Future getBulkJob(int id);

  Future submitPriceUpdate({
    required List<int> productIds,
    required String mode,
    required num value,
    num? discount,
    String? discountType,
  });

  Future submitStockUpdate({
    required List<int> productIds,
    required String mode,
    required int value,
    String? note,
  });

  Future downloadFailures(int id);

  /// The products to choose from, read through the same repository the product
  /// list screen uses so the two cannot show different catalogues.
  Future getSellerProductList({
    required String sellerId,
    required int offset,
    required String languageCode,
    required String search,
    FilterModel? filterModel,
  });
}
