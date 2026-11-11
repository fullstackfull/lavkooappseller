import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/dropdown_decorator_widget.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';


class CustomDatePickerWidget extends StatefulWidget {
  final String? title;
  final String? text;
  final String? image;
  final bool requiredField;
  final bool fromClearance;
  final bool fromVacation;
  final Function? selectDate;
  final Color? borderColor;
  final bool? prefixIcon;
  final bool? isTitleTransparent;
  final bool? iconHintColor;
  const CustomDatePickerWidget({
    super.key,
    this.title,
    this.text,
    this.image,
    this.fromClearance = false,
    this.fromVacation = false,
    this.requiredField = false,
    this.selectDate,
    this.borderColor,
    this.prefixIcon = true,
    this.isTitleTransparent = false,
    this.iconHintColor = false,
  });

  @override
  State<CustomDatePickerWidget> createState() => _CustomDatePickerWidgetState();
}

class _CustomDatePickerWidgetState extends State<CustomDatePickerWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: !widget.fromClearance ? Dimensions.paddingSizeDefault : 0,
        right: !widget.fromClearance ? Dimensions.paddingSizeDefault : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownDecoratorWidget(
            title: widget.title,
            isTitleTransparent: widget.isTitleTransparent ?? false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSize),
              child: InkWell(
                onTap: widget.selectDate as void Function()?,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (widget.prefixIcon!) ...[
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Image.asset(
                          widget.image!,
                          color: widget.fromClearance
                              ? Theme.of(context).primaryColor
                              : Theme.of(context).hintColor,
                        ),
                      ),
                      const SizedBox(width: Dimensions.paddingSizeSmall),
                    ],

                    // 👇 التعديل الأساسي: Expanded + ellipsis
                    Expanded(
                      child: Text(
                        widget.text ?? '',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: robotoRegular.copyWith(
                          fontSize: Dimensions.fontSizeExtraSmall,
                          color: Theme.of(context).textTheme.bodyLarge!.color,
                        ),
                      ),
                    ),

                    if (!widget.prefixIcon!) ...[
                      const SizedBox(width: Dimensions.paddingSizeSmall),
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Image.asset(
                          widget.image!,
                          color: widget.fromClearance
                              ? (widget.iconHintColor ?? false)
                              ? Theme.of(context).hintColor
                              : Theme.of(context).primaryColor
                              : Theme.of(context).hintColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}