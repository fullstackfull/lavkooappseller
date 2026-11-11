import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/order/controllers/order_controller.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

class OrderTypeButtonWidget extends StatelessWidget {
  final Color color;
  final String? text;
  final int index;
  final int? numberOfOrder;
  final double percentage;
  final Function? callback;
  final bool showBorder;

  const OrderTypeButtonWidget({
    super.key,
    required this.color,
    this.text,
    required this.index,
    this.numberOfOrder,
    this.percentage = 0,
    this.callback,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            Provider.of<OrderController>(context, listen: false).setIndex(context, index);
            if (callback != null) callback!();
          },
          // ✅ التعديل هون: vertical صارت paddingSizeDefault بدل paddingSizeSmall
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
              vertical: Dimensions.paddingSizeDefault, // ⬅️ تعديل
            ),
            child: Row(
              children: [
                /// الدائرة مع النسبة
                SizedBox(
                  height: 48,
                  width: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 48,
                        width: 48,
                        child: CircularProgressIndicator(
                          value: percentage,
                          strokeWidth: 4,
                          strokeCap: StrokeCap.round,
                          backgroundColor: color.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                      Text(
                        '${(percentage * 100).round()}%',
                        style: robotoMedium.copyWith(
                          fontSize: Dimensions.fontSizeExtraSmall,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Dimensions.paddingSizeSmall),

                /// العنوان + العدد + شريط التقدم
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text ?? '',
                        style: robotoMedium.copyWith(
                          fontSize: Dimensions.fontSizeLarge,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${numberOfOrder ?? 0} ${getTranslated('orders', context) ?? 'Orders'}',
                        style: robotoRegular.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percentage,
                          minHeight: 6,
                          backgroundColor: color.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Dimensions.paddingSizeExtraSmall),

                /// السهم
                Icon(Icons.arrow_forward, size: 18, color: Theme.of(context).hintColor),
              ],
            ),
          ),
        ),

        /// الخط الفاصل
        if (showBorder)
          Divider(
            height: 1,
            thickness: 1,
            indent: Dimensions.paddingSizeDefault,
            endIndent: Dimensions.paddingSizeDefault,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
          ),
      ],
    );
  }
}