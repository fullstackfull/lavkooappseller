import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

class CustomButtonWidget extends StatelessWidget {
  final Function? onTap;
  final String? btnTxt;
  final bool isColor;
  final Color? backgroundColor;
  final Color? fontColor;
  final Color? borderColor;
  final double? borderRadius;
  final double? buttonHeight;
  final double? textSize;
  final bool isLoading;
  final TextStyle? textStyle;

  const CustomButtonWidget({
    super.key, this.onTap,
    required this.btnTxt,
    this.backgroundColor,
    this.isColor = false,
    this.fontColor,
    this.borderRadius,
    this.borderColor,
    this.buttonHeight = 40,
    this.textSize = Dimensions.fontSizeDefault,
    this.isLoading = false, this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return isLoading ? Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
       SizedBox(
        height: 15, width: 15,
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
          strokeWidth: 2,
        ),
      ),
      const SizedBox(width: Dimensions.paddingSizeSmall),

      Text(getTranslated('loading', context)!, style: robotoBold.copyWith(color: Theme.of(context).primaryColor)),

    ])) : GestureDetector(
      onTap: onTap as void Function()?,
      child: Container(
        width: double.infinity,
        height: buttonHeight, alignment: Alignment.center,
        decoration: BoxDecoration(
            color: backgroundColor ?? Theme.of(context).primaryColor,          borderRadius: BorderRadius.circular(borderRadius != null? borderRadius! : Dimensions.radiusDefault),
          border: Border.all(color: borderColor ?? Colors.transparent, width: borderColor != null ? 1 : 0),
          boxShadow: [
            if (backgroundColor == null || backgroundColor == Theme.of(context).primaryColor)
              BoxShadow(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.25),
                blurRadius: 15,
                spreadRadius: 1,
                offset: const Offset(0, 5),
              )
            else
              BoxShadow(
                color: Theme.of(context).hintColor.withValues(alpha: 0.1),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 3),
              ),
          ]
        ),
        child: Text(btnTxt!,
            style: textStyle ?? robotoBold.copyWith(
              fontSize: textSize,
              color: fontColor ?? Colors.white,
            )),
      ),
    );
  }
}
