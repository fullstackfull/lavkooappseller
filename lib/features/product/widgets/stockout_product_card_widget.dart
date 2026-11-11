import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/addProduct/screens/add_product_tab_view_screen.dart';
import 'package:syriacosmeticsmanger/features/barcode/controllers/barcode_controller.dart';
import 'package:syriacosmeticsmanger/features/product/domain/models/filter_model.dart';
import 'package:syriacosmeticsmanger/features/product/domain/models/product_model.dart';
import 'package:syriacosmeticsmanger/features/product/widgets/limited_stock_product_update_dialog.dart';
import 'package:syriacosmeticsmanger/features/restock/controllers/restock_controller.dart';
import 'package:syriacosmeticsmanger/helper/color_helper.dart';
import 'package:syriacosmeticsmanger/localization/controllers/localization_controller.dart';
import 'package:syriacosmeticsmanger/features/product/controllers/product_controller.dart';
import 'package:syriacosmeticsmanger/features/profile/controllers/profile_controller.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/theme/controllers/theme_controller.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/images.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/confirmation_dialog_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_image_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_snackbar_widget.dart';
import 'package:syriacosmeticsmanger/features/product_details/screens/product_details_screen.dart';
import 'package:syriacosmeticsmanger/features/barcode/screens/bar_code_generator_screen.dart';

import '../../../localization/language_constrants.dart';

class StockOutProductWidget extends StatefulWidget {
  final Product productModel;
  const StockOutProductWidget({super.key, required this.productModel});

  @override
  State<StockOutProductWidget> createState() => _StockOutProductWidgetState();
}

class _StockOutProductWidgetState extends State<StockOutProductWidget> {
  final TextEditingController _stockQuantityController = TextEditingController();

  void _deleteProduct(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (BuildContext dialogContext) {
        return ConfirmationDialogWidget(
          icon: Images.deleteProduct,
          refund: false,
          description: getTranslated('are_you_sure_want_to_delete_this_product', ctx),
          onYesPressed: () {
            Provider.of<ProductController>(ctx, listen: false)
                .deleteProduct(ctx, widget.productModel.id)
                .then((value) {
              Provider.of<ProductController>(Get.context!, listen: false)
                  .getStockOutProductList(1, LocalizationController.apiLanguageCode(Get.context!));
              Provider.of<ProductController>(Get.context!, listen: false)
                  .getSellerProductList(
                Provider.of<ProfileController>(Get.context!, listen: false)
                    .userInfoModel!.id.toString(),
                1, LocalizationController.apiLanguageCode(Get.context!), '',
                filterSearchModel: FilterModel(reload: true),
              );
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLtr = Provider.of<LocalizationController>(context, listen: false).isLtr;
    final bool isDark = Provider.of<ThemeController>(context).darkTheme;
    int variationLength = widget.productModel.variation?.length ?? 0;
    bool isStockOut = widget.productModel.currentStock == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeExtraSmall,
        vertical: Dimensions.paddingSizeVeryTiny,
      ),
      child: Slidable(
        key: ValueKey(widget.productModel.id),

        startActionPane: ActionPane(
          motion: const ScrollMotion(),
          dragDismissible: false,
          children: [
            SlidableAction(
              onPressed: (_) => _deleteProduct(context),
              backgroundColor: Theme.of(context).colorScheme.error.withValues(alpha: .08),
              foregroundColor: Theme.of(context).colorScheme.error,
              icon: Icons.delete_forever_rounded,
              label: getTranslated('delete', context),
            ),
            SlidableAction(
              onPressed: (_) {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AddProductTabView(product: widget.productModel, fromHome: false)));
              },
              backgroundColor: Theme.of(context).primaryColor.withValues(alpha: .08),
              foregroundColor: Theme.of(context).primaryColor,
              icon: Icons.edit_rounded,
              label: getTranslated('edit', context),
            ),
          ],
        ),

        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => _deleteProduct(context),
              backgroundColor: Theme.of(context).colorScheme.error.withValues(alpha: .08),
              foregroundColor: Theme.of(context).colorScheme.error,
              icon: Icons.delete_forever_rounded,
              label: getTranslated('delete', context),
            ),
            SlidableAction(
              onPressed: (_) {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AddProductTabView(product: widget.productModel, fromHome: false)));
              },
              backgroundColor: Theme.of(context).primaryColor.withValues(alpha: .08),
              foregroundColor: Theme.of(context).primaryColor,
              icon: Icons.edit_rounded,
              label: getTranslated('edit', context),
            ),
          ],
        ),

        // ═══════════════════════════════════════════
        // البطاقة الرئيسية
        // ═══════════════════════════════════════════
        child: Container(
          padding: const EdgeInsetsDirectional.only(start: Dimensions.paddingSizeSmall),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).cardColor,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: .06)
                  : Colors.black.withValues(alpha: .04),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: .2)
                    : Colors.black.withValues(alpha: .04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              // ═══════════════════════════════════════
              // المحتوى الرئيسي
              // ═══════════════════════════════════════
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailsScreen(productModel: widget.productModel),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeExtraSmall),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // صورة المنتج
                      Padding(
                        padding: EdgeInsets.only(
                          top: Dimensions.paddingSizeExtraSmall,
                          right: isLtr ? 0 : Dimensions.fontSizeSmall,
                        ),
                        child: Container(
                          width: Dimensions.stockOutImageSize,
                          height: Dimensions.stockOutImageSize,
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withValues(alpha: .06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: .05)
                                  : Colors.black.withValues(alpha: .04),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CustomImageWidget(
                              image: '${widget.productModel.thumbnailFullUrl?.path}',
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: Dimensions.paddingSizeSmall),

                      // معلومات المنتج
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.productModel.name ?? '',
                                style: robotoMedium.copyWith(
                                  fontSize: Dimensions.fontSizeDefault,
                                  color: ColorHelper.blendColors(
                                    Colors.white,
                                    Theme.of(context).textTheme.bodyLarge!.color!,
                                    0.85,
                                  ),
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),

                              const SizedBox(height: Dimensions.paddingSizeSmall),

                              // شارة المخزون
                              _buildStockBadge(context, isStockOut),

                              const SizedBox(height: Dimensions.paddingSizeSmall),

                              // عدد المتغيرات
                              variationLength != 0
                                  ? Row(
                                children: [
                                  Icon(
                                    Icons.layers_outlined,
                                    size: 13,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .color!
                                        .withValues(alpha: .5),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$variationLength ${getTranslated('variation', context)}',
                                    style: robotoRegular.copyWith(
                                      fontSize: Dimensions.fontSizeSmall,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .color!
                                          .withValues(alpha: .5),
                                    ),
                                  ),
                                ],
                              )
                                  : const SizedBox(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ═══════════════════════════════════════
              // زر الباركود (نفس الطريقة القديمة)
              // ═══════════════════════════════════════
              Positioned(
                bottom: 15,
                right: isLtr ? 70 : null,
                left: isLtr ? null : 70,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dimensions.paddingSizeExtraSmall,
                  ),
                  child: Center(
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => BarCodeGenerateScreen(product: widget.productModel),
                        ));
                        Provider.of<BarcodeController>(context, listen: false)
                            .setBarCodeQuantity(4);
                      },
                      child: Image.asset(
                        Images.barcodeIcon,
                        width: 30,
                      ),
                    ),
                  ),
                ),
              ),

              // ═══════════════════════════════════════
              // زر إضافة المخزون
              // ═══════════════════════════════════════
              Consumer<RestockController>(
                builder: (context, productProvider, _) {
                  return Positioned(
                    bottom: 13,
                    right: isLtr ? 15 : null,
                    left: isLtr ? null : 5,
                    child: Container(
                      height: 30,
                      width: 30,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withValues(alpha: .75),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).primaryColor.withValues(alpha: .25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: InkWell(
                          onTap: () => _showRestockDialog(context, productProvider),
                          child: const Center(
                            child: Icon(Icons.add, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // شارة حالة المخزون
  // ═══════════════════════════════════════════════════
  Widget _buildStockBadge(BuildContext context, bool isStockOut) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeSmall,
        vertical: Dimensions.paddingSizeVeryTiny,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isStockOut
            ? Theme.of(context).colorScheme.error.withValues(alpha: .1)
            : Theme.of(context).colorScheme.onSecondary.withValues(alpha: .1),
        border: Border.all(
          width: 1,
          color: isStockOut
              ? Theme.of(context).colorScheme.error.withValues(alpha: .3)
              : Theme.of(context).colorScheme.onSecondary.withValues(alpha: .3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isStockOut
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSecondary,
              boxShadow: [
                BoxShadow(
                  color: (isStockOut
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSecondary
                  ).withValues(alpha: .4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              isStockOut
                  ? getTranslated('stock_out', context) ?? ''
                  : '${widget.productModel.currentStock} ${getTranslated('in_stock', context)}',
              style: robotoMedium.copyWith(
                fontSize: Dimensions.fontSizeSmall,
                color: isStockOut
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // نافذة إعادة التخزين
  // ═══════════════════════════════════════════════════
  void _showRestockDialog(BuildContext context, RestockController productProvider) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return LimitedStockQuantityUpdateDialogWidget(
          stockQuantityController: _stockQuantityController,
          product: widget.productModel,
          title: getTranslated('product_variations', context),
          onYesPressed: () {
            bool isEmpty = false;

            if (productProvider.variationQuantityController.isNotEmpty) {
              for (int i = 0; i < productProvider.variationQuantityController.length; i++) {
                if (productProvider.variationQuantityController[i].text == '' && !isEmpty) {
                  isEmpty = true;
                }
              }
            }

            if (isEmpty) {
              showCustomSnackBarWidget(
                'variation_quantity_is_required',
                sanckBarType: SnackBarType.error,
                context,
              );
            } else if (_stockQuantityController.text.toString().isEmpty) {
              showCustomSnackBarWidget('product_quantity_is_required', context);
              if (kDebugMode) {
                print(widget.productModel.id);
              }
            } else {
              productProvider.updateProductQuantity(
                context,
                widget.productModel.id,
                int.parse(_stockQuantityController.text.toString()),
                widget.productModel.variation!,
              );
            }
          },
        );
      },
    );
  }
}