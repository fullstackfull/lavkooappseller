import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/images.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

class BankInfoWidget extends StatelessWidget {
  final String? name;
  final String? bank;
  final String? branch;
  final String? accountNo;

  const BankInfoWidget({
    super.key,
    this.name,
    this.bank,
    this.branch,
    this.accountNo,
  });

  @override
  Widget build(BuildContext context) {

    final bool isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),

      child: Container(
        width: MediaQuery.of(context).size.width,

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            Dimensions.paddingSizeSmall,
          ),

          image: const DecorationImage(
            image: AssetImage(Images.bankInfoBg),
            fit: BoxFit.cover,
          ),
        ),


        child: Container(

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              Dimensions.paddingSizeSmall,
            ),

            color: isDark
                ? Colors.black.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.20),
          ),


          child: Column(
            children: [

              const SizedBox(
                height: Dimensions.paddingSizeDefault,
              ),


              Row(
                children: [

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.paddingSizeDefault,
                    ),

                    child: SizedBox(
                      width: 40,
                      child: Image.asset(
                        Images.accountHolder,
                        color: isDark
                            ? Colors.white
                            : null,
                      ),
                    ),
                  ),


                  Expanded(
                    child: CardItem(
                      title: 'ac_holder',
                      value: name,
                    ),
                  ),

                ],
              ),



              Divider(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.30)
                    : Colors.black.withValues(alpha: 0.15),

                thickness: 1,
              ),



              CardItem(
                title: 'bank',
                value: bank,
              ),


              CardItem(
                title: 'branch',
                value: branch,
              ),


              CardItem(
                title: 'account_no',
                value: accountNo,
              ),



              const SizedBox(
                height: Dimensions.paddingSizeDefault,
              ),

            ],
          ),
        ),
      ),
    );
  }
}



class CardItem extends StatelessWidget {

  final String? title;
  final String? value;


  const CardItem({
    super.key,
    this.title,
    this.value,
  });



  @override
  Widget build(BuildContext context) {

    final bool isDark =
        Theme.of(context).brightness == Brightness.dark;


    final Color textColor = isDark
        ? Colors.white
        : Colors.black87;


    return Padding(

      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeSmall,
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeSmall,
      ),


      child: Row(

        children: [


          Text(
            '${getTranslated(title, context)} : ',

            style: robotoRegular.copyWith(
              color: textColor.withValues(alpha: 0.85),
            ),
          ),



          Expanded(

            child: Text(

              value ?? '',

              maxLines: 1,

              overflow: TextOverflow.ellipsis,


              style: robotoMedium.copyWith(
                color: textColor,
              ),

            ),
          ),

        ],
      ),
    );
  }
}