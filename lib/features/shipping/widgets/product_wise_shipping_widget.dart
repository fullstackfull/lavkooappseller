import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/features/shipping/controllers/shipping_controller.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/images.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/features/shipping/widgets/drop_down_for_shipping_type_widget.dart';

class ProductWiseShippingWidget extends StatefulWidget {
  const ProductWiseShippingWidget({super.key});

  @override
  State<ProductWiseShippingWidget> createState() => _ProductWiseShippingWidgetState();
}

class _ProductWiseShippingWidgetState extends State<ProductWiseShippingWidget> {

  @override
  void initState() {
    Provider.of<ShippingController>(context, listen: false).iniType('product_type');
    super.initState();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: CustomAppBarWidget(title: getTranslated('shipping_method', context),isBackButtonExist: true,),
        body: Column(crossAxisAlignment: CrossAxisAlignment.center,mainAxisAlignment: MainAxisAlignment.center,children: [
          const DropDownForShippingTypeWidget(),
          Expanded( child: Column( children: [
                Padding(
                  padding: EdgeInsets.only(
                    top : MediaQuery.of(context).size.height/5),
                  child: SizedBox(width: MediaQuery.of(context).size.width/3,
                    child: Image.asset(Images.productWiseShipping)),
                ),
                Padding(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeButton),
                  child: Text(getTranslated('product_wise_delivery_note', context)!,style: robotoRegular.copyWith(
                    color: Theme.of(context).textTheme.bodyLarge?.color
                  ),textAlign: TextAlign.center),
                )
              ],
            ),
          ),
          const SizedBox()

        ],));
  }
}
