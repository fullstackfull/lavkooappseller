import 'package:flutter/foundation.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/lazy_paginated_list_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/addProduct/screens/add_product_tab_view_screen.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/localization/controllers/localization_controller.dart';
import 'package:syriacosmeticsmanger/features/product/controllers/product_controller.dart';
import 'package:syriacosmeticsmanger/features/profile/controllers/profile_controller.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/images.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/no_data_screen.dart';
import 'package:syriacosmeticsmanger/features/order/screens/order_screen.dart';
import 'package:syriacosmeticsmanger/features/shop/widgets/animated_floating_button_widget.dart';
import 'package:syriacosmeticsmanger/features/shop/widgets/shop_product_card_widget.dart';
import 'package:syriacosmeticsmanger/features/product/screens/stock_out_product_screen.dart';
import 'package:syriacosmeticsmanger/core/animations/app_animations.dart';

class ProductViewWidget extends StatefulWidget {
  final int? sellerId;
  final bool fromNotification;
  final double keyboardHeight;
  const ProductViewWidget({super.key, required this.sellerId, this.fromNotification = false, required this.keyboardHeight});

  @override
  State<ProductViewWidget> createState() => _ProductViewWidgetState();
}

class _ProductViewWidgetState extends State<ProductViewWidget> {
  ScrollController scrollController = ScrollController();
  String message = "";
  bool activated = false;
  bool endScroll = false;
  void _scrollListener() {
    if (scrollController.offset >= scrollController.position.maxScrollExtent && !scrollController.position.outOfRange) {
      setState(() {
        endScroll = true;
        message = "bottom";
        if (kDebugMode) {
          print('=========$message=========');
        }
      });
    }else{
      if(endScroll) {
        setState(() {
          endScroll = false;
        });
      }
    }
  }

  @override
  void dispose() {
    scrollController.removeListener(_scrollListener);
    scrollController.dispose();
    super.dispose();
  }

  int? userId;

  @override
  void initState() {
    scrollController = ScrollController();
    scrollController.addListener(_scrollListener);
    userId = Provider.of<ProfileController>(context, listen: false).userId;
    if(widget.fromNotification) {
      Provider.of<ProductController>(context, listen: false).emptySellerProduct();
      Provider.of<ProfileController>(context, listen: false).getSellerInfo().then((responce) {
        if(responce.isSuccess) {
          userId = Provider.of<ProfileController>(Get.context!, listen: false).userId;
          Provider.of<ProductController>(Get.context!, listen: false).getSellerProductList(
            Provider.of<ProfileController>(Get.context!, listen: false).userId.toString(), 1,
            Provider.of<LocalizationController>(Get.context!, listen: false).locale.languageCode == 'US' ? 'en':
            LocalizationController.apiLanguageCode(Get.context!),''
          );
        } else {
          Provider.of<ProductController>(Get.context!, listen: false).getSellerProductList(
            Provider.of<ProfileController>(Get.context!, listen: false).userId.toString(), 1,
            Provider.of<LocalizationController>(Get.context!, listen: false).locale.languageCode == 'US' ? 'en':
            LocalizationController.apiLanguageCode(Get.context!),''
          );
        }
      });
    } else {
      Provider.of<ProductController>(context, listen: false).getSellerProductList(
        Provider.of<ProfileController>(context, listen: false).userId.toString(), 1,
        Provider.of<LocalizationController>(context, listen: false).locale.languageCode == 'US'?'en':
        LocalizationController.apiLanguageCode(context),''
      );
    }
    super.initState();
  }



  @override
  Widget build(BuildContext context) {
    String userId = Provider.of<ProfileController>(context, listen: false).userId.toString();

    return RefreshIndicator(
      onRefresh: () async {
        Provider.of<ProductController>(context, listen: false).getSellerProductList(
          Provider.of<ProfileController>(context, listen: false).userId.toString(), 1,
          Provider.of<LocalizationController>(context, listen: false).locale.languageCode == 'US'?'en':
          LocalizationController.apiLanguageCode(context), '', filterSearchModel: Provider.of<ProductController>(context, listen: false).filterModel
        );
      },
      child: Consumer<ProductController>(
        builder: (context, prodProvider, child) {
          return SizedBox(height: MediaQuery.of(context).size.height,
            child: Stack(
              children: [
                (prodProvider.sellerProductModel != null) ? (prodProvider.sellerProductModel!.products != null && prodProvider.sellerProductModel!.products!.isNotEmpty) ?
                  NotificationListener<ScrollNotification>(
                    onNotification: (scrollNotification) {
                      return false;
                    },
                    child: LazyPaginatedListView(
                        scrollController: scrollController,
                        pageSize: 20,
                        totalSize: prodProvider.sellerProductModel?.totalSize,
                        offset: prodProvider.sellerProductModel != null ? int.tryParse(prodProvider.sellerProductModel!.offset.toString()) : null,
                        padding: const EdgeInsets.only(bottom: Dimensions.floatingNavClearance),
                        itemCount: prodProvider.sellerProductModel!.products!.length,
                        onPaginate: (int offset) async {
                          // Later pages must repeat the exact query of page 1 —
                          // the applied filter AND the search text — or the
                          // list silently switches result sets mid-scroll.
                          await prodProvider.getSellerProductList(
                            userId, offset, LocalizationController.apiLanguageCode(context),
                            prodProvider.sellerProductModel?.search ?? '',
                            filterSearchModel: prodProvider.filterModel.copyWith(reload: false),
                          );
                        },

                        itemBuilder: (BuildContext context, int index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall),
                            child: ShopProductWidget(productModel: prodProvider.sellerProductModel!.products![index]),
                          ).animateListEntrance(index);
                        },
                    ),
                  ) : const NoDataScreen() : const OrderShimmer(),


               if(widget.keyboardHeight == 0)...[
                 if(!endScroll)
                   Positioned(
                     bottom: 20,
                     right: Provider.of<LocalizationController>(context, listen: false).isLtr ? 20: null,
                     left: Provider.of<LocalizationController>(context, listen: false).isLtr ? null: 20,
                     child: Align(
                       alignment: AlignmentDirectional.bottomEnd,
                       child: ScrollingFabAnimated(
                         width: 150,
                         color: Theme.of(context).cardColor,
                         icon: SizedBox(width: Dimensions.iconSizeExtraLarge,child: Image.asset(Images.addIcon)),
                         text: Text(getTranslated('add_new', context)!, style: robotoRegular.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color),),
                         onPress: (){
                           Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddProductTabView(product: null, addProduct: null, fromHome: false,)));
                         },
                         animateIcon: true,
                         inverted: false,
                         scrollController: scrollController,
                         radius: 10.0,
                       ),
                     ),
                   ),

                 if(!endScroll)
                   Positioned(bottom: 100,
                     right: Provider.of<LocalizationController>(context, listen: false).isLtr ? 22: null,
                     left: Provider.of<LocalizationController>(context, listen: false).isLtr ? null: 22,
                     child: ScrollingFabAnimated(width: 200, color: Theme.of(context).cardColor,
                       icon: SizedBox(width: Dimensions.iconSizeExtraLarge,child: Image.asset(Images.limitedStockIcon)),
                       text: Text(getTranslated('limited_stocks', context)!, style: robotoRegular.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color),),
                       onPress: () {
                         Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StockOutProductScreen()));
                       },
                       animateIcon: true,
                       inverted: false,
                       scrollController: scrollController,
                       radius: 10.0,
                     ),
                   ),
               ],
              ],
            ),
          );
        },
      ),
    );
  }
}

