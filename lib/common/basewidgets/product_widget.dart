import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/localization/controllers/localization_controller.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/confirmation_dialog_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_image_widget.dart';
import 'package:syriacosmeticsmanger/features/addProduct/screens/add_product_tab_view_screen.dart';
import 'package:syriacosmeticsmanger/features/product/domain/models/filter_model.dart';
import 'package:syriacosmeticsmanger/features/product/domain/models/product_model.dart';
import 'package:syriacosmeticsmanger/helper/color_helper.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/features/product/controllers/product_controller.dart';
import 'package:syriacosmeticsmanger/features/profile/controllers/profile_controller.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/images.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';
import 'package:syriacosmeticsmanger/features/product_details/screens/product_details_screen.dart';

class ProductWidget extends StatefulWidget {
  final Product productModel;
  const ProductWidget({super.key, required this.productModel});

  @override
  State<ProductWidget> createState() => _ProductWidgetState();
}

class _ProductWidgetState extends State<ProductWidget> {
  var isDialOpen = ValueNotifier<bool>(false);
  var extend = false;

  @override
  Widget build(BuildContext context) {
    double imageSize = MediaQuery.of(context).size.width / 2.8;

    double totalRatting = 0;
    double averageProductRatting = 0;
    if (widget.productModel.reviews!.isNotEmpty) {
      for (int i = 0; i < widget.productModel.reviews!.length; i++) {
        totalRatting += widget.productModel.reviews![i].rating!;
      }
      averageProductRatting = totalRatting / widget.productModel.reviews!.length;
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailsScreen(productModel: widget.productModel),
        ),
      ),
      child: SizedBox(
        width: imageSize + 30,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeExtraSmall,
            vertical: Dimensions.paddingSizeVeryTiny,
          ),
          child: Stack(
            children: [
              // ═══════════════════════════════════════
              // الكارت - أسلوب Apple
              // ═══════════════════════════════════════
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .04),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ═══════════════════════════
                    // الصورة
                    // ═══════════════════════════
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: Container(
                        width: imageSize + 30,
                        height: imageSize,
                        color: Theme.of(context).primaryColor.withValues(alpha: .03),
                        child: CustomImageWidget(
                          height: imageSize,
                          width: imageSize + 30,
                          image: '${widget.productModel.thumbnailFullUrl?.path}',
                        ),
                      ),
                    ),

                    // ═══════════════════════════
                    // المعلومات
                    // ═══════════════════════════
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Dimensions.paddingSizeSmall,
                        Dimensions.paddingSizeSmall,
                        Dimensions.paddingSizeSmall,
                        Dimensions.paddingSizeDefault,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // اسم المنتج
                          Text(
                            widget.productModel.name ?? '',
                            style: robotoMedium.copyWith(
                              fontSize: Dimensions.fontSizeDefault,
                              color: ColorHelper.blendColors(
                                Colors.white,
                                Theme.of(context).textTheme.bodyLarge!.color!,
                                0.9,
                              ),
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: Dimensions.paddingSizeSmall),

                          // التقييم
                          // ═══════════════════════════
// التقييم - ستايل App Store
// ═══════════════════════════
                          Row(
                            children: [
                              // نجمة واحدة
                              Icon(
                                Icons.star_rounded,
                                size: 16,
                                color: Colors.amber.shade600,
                              ),

                              const SizedBox(width: 4),

                              // رقم التقييم
                              Text(
                                averageProductRatting.toStringAsFixed(1),
                                style: robotoMedium.copyWith(
                                  fontSize: Dimensions.fontSizeSmall,
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                              ),

                              const SizedBox(width: Dimensions.paddingSizeExtraSmall),

                              // فاصل
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall!
                                      .color!
                                      .withValues(alpha: .3),
                                ),
                              ),

                              const SizedBox(width: Dimensions.paddingSizeExtraSmall),

                              // عدد المراجعات
                              Text(
                                '${widget.productModel.reviewsCount} ${getTranslated('reviews', context) ?? ''}',
                                style: robotoRegular.copyWith(
                                  fontSize: Dimensions.fontSizeSmall,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall!
                                      .color!
                                      .withValues(alpha: .4),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ═══════════════════════════════════════
              // زر القائمة
              // ═══════════════════════════════════════
              Positioned(
                top: 10,
                right: 10,
                child: SpeedDial(
                  animationDuration: const Duration(milliseconds: 300),
                  overlayOpacity: 0,
                  icon: Icons.more_horiz_rounded,
                  activeIcon: Icons.close_rounded,
                  spacing: 3,
                  mini: true,
                  openCloseDial: isDialOpen,
                  childPadding: const EdgeInsets.all(4),
                  spaceBetweenChildren: 4,
                  buttonSize: const Size(30.0, 30.0),
                  childrenButtonSize: const Size(38.0, 38.0),
                  visible: true,
                  direction: SpeedDialDirection.left,
                  switchLabelPosition: false,
                  closeManually: true,
                  renderOverlay: true,
                  useRotationAnimation: false,
                  backgroundColor: Colors.white.withValues(alpha: .95),
                  foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
                  elevation: extend ? 0 : 2.0,
                  animationCurve: Curves.easeInOut,
                  isOpenOnStart: false,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  onOpen: () => setState(() => extend = true),
                  onClose: () => setState(() => extend = false),
                  children: [
                    SpeedDialChild(
                      elevation: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .1),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.asset(Images.editIcon),
                        ),
                      ),
                      onTap: () async {
                        setState(() {
                          isDialOpen.value = false;
                          extend = false;
                        });
                        await Future.delayed(const Duration(milliseconds: 350));
                        Navigator.of(Get.context!).push(
                          MaterialPageRoute(
                            builder: (_) => AddProductTabView(
                              product: widget.productModel,
                              fromHome: false,
                            ),
                          ),
                        );
                      },
                    ),
                    SpeedDialChild(
                      elevation: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .1),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.asset(Images.delete),
                        ),
                      ),
                      onTap: () async {
                        setState(() {
                          isDialOpen.value = false;
                          extend = false;
                        });
                        await Future.delayed(const Duration(milliseconds: 350));
                        showDialog(
                          context: Get.context!,
                          builder: (BuildContext context) {
                            return ConfirmationDialogWidget(
                              icon: Images.deleteProduct,
                              refund: false,
                              description: getTranslated(
                                  'are_you_sure_want_to_delete_this_product',
                                  context),
                              onYesPressed: () {
                                Provider.of<ProductController>(context, listen: false)
                                    .deleteProduct(context, widget.productModel.id)
                                    .then((value) {
                                  Provider.of<ProductController>(Get.context!,
                                      listen: false)
                                      .getStockOutProductList(1, LocalizationController.apiLanguageCode(Get.context!));
                                  Provider.of<ProductController>(Get.context!,
                                      listen: false)
                                      .getSellerProductList(
                                    Provider.of<ProfileController>(Get.context!,
                                        listen: false)
                                        .userInfoModel!
                                        .id
                                        .toString(),
                                    1,
                                    LocalizationController.apiLanguageCode(Get.context!),
                                    '',
                                    filterSearchModel: FilterModel(reload: true),
                                  );
                                });
                              },
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}