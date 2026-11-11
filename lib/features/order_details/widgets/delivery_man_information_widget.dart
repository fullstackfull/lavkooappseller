import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/features/order/domain/models/order_model.dart';
import 'package:syriacosmeticsmanger/helper/color_helper.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/images.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_image_widget.dart';


class DeliveryManContactInformationWidget extends StatelessWidget {
  final String? orderType;
  final Order? orderModel;
  final bool? onlyDigital;
  const DeliveryManContactInformationWidget({super.key, this.orderModel, this.orderType, this.onlyDigital});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [BoxShadow(color: Theme.of(context).hintColor.withValues(alpha:0.2), spreadRadius:1.5, blurRadius: 3)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
              child: Text(getTranslated('deliveryman_information', context)!,
                style: robotoBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Theme.of(context).textTheme.bodyLarge?.color)
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall),

            Divider(thickness: 0.2, height: 1, color: Theme.of(context).hintColor.withValues(alpha: .65)),
            const SizedBox(height: Dimensions.paddingSizeSmall),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
              child: Row(children: [ClipRRect(borderRadius: BorderRadius.circular(50),
                child: CustomImageWidget( height: 50,width: 50, fit: BoxFit.cover,
                image: '${orderModel!.deliveryMan!.imageFullUrl?.path}')
              ),
              const SizedBox(width: Dimensions.paddingSizeSmall),

                Expanded(child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${orderModel!.deliveryMan!.fName ?? ''} ''${orderModel!.deliveryMan!.lName ?? ''}',
                      style: titilliumRegular.copyWith(color: ColorHelper.blendColors(Colors.white, Theme.of(context).textTheme.bodyLarge!.color!, 0.7),
                          fontSize: Dimensions.fontSizeDefault)),

                  const SizedBox(height: Dimensions.paddingSizeExtraSmall,),

                  Row(children: [
                    Image.asset(Images.phone, width: 15),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    Text('${orderModel!.deliveryMan!.countryCode} ${orderModel!.deliveryMan!.phone}',
                        style: titilliumRegular.copyWith(color: ColorHelper.blendColors(Colors.white, Theme.of(context).textTheme.bodyLarge!.color!, 0.7),
                            fontSize: Dimensions.fontSizeDefault)),
                    ]
                  ),

                  const SizedBox(height: Dimensions.paddingSizeExtraSmall,),

                  Row(children: [
                    Image.asset(Images.email, width: 15),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    Text(orderModel!.deliveryMan!.email ?? '',
                        style: titilliumRegular.copyWith(color: ColorHelper.blendColors(Colors.white, Theme.of(context).textTheme.bodyLarge!.color!, 0.7),
                            fontSize: Dimensions.fontSizeDefault)),
                    ],
                  ),


                ],))
                ],
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeDefault),



          ]),
        ),
      ],
    );
  }
}
