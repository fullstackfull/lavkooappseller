import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_asset_image_widget.dart';
import 'package:syriacosmeticsmanger/features/shop/controllers/shop_controller.dart';
import 'package:syriacosmeticsmanger/features/shop/widgets/business_setup_guideline.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/theme/controllers/theme_controller.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/images.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

import 'package:syriacosmeticsmanger/core/app_context.dart';

class MyShopAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;

  const MyShopAppBar({super.key, required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
      preferredSize: preferredSize,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Provider.of<ThemeController>(context, listen: false).darkTheme? Theme.of(context).primaryColor.withValues(alpha:0):
            Theme.of(context).primaryColor.withValues(alpha:.10),
              offset: const Offset(0, 2.0), blurRadius: 4.0,
            )
          ]
        ),
        child: AppBar(
          surfaceTintColor: Theme.of(context).scaffoldBackgroundColor,
          shadowColor: Theme.of(context).primaryColor.withValues(alpha:.5),
          titleSpacing: 0,
          title: Text(title!,
            style: titilliumSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge,
            color: Theme.of(context).textTheme.bodyLarge!.color)
          ),
          centerTitle: false,
          leading:  Consumer<ShopController>(
            builder: (context, shopInfo, child) {
              return IconButton(icon: const Icon(Icons.arrow_back_ios, size: Dimensions.iconSizeDefault),
                color: Theme.of(context).textTheme.bodyLarge!.color,
                onPressed: () {
                  if(shopInfo.myShopPageIndex != 0) {
                    shopInfo.setShopPageIndex(0, isUpdate: true);
                  }else {
                    Future.microtask(() {
                      Navigator.of(Get.context!).pop();
                    });
                  }
                }
              );
            }
          ),

          backgroundColor: Theme.of(context).highlightColor,
          elevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
              child: InkWell(
                onTap: () {
                  showModalBottomSheet(
                    backgroundColor: Theme.of(context).cardColor,
                    useSafeArea: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    isScrollControlled: true,
                    context: context,
                    builder: (BuildContext context) {
                      return const BusinessSetupGuideline();
                    },
                  );
                } ,
                child: const CustomAssetImageWidget(Images.storeWebIcon, width: 25, height: 25)
              )
            ),
          ],

          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(40), // Height of the additional content
            child: Padding(
              padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall, left: Dimensions.paddingSizeDefault,
                right: Dimensions.paddingSizeSmall, top: Dimensions.paddingSizeSmall),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Consumer<ShopController>(
                  builder: (context, shopInfo, child) {
                    return Row(
                      children: [

                        Button(
                          isSelected: shopInfo.myShopPageIndex == 0,
                          title: getTranslated('shop_details', context) ?? '',
                          onPressed: () {
                            shopInfo.setShopPageIndex(0);
                          },
                        ),
                        const SizedBox(width: Dimensions.paddingSizeSmall),

                        Button(
                          isSelected: shopInfo.myShopPageIndex == 1,
                          title: getTranslated('payment_info', context) ?? '',
                          onPressed: () {
                            shopInfo.setShopPageIndex(1);
                          },
                        ),
                        const SizedBox(width: Dimensions.paddingSizeSmall),


                        Button(
                          isSelected: shopInfo.myShopPageIndex == 2,
                          title: getTranslated('other_setup', context) ?? '',
                          onPressed: () {
                            shopInfo.setShopPageIndex(2);
                          },
                        ),
                        const SizedBox(width: Dimensions.paddingSizeSmall),

                      ],
                    );
                  }
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  @override
  Size get preferredSize => const Size(double.maxFinite, 100);
}


class Button extends StatelessWidget {
  final String title;
  final bool isSelected;
  final Function? onPressed;

  const Button({
    super.key,
    required this.isSelected,
    required this.title,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {

    final bool isDark =
        Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        onPressed!();
      },
      borderRadius: BorderRadius.circular(50),

      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: Dimensions.paddingSizeExtraSmall,
          horizontal: Dimensions.paddingSizeSmall,
        ),

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),

          color: isSelected
              ? Theme.of(context).primaryColor
              : isDark
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.20),
        ),

        child: Text(
          title,

          style: robotoMedium.copyWith(
            fontSize: Dimensions.fontSizeDefault,

            color: isSelected
                ? Colors.white
                : Theme.of(context)
                .textTheme
                .bodyLarge!
                .color,
          ),
        ),
      ),
    );
  }
}

