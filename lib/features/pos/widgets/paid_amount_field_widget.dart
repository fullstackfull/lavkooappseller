import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/textfeild/custom_text_feild_widget.dart';
import 'package:syriacosmeticsmanger/features/storefront/market_money.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';

class PaidAmountFieldWidget extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isEnabled;
  final bool isPaidAmountLess;
  final ValueChanged<String> onChanged;
  const PaidAmountFieldWidget({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isEnabled,
    required this.isPaidAmountLess,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CustomTextFieldWidget(
      idDate: !isEnabled,
      border: true,
      hintText: getTranslated('amount', context),
      controller: controller,
      focusNode: focusNode,
      textInputAction: TextInputAction.next,
      textInputType: MarketMoney.keyboardType(outsideMarket: TextInputType.number),
      borderColor: isPaidAmountLess ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
      isAmount: MarketMoney.current() == null,
      inputFormatters: MarketMoney.inputFormatters(),
      focusBorder: true,
      onChanged: onChanged,
    );
  }
}
