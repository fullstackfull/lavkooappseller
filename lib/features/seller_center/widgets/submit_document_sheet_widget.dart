import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_button_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_snackbar_widget.dart';
import 'package:syriacosmeticsmanger/features/seller_center/controllers/seller_center_controller.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// Submit one KYC document: type, optional number and expiry, and an optional
/// photo of the document itself taken with the camera or picked from gallery.
class SubmitDocumentSheetWidget extends StatefulWidget {
  const SubmitDocumentSheetWidget({super.key});

  @override
  State<SubmitDocumentSheetWidget> createState() => _SubmitDocumentSheetWidgetState();
}

class _SubmitDocumentSheetWidgetState extends State<SubmitDocumentSheetWidget> {
  final TextEditingController _numberController = TextEditingController();
  String? _documentType;

  @override
  void initState() {
    super.initState();
    // The picked file lives on the shared controller, and a sheet dismissed by
    // swiping leaves it behind. Clearing on open means a new submission never
    // silently carries the file someone abandoned last time.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<SellerCenterController>(context, listen: false).setPickedDocument(null);
      }
    });
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument(ImageSource source) async {
    final XFile? picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: AppConstants.imageQuality,
    );
    if (picked != null && mounted) {
      Provider.of<SellerCenterController>(context, listen: false).setPickedDocument(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SellerCenterController>(
      builder: (context, sellerCenter, _) {
        // The required set is server-configured, so the picker offers exactly what
        // this store asks for rather than a hardcoded list.
        final List<String> types = sellerCenter.verification?.requiredDocuments.isNotEmpty == true
            ? sellerCenter.verification!.requiredDocuments
            : const ['identity', 'business_license'];
        // The list can change under the sheet — it starts as the fallback and is
        // replaced once the server's required set arrives. A selection that is
        // no longer offered would assert inside DropdownButton, so it is
        // re-pointed at the first real option instead.
        if (_documentType == null || !types.contains(_documentType)) {
          _documentType = types.first;
        }

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(Dimensions.radiusLarge)),
            ),
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(
                  child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).hintColor.withValues(alpha: .3),
                      borderRadius: BorderRadius.circular(Dimensions.radiusPill),
                    ),
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeDefault),

                Text(getTranslated('submit_document', context)!,
                    style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge,
                        color: Theme.of(context).textTheme.bodyLarge?.color)),
                const SizedBox(height: Dimensions.paddingSizeDefault),

                Text(getTranslated('document_type', context)!,
                    style: robotoRegular.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color)),
                const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).hintColor.withValues(alpha: .3)),
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                  ),
                  child: DropdownButton<String>(
                    value: _documentType,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: types.map((type) => DropdownMenuItem<String>(
                      value: type,
                      child: Text(getTranslated(type, context) ?? type,
                          style: robotoRegular.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color)),
                    )).toList(),
                    onChanged: (value) => setState(() => _documentType = value),
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeDefault),

                Text(getTranslated('document_number', context)!,
                    style: robotoRegular.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color)),
                const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                TextField(
                  controller: _numberController,
                  decoration: InputDecoration(
                    hintText: getTranslated('optional', context),
                    hintStyle: robotoRegular.copyWith(color: Theme.of(context).hintColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                      borderSide: BorderSide(color: Theme.of(context).hintColor.withValues(alpha: .3)),
                    ),
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeDefault),

                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () => _pickDocument(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined, size: Dimensions.iconSizeSmall),
                    label: Text(getTranslated('camera', context)!,
                        style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall)),
                  )),
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () => _pickDocument(ImageSource.gallery),
                    icon: const Icon(Icons.image_outlined, size: Dimensions.iconSizeSmall),
                    label: Text(getTranslated('gallery', context)!,
                        style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall)),
                  )),
                ]),

                if (sellerCenter.pickedDocument != null) ...[
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  Row(children: [
                    Icon(Icons.attach_file_rounded, size: Dimensions.iconSizeSmall,
                        color: Theme.of(context).colorScheme.onTertiaryContainer),
                    const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                    Expanded(
                      child: Text(sellerCenter.pickedDocument!.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: robotoRegular.copyWith(
                              fontSize: Dimensions.fontSizeSmall,
                              color: Theme.of(context).textTheme.bodyLarge?.color)),
                    ),
                    InkWell(
                      onTap: () => sellerCenter.setPickedDocument(null),
                      child: Icon(Icons.close_rounded, size: Dimensions.iconSizeSmall,
                          color: Theme.of(context).colorScheme.error),
                    ),
                  ]),
                ],
                const SizedBox(height: Dimensions.paddingSizeLarge),

                CustomButtonWidget(
                  isLoading: sellerCenter.isSubmitting,
                  btnTxt: getTranslated('submit', context),
                  backgroundColor: Theme.of(context).primaryColor,
                  onTap: () async {
                    if (_documentType == null) {
                      showCustomSnackBarWidget(getTranslated('document_type', context), context);
                      return;
                    }
                    final bool submitted = await sellerCenter.submitVerificationDocument(
                      documentType: _documentType!,
                      documentNumber: _numberController.text.trim(),
                    );
                    if (submitted && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
              ]),
            ),
          ),
        );
      },
    );
  }
}
