import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/features/product/domain/models/product_model.dart';
import 'package:syriacosmeticsmanger/features/product/controllers/product_controller.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/paginated_list_view_widget.dart';
import 'package:syriacosmeticsmanger/features/pos/widgets/pos_product_card_widget.dart';

class PosProductListWidget extends StatelessWidget {
  final List<Product>? productList;
  final ScrollController? scrollController;
  final ProductController? productProvider;
  const PosProductListWidget({super.key, this.productList, this.scrollController, this.productProvider});

  @override
  Widget build(BuildContext context) {
    return PaginatedListViewWidget(
        reverse: true,
        scrollController: scrollController,
        totalSize: productProvider!.posProductModel?.totalSize,
        offset: productProvider!.posProductModel != null ? int.parse(productProvider!.posProductModel!.offset.toString()) : null,
        onPaginate: (int? offset) async {
          await productProvider!.getPosProductList(offset!, context, productProvider!.posSelectedCategoryIds, reload: false);
        },
        itemView: ListView.builder(
          itemCount: productList!.length,
          padding: const EdgeInsets.all(0),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemBuilder: (BuildContext context, int index) {
            return POSProductWidget(productModel: productList![index], index: index,);
          },
        ),
      );
  }
}
