import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/product/controllers/product_controller.dart';
import 'package:syriacosmeticsmanger/features/profile/controllers/profile_controller.dart';
import 'package:syriacosmeticsmanger/localization/controllers/localization_controller.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';


class StatusFilterWidget extends StatefulWidget {
  final Function(int index) onFilterChanged;
  const StatusFilterWidget({super.key, required this.onFilterChanged});

  @override
  State<StatusFilterWidget> createState() => _StatusFilterWidgetState();
}

class _StatusFilterWidgetState extends State<StatusFilterWidget> {
  int _selectedIndex = 0;

  final List<String> _filterList = ['all', 'approved', 'denied', 'new_product'];

  ProductController productController = Provider.of<ProductController>(Get.context!, listen: false);


  void _callApi (String status) {
    productController.getSellerProductList(
      Provider.of<ProfileController>(context, listen: false).userId.toString(), 1,
      Provider.of<LocalizationController>(context, listen: false).locale.languageCode == 'US'?'en':
      LocalizationController.apiLanguageCode(context),'',
      filterSearchModel:  productController.filterModel.copyWith(
        reload: true,
        isApproved: status,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).cardColor,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filterList.length,
        shrinkWrap: true,
        itemBuilder: (context, index) {
          bool isSelected = _selectedIndex == index;
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: Dimensions.paddingSizeSmall),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedIndex = index;
                });
                _callApi(_filterList[index]);
              },
              borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeExtraLarge),
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).primaryColor
                    : Theme.of(context).hintColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge),
                ),
                alignment: Alignment.center,
                child: Text(
                  getTranslated(_filterList[index], context)  ?? _filterList[index],
                  style: isSelected ? robotoBold.copyWith(
                    color: Colors.white,
                    fontSize: Dimensions.fontSizeDefault
                  ) : robotoRegular.copyWith(
                    color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
                    fontSize: Dimensions.fontSizeDefault
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}