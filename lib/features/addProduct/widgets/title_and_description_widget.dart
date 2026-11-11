import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_snackbar_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/textfeild/custom_text_feild_widget.dart';
import 'package:syriacosmeticsmanger/features/ai/controllers/ai_controller.dart';
import 'package:syriacosmeticsmanger/features/splash/controllers/splash_controller.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/features/addProduct/controllers/add_product_controller.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';
class TitleAndDescriptionWidget extends StatefulWidget {
  final AddProductController resProvider;
  final int index;
  final String langCode;
  const TitleAndDescriptionWidget({super.key, required this.resProvider, required  this.index, required  this.langCode});

  @override
  State<TitleAndDescriptionWidget> createState() => _TitleAndDescriptionWidgetState();
}

class _TitleAndDescriptionWidgetState extends State<TitleAndDescriptionWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal : Dimensions.iconSizeSmall),
      // color: Colors.red,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Padding(
        //   padding: const EdgeInsets.symmetric(horizontal: 2),
        //   child: Text('${getTranslated('inset_lang_wise_title_des', context)}',
        //     style: robotoRegular.copyWith(color: Theme.of(context).hintColor,
        //       fontSize: Dimensions.fontSizeSmall),),
        // ),
        // const SizedBox(height: Dimensions.paddingSizeSmall,),

        if(Provider.of<SplashController>(context,listen: false).configModel?.isAiFeatureActive == 1)
          Consumer<AiController>(
              builder: (context, aiController, child){
                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () {
                        if(widget.resProvider.titleControllerList[widget.index].text.isEmpty) {
                          showCustomSnackBarWidget('${getTranslated('product_name_required', context)}', context);
                        }else{
                          aiController.generateTitle(
                            title: widget.resProvider.titleControllerList[widget.index].text.trim(),
                            langCode: widget.langCode,
                          ).then((value) {
                            if(aiController.titleModel != null) {
                              widget.resProvider.titleControllerList[widget.index].text = aiController.titleModel?.data ?? '';
                              setState(() {});
                            }
                          });
                        }
                      },
                      child: !aiController.titleLoading ? const Icon(Icons.auto_awesome, color: const Color(0xFF1F7A55)) : Shimmer.fromColors(
                        baseColor: Theme.of(context).primaryColor,
                        highlightColor: ShimmerColors.highlight(context),
                        child: Row(children: [
                          const Icon(Icons.auto_awesome, color: const Color(0xFF1F7A55)),
                          const SizedBox(width: Dimensions.paddingSizeExtraSmall),

                          Text(getTranslated('generating', context) ?? '', style: robotoBold.copyWith(color: const Color(0xFF1F7A55))),
                        ]),
                      ),
                    ),
                  ],
                );
              }
          ),


        const SizedBox(height: Dimensions.paddingSizeSmall),

        CustomTextFieldWidget(
          formProduct: true,
          textInputAction: TextInputAction.next,
          controller: TextEditingController(text: widget.resProvider.titleControllerList[widget.index].text),
          textInputType: TextInputType.name,
          required: true,
          hintText: getTranslated('product_name', context),
          border: true,
          borderColor: Theme.of(context).primaryColor.withValues(alpha: .25),
          onChanged: (String text) {
            widget.resProvider.setTitle(widget.index, text);
          },
        ),
        const SizedBox(height: Dimensions.paddingSizeSmall),


        // Row(
        //   children: [
        //     Text(getTranslated('product_description',context)!,
        //       style: robotoRegular.copyWith(color:  ColorResources.titleColor(context),
        //           fontSize: Dimensions.fontSizeDefault),),
        //
        //     Text('*',style: robotoBold.copyWith(color: ColorResources.mainCardFourColor(context),
        //         fontSize: Dimensions.fontSizeDefault),),
        //   ],
        // ),

        if(Provider.of<SplashController>(context,listen: false).configModel?.isAiFeatureActive == 1)
          Consumer<AiController>(
              builder: (context, aiController, child){
                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () {
                        if(widget.resProvider.titleControllerList[widget.index].text.isEmpty) {
                          showCustomSnackBarWidget('${getTranslated('product_name_required', context)}', context);
                        }else{
                          aiController.generateDescription (
                            title: widget.resProvider.titleControllerList[widget.index].text.trim(),
                            langCode: widget.langCode,
                          ).then((value) {
                            if(aiController.description?.data != null && aiController.description!.data!.isNotEmpty) {
                              widget.resProvider.descriptionControllerList[widget.index].text = aiController.description?.data ?? '';
                              setState(() {});
                            }
                          });
                        }
                      },
                      child: !aiController.descLoading ? const Icon(Icons.auto_awesome, color: const Color(0xFF1F7A55)) : Shimmer.fromColors(
                        baseColor: Theme.of(context).primaryColor,
                        highlightColor: ShimmerColors.highlight(context),
                        child: Row(children: [
                          const Icon(Icons.auto_awesome, color: const Color(0xFF1F7A55)),
                          const SizedBox(width: Dimensions.paddingSizeExtraSmall),

                          Text(getTranslated('generating', context) ?? '', style: robotoBold.copyWith(color: const Color(0xFF1F7A55))),
                        ]),
                      ),
                    ),
                  ],
                );
              }
          ),
        const SizedBox(height: Dimensions.paddingSizeSmall),

        CustomTextFieldWidget(
          formProduct: true,
          required: true,
          isDescription: true,
          controller: TextEditingController(text: widget.resProvider.descriptionControllerList[widget.index].text),
          onChanged: (String text) => widget.resProvider.setDescription(widget.index, text),
          textInputType: TextInputType.multiline,
          maxLine: 3,
          border: true,
          borderColor: Theme.of(context).primaryColor.withValues(alpha: .25),
          hintText: getTranslated('product_description', context),
        ),
        const SizedBox(height: Dimensions.paddingSizeSmall,),

      ],
      ),
    );
  }
}
