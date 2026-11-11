import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/localization/controllers/localization_controller.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/product/controllers/product_controller.dart';
import 'package:syriacosmeticsmanger/features/product/domain/models/filter_model.dart';
import 'package:syriacosmeticsmanger/features/profile/controllers/profile_controller.dart';
import 'package:syriacosmeticsmanger/features/review/controllers/product_review_controller.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/paginated_list_view_widget.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

class ReviewProductFilterWidget extends StatefulWidget {
  const ReviewProductFilterWidget({super.key});

  @override
  State<ReviewProductFilterWidget> createState() => _ReviewProductFilterWidgetState();
}

class _ReviewProductFilterWidgetState extends State<ReviewProductFilterWidget> {

  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .65,
        child: Consumer<ProductController>(
          builder: (context, productProvider, _) {

            final products = productProvider.sellerProductModel?.products ?? [];

            return SingleChildScrollView(
              controller: _scrollController,
              child: PaginatedListViewWidget(
                scrollController: _scrollController,
                onPaginate: (int? offset) async {
                  await productProvider.getSellerProductList(
                    Provider.of<ProfileController>(context, listen: false).userInfoModel!.id.toString(), offset!, LocalizationController.apiLanguageCode(context), '',
                    filterSearchModel: FilterModel(
                      reload: false,
                    ),
                  );
                },

                totalSize: productProvider.sellerProductModel?.totalSize,
                offset: productProvider.sellerProductModel?.offset,
                itemView: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(products.length, (index) {
                    final product = products[index];
                    return InkWell(
                      onTap: () {
                        Provider.of<ProductReviewController>(context, listen: false).setReviewProductIndex(index, product.id, product.name, true);
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.only(left: Dimensions.paddingSizeSmall, top: Dimensions.paddingSizeSmall, bottom: Dimensions.paddingSizeSmall),
                            child: Text(
                              product.name ?? '',
                              style: robotoRegular.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Divider(color: Theme.of(context).hintColor)
                        ],
                      ),
                    );
                  }),
                ),

              ),
            );
          },
        ),
      ),
    );
  }
}
