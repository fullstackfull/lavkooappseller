import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/theme/app_glass.dart';

import 'package:syriacosmeticsmanger/features/order/domain/models/order_model.dart';
import 'package:syriacosmeticsmanger/features/order_details/screens/order_details_screen.dart';
import 'package:syriacosmeticsmanger/helper/date_converter.dart';
import 'package:syriacosmeticsmanger/helper/price_converter.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';


class OrderWidget extends StatelessWidget {

  final Order orderModel;
  final int? index;

  const OrderWidget({
    super.key,
    required this.orderModel,
    this.index,
  });


  @override
  Widget build(BuildContext context) {

    return InkWell(
      borderRadius: BorderRadius.circular(Dimensions.radiusLarge),

      onTap: (){
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailsScreen(
              orderId: orderModel.id,
            ),
          ),
        );
      },


      child: Container(

        margin: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 6,
        ),

        padding: const EdgeInsets.all(12),


        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
          border: Border.all(color: AppGlass.of(context).border),
          // Shadow now comes from the theme tokens, so dark mode gets a real
          // (darker) shadow instead of none at all.
          boxShadow: AppGlass.of(context).shadowSoft,
        ),



        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [



            /// TOP
            Row(

              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,

              children: [


                Row(
                  children: [

                    Text(
                      "#${orderModel.id}",
                      style: robotoBold.copyWith(
                        fontSize: 15,
                      ),
                    ),


                    if(orderModel.orderType=="POS")

                      Container(

                        margin: const EdgeInsets.only(
                          left: 6,
                        ),

                        padding:
                        const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),

                        decoration: BoxDecoration(
                          color: const Color(0xFF1F7A55).withValues(alpha:.1),
                          borderRadius:
                          BorderRadius.circular(20),
                        ),


                        child: Text(
                          "POS",
                          style: robotoMedium.copyWith(
                            fontSize: 11,
                            color: const Color(0xFF1F7A55),
                          ),
                        ),
                      ),



                  ],
                ),



                Container(

                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),


                  decoration: BoxDecoration(

                    color: _statusBg(
                      context,
                      orderModel.orderStatus,
                    ),

                    borderRadius:
                    BorderRadius.circular(20),

                  ),


                  child: Text(

                    getTranslated(
                        orderModel.orderStatus ?? '',
                        context
                    ) ?? '',


                    style: robotoBold.copyWith(

                      fontSize: 11,

                      color: _statusColor(
                        context,
                        orderModel.orderStatus,
                      ),

                    ),

                  ),

                )


              ],
            ),




            const SizedBox(height:12),




            /// DATE

            if(orderModel.createdAt != null)

              Row(

                children: [

                  Icon(
                    Icons.access_time,
                    size:15,
                    color: Theme.of(context).hintColor,
                  ),

                  const SizedBox(width:6),


                  Text(

                    DateConverter.localDateToIsoStringAMPM(
                      DateTime.parse(
                          orderModel.createdAt!
                      ),
                    ),


                    style: robotoRegular.copyWith(

                      fontSize:12,

                      color:
                      Theme.of(context).hintColor,

                    ),

                  ),

                ],
              ),




            const SizedBox(height:12),





            /// PAYMENT + PRICE

            Row(

              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,


              children: [


                Row(

                  children: [


                    Icon(

                      orderModel.paymentMethod ==
                          "cash_on_delivery"

                          ? Icons.payments_outlined

                          : Icons.credit_card,

                      size:18,

                      color:
                      Theme.of(context)
                          .primaryColor,

                    ),



                    const SizedBox(width:7),



                    Text(

                      getTranslated(
                          orderModel.paymentMethod ?? '',
                          context
                      ) ?? '',


                      style: robotoRegular.copyWith(
                        fontSize:13,
                        color:
                        Theme.of(context)
                            .hintColor,
                      ),

                    ),

                  ],
                ),




                Text(

                  PriceConverter.convertPrice(

                    context,

                    orderModel.orderAmount ?? 0,

                  ),


                  style: robotoBold.copyWith(

                    fontSize:16,

                    color:
                    Theme.of(context)
                        .primaryColor,

                  ),

                ),


              ],

            ),


          ],

        ),

      ),

    );

  }




  Color _statusBg(
      BuildContext context,
      String? status
      ){

    switch(status){

      case "pending":
        return Colors.orange.withValues(alpha:.12);

      case "confirmed":
      case "delivered":
        return Colors.green.withValues(alpha:.12);


      case "processing":
        return const Color(0xFF1F7A55).withValues(alpha:.12);


      case "canceled":
      case "failed":
        return Colors.red.withValues(alpha:.12);


      default:
        return Colors.grey.withValues(alpha:.12);

    }

  }



  Color _statusColor(
      BuildContext context,
      String? status
      ){

    switch(status){

      case "pending":
        return Colors.orange;


      case "confirmed":
      case "delivered":
        return Colors.green;


      case "processing":
        return const Color(0xFF1F7A55);


      case "canceled":
      case "failed":
        return Colors.red;


      default:
        return Colors.grey;

    }

  }


}
/*
import 'package:flutter/material.dart';
import 'package:just_the_tooltip/just_the_tooltip.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_asset_image_widget.dart';
import 'package:syriacosmeticsmanger/features/order/domain/models/order_model.dart';
import 'package:syriacosmeticsmanger/helper/date_converter.dart';
import 'package:syriacosmeticsmanger/helper/price_converter.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/images.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';
import 'package:syriacosmeticsmanger/features/order_details/screens/order_details_screen.dart';

class OrderWidget extends StatefulWidget {
  final Order orderModel;
  final int? index;
  const OrderWidget({super.key, required this.orderModel, this.index});

  @override
  State<OrderWidget> createState() => _OrderWidgetState();
}

class _OrderWidgetState extends State<OrderWidget> {
  final tooltipController = JustTheController();


  @override
  Widget build(BuildContext context) {
    double orderAmount = 0;

    if(widget.orderModel.orderType == 'POS') {
      double itemsPrice = 0;
      double discount = 0;
      double? eeDiscount = 0;
      double tax = 0;
      double coupon = 0;
      double shipping = 0;
      if (widget.orderModel.orderDetails != null && widget.orderModel.orderDetails!.isNotEmpty ) {
        coupon = widget.orderModel.discountAmount!;
        shipping = widget.orderModel.shippingCost!;
        for (var orderDetails in widget.orderModel.orderDetails!) {
          if(orderDetails.productDetails?.productType == "physical"){
          }
          itemsPrice = itemsPrice + (orderDetails.price! * orderDetails.qty!);
          discount = discount + orderDetails.discount!;
          tax = tax + orderDetails.tax!;

        }
        if(widget.orderModel.orderType == 'POS'){
          if(widget.orderModel.extraDiscountType == 'percent'){
            eeDiscount = itemsPrice * (widget.orderModel.extraDiscount!/100);
          }else{
            eeDiscount = widget.orderModel.extraDiscount;
          }
        }
      }
      double subTotal = itemsPrice +tax - discount;

      orderAmount = subTotal + shipping - coupon - eeDiscount!;




      // double ? _extraDiscountAnount = 0;
      // if(orderModel.extraDiscount != null){
      //   _extraDiscountAnount = PriceConverter.convertWithDiscount(context, orderModel.totalProductPrice, orderModel.extraDiscount, orderModel.extraDiscountType == 'percent' ? 'percent' : 'amount' );
      //   if(_extraDiscountAnount != null) {
      //     double percentAmount = _extraDiscountAnount!;
      //     _extraDiscountAnount = orderModel.totalProductPrice! - percentAmount;
      //   }
      // }
      //
      // double totalDiscount = (_extraDiscountAnount! + orderModel.totalProductDiscount!);
      // double totalOrderAmount = (orderModel.totalProductPrice! + orderModel.totalTaxAmount!);
      //
      // orderAmount = totalOrderAmount - totalDiscount;
      //
      // orderAmount = orderModel.orderAmount! - orderModel.totalTaxAmount!;


    }



    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeMedium),
      child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsScreen (orderId: widget.orderModel.id))),
            child: Container(decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall),
                boxShadow: [BoxShadow(color: Provider.of<ThemeController>(context, listen: false).darkTheme?Theme.of(context).primaryColor.withValues(alpha:0):
                Theme.of(context).primaryColor.withValues(alpha:.09),blurRadius: 5, spreadRadius: 1, offset: const Offset(1,2))]),
              child: Column( crossAxisAlignment: CrossAxisAlignment.start,children: [

                Container(decoration: const BoxDecoration(
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(Dimensions.paddingSizeSmall), topRight: Radius.circular(Dimensions.paddingSizeSmall))),
                  child: Padding(padding: const EdgeInsets.only(
                    top: Dimensions.paddingSizeSmall,
                    left: Dimensions.paddingSizeSmall,
                    right: Dimensions.paddingSizeSmall
                  ),
                    child: Row(mainAxisAlignment : MainAxisAlignment.spaceBetween, children: [

                        Row(children: [
                          Text('${getTranslated('order_no', context)} ',
                            style: robotoRegular.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: Dimensions.fontSizeDefault),),
                          Text('#${widget.orderModel.id} ${widget.orderModel.orderType == 'POS'? '(POS)':''}',
                            style: robotoMedium.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color,fontSize: Dimensions.fontSizeDefault),),

                          if(widget.orderModel.editedStatus == 1)
                          Text('(${getTranslated('edited', context)})',
                            style: robotoMedium.copyWith(color: Theme.of(context).textTheme.headlineMedium?.color,fontSize: Dimensions.fontSizeSmall),
                          ),
                          SizedBox(width: Dimensions.paddingSizeExtraSmall),

                          if(widget.orderModel.editedStatus == 1 && ((widget.orderModel.editDueAmount ?? 0) > 0 || (widget.orderModel.editReturnAmount ?? 0) > 0))
                          JustTheTooltip(
                            backgroundColor: Colors.black87,
                            controller: tooltipController,
                            preferredDirection: AxisDirection.up,
                            tailLength: 10,
                            tailBaseWidth: 20,
                            content: Container(width: 250,
                              padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                              child: Text(
                                (widget.orderModel.editDueAmount ?? 0) > 0 ? getTranslated('customer_will_pay_due', context)! :
                                (widget.orderModel.editReturnAmount ?? 0) > 0 ? getTranslated('contact_the_admin_to_return', context)! : '',
                                style: robotoRegular.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeDefault)
                              )
                            ),
                            child: InkWell(
                              onTap: ()=>  tooltipController.showTooltip(),
                              child: CustomAssetImageWidget(
                                (widget.orderModel.editDueAmount ?? 0) > 0 ?
                                Images.orderDueAmountIcon : (widget.orderModel.editReturnAmount ?? 0) > 0 ? Images.orderReturnAmountIcon : Images.pendingOrderCardIcon,
                                height: 16, width: 16
                              ),
                            ),
                          ),
                        ]),


                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Dimensions.paddingSizeSmall,
                            vertical: Dimensions.paddingSizeExtraSmall,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            color: _getStatusBgColor(context, widget.orderModel.orderStatus),
                          ),
                          child: Text(
                            getTranslated(widget.orderModel.orderStatus, context) ?? '',
                            style: robotoBold.copyWith(
                              fontSize: Dimensions.fontSizeSmall,
                              color: _getStatusTextColor(context, widget.orderModel.orderStatus),
                            ),
                          ),
                        ),

                      ],
                    ),
                  ),
                ),

                Container(decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(Dimensions.paddingSizeSmall),
                  bottomRight: Radius.circular(Dimensions.paddingSizeSmall))),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeSmall, 0, Dimensions.paddingSizeSmall, Dimensions.paddingSizeSmall),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,children: [

                      widget.orderModel.createdAt != null?
                      Text(DateConverter.localDateToIsoStringAMPM(DateTime.parse(widget.orderModel.createdAt!)),
                        style: robotoRegular.copyWith(color: Theme.of(context).hintColor)) : const SizedBox(),


                      const SizedBox(height: Dimensions.paddingSizeSmall),


                      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center, children: [
                          Row(children: [
                            SizedBox(height: Dimensions.iconSizeDefault, width: Dimensions.iconSizeDefault,
                              child: CustomAssetImageWidget(widget.orderModel.paymentMethod == 'cash_on_delivery'? Images.paymentIcon:
                              widget.orderModel.paymentMethod == 'pay_by_wallet'? Images.payByWalletIcon : Images.digitalPaymentIcon),
                            ),
                            const SizedBox(width: Dimensions.paddingSizeSmall),

                            if(widget.orderModel.paymentMethod != null &&widget.orderModel.paymentMethod!.isNotEmpty)
                            Text(widget.orderModel.paymentMethod != null? getTranslated(widget.orderModel.paymentMethod??'', context)??'':'',
                              style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: Theme.of(context).hintColor)),
                          ],),

                          Text(
                            PriceConverter.convertPrice(context,  widget.orderModel.orderType == 'POS' ? widget.orderModel.orderAmount : widget.orderModel.orderAmount ?? 0),
                            style: robotoMedium.copyWith(color: Theme.of(context).primaryColor)
                          ),

                      ],),
                    ],),
                  ),
                )


              ],),),
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),

        ],
      ),
    );
  }


  Color _getStatusBgColor(BuildContext context, String? status) {
    switch (status) {
      case 'delivered':
      case 'confirmed':
        return Theme.of(context).colorScheme.onTertiaryContainer.withValues(alpha: .1);
      case 'pending':
        return Theme.of(context).primaryColor.withValues(alpha: .1);
      case 'processing':
        return Theme.of(context).colorScheme.outline.withValues(alpha: .1);
      case 'canceled':
      case 'failed':
        return Theme.of(context).colorScheme.error.withValues(alpha: .1);
      default:
        return Theme.of(context).colorScheme.secondary.withValues(alpha: .1);
    }
  }

  Color _getStatusTextColor(BuildContext context, String? status) {
    switch (status) {
      case 'delivered':
      case 'confirmed':
        return Theme.of(context).colorScheme.onTertiaryContainer;
      case 'pending':
        return Theme.of(context).primaryColor;
      case 'processing':
        return Theme.of(context).colorScheme.outline;
      case 'canceled':
      case 'failed':
        return Theme.of(context).colorScheme.error;
      default:
        return Theme.of(context).colorScheme.secondary;
    }
  }




}

 */

