import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/localization/controllers/localization_controller.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/features/product/controllers/product_controller.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/features/product/widgets/stock_out_product_widget.dart';

class StockOutProductScreen extends StatelessWidget {
  const StockOutProductScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: CustomAppBarWidget(title: getTranslated('stock_out_product',context)),
      body: RefreshIndicator(
        onRefresh: () async{
          Provider.of<ProductController>(context,listen: false).getStockOutProductList(1, LocalizationController.apiLanguageCode(context));
        },
        child: const Padding(
          padding: EdgeInsets.only(top: Dimensions.paddingSizeSmall),
          child: StockOutProductView(isHome: false),
        ),
      ),
    );
  }
}
