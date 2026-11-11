import 'dart:async';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/barcode/controllers/barcode_controller.dart';
import 'package:syriacosmeticsmanger/features/product/domain/models/product_model.dart';
import 'package:syriacosmeticsmanger/helper/price_converter.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_button_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_snackbar_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/textfeild/custom_text_feild_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class BarCodeGenerateScreen extends StatefulWidget {
  final Product? product;
  const BarCodeGenerateScreen({super.key, this.product});

  @override
  State<BarCodeGenerateScreen> createState() => _BarCodeGenerateScreenState();
}

class _BarCodeGenerateScreenState extends State<BarCodeGenerateScreen> {
  TextEditingController quantityController = TextEditingController();
  int barCodeQuantity = 4;

  @override
  void initState() {
    super.initState();
    quantityController.text = '4';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: getTranslated('bar_code_generator', context)),
      body: Consumer<BarcodeController>(
        builder: (context, barCodeController, _) {
          return Column(
            children: [
              // ═══════════════════════════════════════
              // القسم العلوي
              // ═══════════════════════════════════════
              Container(
                padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // كارت معلومات المنتج
                    _buildProductInfoCard(context),

                    const SizedBox(height: Dimensions.paddingSizeDefault),

                    // حقل الكمية
                    _buildQuantitySection(context, barCodeController),

                    const SizedBox(height: Dimensions.paddingSizeDefault),

                    // الأزرار
                    _buildActionButtons(context, barCodeController),
                  ],
                ),
              ),

              // ═══════════════════════════════════════
              // قسم الباركودات
              // ═══════════════════════════════════════
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                  child: GridView.builder(
                    itemCount: barCodeController.barCodeQuantity,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1 / 1.3,
                    ),
                    itemBuilder: (context, index) {
                      return _buildBarcodeCard(context);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // كارت معلومات المنتج
  // ═══════════════════════════════════════════════════
  Widget _buildProductInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: .1),
        ),
      ),
      child: Column(
        children: [
          // كود المنتج
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.qr_code_rounded,
                  size: 16,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: Dimensions.paddingSizeSmall),
              Text(
                '${getTranslated('code', context)} : ',
                style: robotoMedium.copyWith(
                  fontSize: Dimensions.fontSizeSmall,
                ),
              ),
              Expanded(
                child: Text(
                  '${widget.product!.code}',
                  style: robotoRegular.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeExtraSmall),
            child: Divider(
              color: Theme.of(context).primaryColor.withValues(alpha: .08),
              height: 1,
            ),
          ),

          // اسم المنتج
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 16,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: Dimensions.paddingSizeSmall),
              Text(
                '${getTranslated('product_name', context)} : ',
                style: robotoMedium.copyWith(
                  fontSize: Dimensions.fontSizeSmall,
                ),
              ),
              Expanded(
                child: Text(
                  '${widget.product!.name}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: robotoRegular.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // قسم الكمية
  // ═══════════════════════════════════════════════════
  Widget _buildQuantitySection(BuildContext context, BarcodeController barCodeController) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${getTranslated('qty', context)} (1-270)',
              style: robotoMedium.copyWith(
                fontSize: Dimensions.fontSizeDefault,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeSmall,
                vertical: Dimensions.paddingSizeVeryTiny,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                getTranslated('maximum_quantity_270', context) ?? '',
                style: robotoRegular.copyWith(
                  fontSize: Dimensions.fontSizeSmall,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        CustomTextFieldWidget(
          isPhoneNumber: true,
          controller: quantityController,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  // أزرار الإجراءات
  // ═══════════════════════════════════════════════════
  Widget _buildActionButtons(BuildContext context, BarcodeController barCodeController) {
    return Column(
      children: [
        // زر التوليد - كبير وبارز
        SizedBox(
          width: double.infinity,
          height: 48,
          child: CustomButtonWidget(
            btnTxt: getTranslated('generate', context),
            onTap: () {
              if (int.parse(quantityController.text) > 270 ||
                  int.parse(quantityController.text) == 0) {
                showCustomSnackBarWidget(
                  getTranslated('please_enter_from_1_to_270', context),
                  context,
                );
              } else {
                barCodeController.setBarCodeQuantity(
                  int.parse(quantityController.text),
                );
              }
            },
          ),
        ),

        const SizedBox(height: Dimensions.paddingSizeSmall),

        // زر التحميل وإعادة التعيين
        Row(
          children: [
            // زر التحميل
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: () async {
                    barCodeController
                        .barCodeDownload(
                      Get.context!,
                      widget.product!.id,
                      int.parse(quantityController.text),
                    )
                        .then((value) async {
                      _launchUrl(
                        Uri.parse(barCodeController.printBarCode!),
                      );
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Theme.of(context).primaryColor.withValues(alpha: .3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.download_rounded,
                        size: 18,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        getTranslated('download', context) ?? '',
                        style: robotoMedium.copyWith(
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: Dimensions.paddingSizeSmall),

            // زر إعادة التعيين
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: () {
                    quantityController.text = '4';
                    barCodeController.setBarCodeQuantity(4);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.error.withValues(alpha: .3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        getTranslated('reset', context) ?? '',
                        style: robotoMedium.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  // كارت الباركود الواحد
  // ═══════════════════════════════════════════════════
  Widget _buildBarcodeCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: .08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // اسم الشركة
          Text(
            AppConstants.companyName,
            style: robotoBold.copyWith(
              fontSize: Dimensions.fontSizeSmall,
              color: Theme.of(context).primaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 4),

          // اسم المنتج
          Text(
            '${widget.product!.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: robotoRegular.copyWith(
              fontSize: Dimensions.fontSizeSmall,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),

          const SizedBox(height: 4),

          // السعر
          Text(
            PriceConverter.convertPrice(context, widget.product!.unitPrice),
            style: robotoBold.copyWith(
              fontSize: Dimensions.fontSizeSmall,
            ),
          ),

          const SizedBox(height: Dimensions.paddingSizeExtraSmall),

          // الباركود
          BarcodeWidget(
            data: 'code : ${widget.product!.code}',
            style: robotoRegular.copyWith(
              fontSize: Dimensions.fontSizeSmall,
            ),
            barcode: Barcode.code128(),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }
}