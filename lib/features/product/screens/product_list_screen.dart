import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/filter_icon_widget.dart';
import 'package:syriacosmeticsmanger/features/dashboard/screens/dashboard_screen.dart';
import 'package:syriacosmeticsmanger/features/product/domain/models/product_model.dart';
import 'package:syriacosmeticsmanger/features/product/widgets/product_filter_bottomsheet_widget.dart';
import 'package:syriacosmeticsmanger/features/product/widgets/status_filter_widget.dart';
import 'package:syriacosmeticsmanger/helper/debounce_helper.dart';
import 'package:syriacosmeticsmanger/localization/controllers/localization_controller.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/features/product/controllers/product_controller.dart';
import 'package:syriacosmeticsmanger/features/profile/controllers/profile_controller.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/images.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_search_field_widget.dart';
import 'package:syriacosmeticsmanger/features/product/widgets/product_widget.dart';

class ProductListMenuScreen extends StatefulWidget {
  final bool fromNotification;

  /// True when hosted as a dashboard tab: no PopScope (the shell owns back
  /// handling) and no back arrow in the app bar.
  final bool isTab;
  const ProductListMenuScreen({super.key,  this.fromNotification = false, this.isTab = false});
  @override
  State<ProductListMenuScreen> createState() => _ProductListMenuScreenState();
}

class _ProductListMenuScreenState extends State<ProductListMenuScreen> {
  final DebounceHelper _debounce = DebounceHelper(milliseconds: 500);
  TextEditingController searchController = TextEditingController();
  int? userId;




  void _getBrandList() {
    String languageCode = LocalizationController.apiLanguageCode(context);
    Provider.of<ProductController>(Get.context!,listen: false).getBrandList(Get.context!, languageCode);
  }


  @override
  void initState() {
    userId = Provider.of<ProfileController>(context, listen: false).userId;
    Provider.of<ProductController>(context, listen: false).clearFilterData();
    _getBrandList();
    super.initState();
  }

  @override
  void dispose() {
    _debounce.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.isTab,
      onPopInvokedWithResult: (didPop, _) async {
        // As a tab this widget stays mounted inside the dashboard's
        // IndexedStack; back handling belongs to the shell alone there.
        if(widget.isTab || didPop) return;
        if(widget.fromNotification) {
          Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(
            builder: (BuildContext context) => const DashboardScreen(),
          ), (route) => false);
        } else {
          Navigator.of(context).pop();
        }
      },

      child: Scaffold(
        appBar: CustomAppBarWidget(
          title: getTranslated('product_list', context),
          isBackButtonExist: !widget.isTab,
          onBackPressed: () {
            if(widget.fromNotification) {
              Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (BuildContext context) => const DashboardScreen()), (route) => false);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.only(top : Dimensions.paddingSizeMedium),
            color: Theme.of(context).cardColor,
            child: StatusFilterWidget(
              onFilterChanged: (index) {},
            ),
          ),

          SizedBox(height: 80,
            child: Consumer<ProductController>(
              builder: (context, productController, _) {
                return Container(
                  color: Theme.of(context).cardColor,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeMedium, vertical: Dimensions.paddingSizeExtraSmall),
                    child: Row(
                      children: [
                        Expanded(
                          child: CustomSearchFieldWidget(
                            controller: searchController,
                            hint: getTranslated('search_by_product_name', context),
                            prefix: Images.iconsSearch,
                            iconPressed: () => (){},
                            onSubmit: (text) => (){},
                            onChanged: (value)=> _debounce.run(() async {
                              productController.getSellerProductList(
                                userId.toString(), 1, LocalizationController.apiLanguageCode(context), value,
                                filterSearchModel: productController.filterModel.copyWith(reload: true),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(width: Dimensions.paddingSize),

                        ///filter Icon
                        FilterIconWidget(
                          filterCount: _getFilterCount(productController.sellerProductModel),
                          onTap: productController.sellerProductModel == null ? null : () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (builder) => const ProductFilterBottomSheet(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }
            )
          ),
          const SizedBox(height: Dimensions.paddingSize),

          Expanded(child: ProductViewWidget(
           sellerId: userId,
           fromNotification: widget.fromNotification,
           keyboardHeight: MediaQuery.of(context).viewInsets.bottom,
          ))

          ],
        ),
      ),
    );
  }

  int _getFilterCount(ProductModel? sellerProductModel) {
    if (sellerProductModel == null) return 0;
    final int nonNullFilterCount = [
      sellerProductModel.productType,
      sellerProductModel.maxPrice,
      sellerProductModel.endDate,
      sellerProductModel.status,
      sellerProductModel.isApproved,
      sellerProductModel.sorting,
      sellerProductModel.offerType,
    ].whereType<Object>().length;


    final int categoryCount = sellerProductModel.categoryIds?.length ?? 0;
    final int subCategoryCount = sellerProductModel.filterSubCategoryIds?.length ?? 0;
    final int subSubCategoryCount = sellerProductModel.filterSubSubCategoryIds?.length ?? 0;
    final int brandCount = sellerProductModel.brandIds?.length ?? 0;
    final int publisherCount = sellerProductModel.publishHouseIds?.length ?? 0;
    final int authorCount = sellerProductModel.authorIds?.length ?? 0;

    return nonNullFilterCount +
        categoryCount +
        subCategoryCount +
        subSubCategoryCount +
        brandCount +
        publisherCount +
        authorCount;
  }

}
