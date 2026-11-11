import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/bank_info/screens/bank_editing_screen.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/features/bank_info/controllers/bank_info_controller.dart';
import 'package:syriacosmeticsmanger/theme/controllers/theme_controller.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/images.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/features/bank_info/widgets/bank_info_widget.dart';
import 'package:syriacosmeticsmanger/core/animations/app_animations.dart';

class BankInfoScreen extends StatelessWidget {
  const BankInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Provider.of<BankInfoController>(context, listen: false).setWarningValue(true,isUpdate: false);
    return Scaffold(
      appBar: CustomAppBarWidget(title:getTranslated('bank_info', context), isBackButtonExist: true,),
        body: Consumer<BankInfoController>(
          builder: (context, bankProvider, child) {
            String name = bankProvider.bankInfoOrEmpty.holderName?? '';
            String bank = bankProvider.bankInfoOrEmpty.bankName?? '';
            String branch = bankProvider.bankInfoOrEmpty.branch?? '';
            String accountNo = bankProvider.bankInfoOrEmpty.accountNo?? '';
            return Column(children: [

              bankProvider.showWarning?
                Padding(
                  padding:  const EdgeInsets.all(Dimensions.paddingSizeDefault),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault, vertical: Dimensions.paddingSizeMedium),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).primaryColor.withValues(alpha: 0.20)
                          : Theme.of(context).primaryColor.withValues(alpha: 0.06),

                      border: Border.all(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.45),
                        width: 1,
                      ),

                      borderRadius: BorderRadius.circular(16),

                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: Theme.of(context).brightness == Brightness.dark ? 0.20 : 0.05,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row( crossAxisAlignment:CrossAxisAlignment.center, children: [
                      SizedBox(width: 20, height: 20, child: Image.asset(Images.bulb)),
                      const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                      Expanded(
                        child: Text(getTranslated('you_should_fill_up', context)!, style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall,
                          color: Provider.of<ThemeController>(context, listen: false).darkTheme?
                          Theme.of(context).hintColor: Theme.of(context).primaryColor),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                      InkWell(
                        onTap: () {
                          bankProvider.setWarningValue(false, isUpdate: true);
                        },
                        child: SizedBox(width: 20, height: 20, child: Image.asset(Images.crossIcon))),
                      ],
                    ),
                  ),
                ).animateSectionEntrance(index: 0) : const SizedBox(),


              !bankProvider.showWarning ?
                  const SizedBox(height: Dimensions.paddingSizeSmall) : const SizedBox(),

                GestureDetector(
                  onTap: ()=>Navigator.push(context,
                      MaterialPageRoute(builder: (_) => BankEditingScreen(sellerModel: bankProvider.bankInfo))),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          Dimensions.paddingSizeSmall,
                        ),
                        border: Border.all(
                          width: 1,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).primaryColor.withValues(alpha: 0.55)
                              : Theme.of(context).primaryColor.withValues(alpha: 0.30),
                        ),
                      ),
                      padding:  const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault, vertical: Dimensions.paddingSizeSmall),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(getTranslated('edit_info', context)!, style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeLarge,
                            color: Provider.of<ThemeController>(context, listen: false).darkTheme?
                            Theme.of(context).hintColor: Theme.of(context).primaryColor)),
                        
                        SizedBox(height: 16, width: 16, child: Image.asset(Images.editIcon))
                      ],),
                    ),
                  ),
                ).animateSectionEntrance(index: 1),

                BankInfoWidget(name: name,bank: bank,branch: branch,accountNo: accountNo,).animateSectionEntrance(index: 2),
              ],
            );
          }
        ));
  }
}


