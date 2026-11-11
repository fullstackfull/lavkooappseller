import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/features/brand_claims/controllers/brand_claim_controller.dart';
import 'package:syriacosmeticsmanger/features/brand_claims/domain/models/brand_claim_models.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// Which brands this shop sells under, and what has been done about each.
///
/// Built around the question a seller has — which of my brands is going to be a
/// problem — rather than around the claims table. Brands needing action come
/// first; the rest are there but not shouting.
class BrandClaimsScreen extends StatefulWidget {
  const BrandClaimsScreen({super.key});

  @override
  State<BrandClaimsScreen> createState() => _BrandClaimsScreenState();
}

class _BrandClaimsScreenState extends State<BrandClaimsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => Provider.of<BrandClaimController>(context, listen: false).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: getTranslated('brands', context)),
      body: Consumer<BrandClaimController>(
        builder: (context, brands, _) {
          if (brands.isLoading && brands.exposure.isEmpty && brands.claims.isEmpty) {
            return Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)),
            );
          }

          if (brands.exposure.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(Dimensions.paddingSizeExtraLarge),
                child: Text(getTranslated('you_do_not_sell_under_any_brand', context) ?? '',
                    textAlign: TextAlign.center,
                    style: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
              ),
            );
          }

          // Needing action first. The rest are listed because a seller checking
          // their standing wants the whole picture, not only the bad half.
          final List<BrandExposureModel> ordered = [
            ...brands.brandsNeedingAction,
            ...brands.exposure.where((brand) => !brand.needsAction),
          ];

          return RefreshIndicator(
            onRefresh: brands.load,
            color: Theme.of(context).cardColor,
            backgroundColor: Theme.of(context).primaryColor,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              children: [
                Text(
                  getTranslated(
                          brands.enforcing
                              ? 'brand_enforcement_is_on'
                              : 'brand_enforcement_is_off',
                          context) ??
                      '',
                  style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor),
                ),
                const SizedBox(height: Dimensions.paddingSizeDefault),
                ...ordered.map((brand) => _brand(context, brands, brand)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _brand(BuildContext context, BrandClaimController brands, BrandExposureModel brand) {
    final BrandClaimModel? claim = brands.claimFor(brand.brandId);
    final Color tone = brand.needsAction ? Colors.orange.shade700 : Colors.green.shade600;

    return Container(
      margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(brand.needsAction ? Icons.gpp_maybe_outlined : Icons.verified_user_outlined,
              size: 20, color: tone),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Expanded(
            child: Text(brand.brandName ?? '#${brand.brandId}',
                style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeDefault)),
          ),
          Text('${brand.products} ${getTranslated('listings', context) ?? ''}',
              style: robotoRegular.copyWith(
                  fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
        ]),
        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
        Text(
          getTranslated(
                  brand.needsAction
                      ? (brands.enforcing
                          ? 'these_listings_are_blocked'
                          : 'somebody_else_holds_this_brand')
                      : 'you_may_list_under_this_brand',
                  context) ??
              '',
          style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: tone),
        ),

        if (claim != null) ...[
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Text(
            '${getTranslated('your_claim', context) ?? ''}: '
            '${getTranslated('claim_status_${claim.status}', context) ?? claim.status}'
            ' · ${getTranslated('claim_type_${claim.claimType}', context) ?? claim.claimType}',
            style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall),
          ),
          if (claim.reviewNote != null && claim.reviewNote!.isNotEmpty)
            Text(claim.reviewNote!,
                style: robotoRegular.copyWith(
                    fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
          if (claim.documents.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Dimensions.paddingSizeExtraSmall),
              child: Text(
                '${claim.documents.length} ${getTranslated('documents_attached', context) ?? ''}',
                style: robotoRegular.copyWith(
                    fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor),
              ),
            ),
        ],

        const SizedBox(height: Dimensions.paddingSizeSmall),
        Wrap(spacing: Dimensions.paddingSizeSmall, children: [
          if (claim == null || claim.isEditable)
            TextButton(
              onPressed: brands.isBusy ? null : () => _openClaimSheet(context, brands, brand, claim),
              child: Text(
                  getTranslated(claim == null ? 'claim_this_brand' : 'edit_claim', context) ?? '',
                  style: robotoMedium.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall,
                      color: Theme.of(context).primaryColor)),
            ),
          if (claim != null && claim.isEditable && claim.documents.isNotEmpty)
            TextButton(
              onPressed: brands.isBusy ? null : () => brands.submit(claim.id),
              child: Text(getTranslated('send_for_review', context) ?? '',
                  style: robotoMedium.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall,
                      color: Theme.of(context).primaryColor)),
            ),
          if (claim != null && claim.isPending)
            TextButton(
              onPressed: brands.isBusy ? null : () => brands.withdraw(claim.id),
              child: Text(getTranslated('take_it_back', context) ?? '',
                  style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
            ),
        ]),
      ]),
    );
  }

  Future<void> _openClaimSheet(
    BuildContext context,
    BrandClaimController brands,
    BrandExposureModel brand,
    BrandClaimModel? existing,
  ) async {
    final TextEditingController statement = TextEditingController(text: existing?.statement ?? '');
    String claimType = existing?.claimType ?? 'owner';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Dimensions.radiusLarge)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: Dimensions.paddingSizeDefault,
          right: Dimensions.paddingSizeDefault,
          top: Dimensions.paddingSizeDefault,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + Dimensions.paddingSizeDefault,
        ),
        child: StatefulBuilder(
          builder: (sheetContext, setSheetState) => SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(brand.brandName ?? '#${brand.brandId}',
                  style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge)),
              const SizedBox(height: Dimensions.paddingSizeExtraSmall),
              Text(getTranslated('a_person_reviews_this_claim', context) ?? '',
                  style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
              const SizedBox(height: Dimensions.paddingSizeDefault),

              DropdownButtonFormField<String>(
                initialValue: claimType,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: getTranslated('you_are_the', context) ?? '',
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
                ),
                items: ['owner', 'authorized_reseller', 'distributor']
                    .map((type) => DropdownMenuItem<String>(
                          value: type,
                          child: Text(getTranslated('claim_type_$type', context) ?? type,
                              style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall)),
                        ))
                    .toList(),
                onChanged: (value) => setSheetState(() => claimType = value ?? 'owner'),
              ),
              const SizedBox(height: Dimensions.paddingSizeSmall),
              TextField(
                controller: statement,
                maxLines: 3,
                style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall),
                decoration: InputDecoration(
                  labelText: getTranslated('explain_the_relationship', context) ?? '',
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
                ),
              ),

              if (existing != null && existing.isEditable) ...[
                const SizedBox(height: Dimensions.paddingSizeDefault),
                Text(getTranslated('evidence', context) ?? '',
                    style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeDefault)),
                const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                // Said plainly: a claim with nothing behind it is refused when
                // sent, so there is no point letting the seller discover that
                // at the last step.
                Text(getTranslated('a_claim_needs_at_least_one_document', context) ?? '',
                    style: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeExtraSmall,
                        color: Theme.of(context).hintColor)),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                ...existing.documents.map((document) => Row(children: [
                      Expanded(
                        child: Text(
                          '${getTranslated(document.documentType, context) ?? document.documentType}'
                          '${document.originalName == null ? '' : ' · ${document.originalName}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () async {
                          await brands.removeDocument(existing.id, document.id);
                          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                        },
                      ),
                    ])),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                Wrap(spacing: Dimensions.paddingSizeSmall, children: [
                  'trademark_certificate',
                  'authorization_letter',
                  'invoice',
                ].map((type) => OutlinedButton(
                      onPressed: () async {
                        await _pickAndAttach(sheetContext, brands, existing.id, type);
                      },
                      child: Text(getTranslated('add_$type', context) ?? type,
                          style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall)),
                    )).toList()),
              ],

              const SizedBox(height: Dimensions.paddingSizeLarge),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                  onPressed: () async {
                    await brands.saveClaim(
                      brandId: brand.brandId,
                      claimType: claimType,
                      statement: statement.text.trim(),
                    );
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  },
                  child: Text(getTranslated('save', context) ?? '',
                      style: robotoMedium.copyWith(color: Colors.white)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );

    statement.dispose();
  }

  Future<void> _pickAndAttach(
    BuildContext sheetContext,
    BrandClaimController brands,
    int claimId,
    String documentType,
  ) async {
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );

    final PlatformFile? file = picked?.files.firstOrNull;
    if (file == null || file.bytes == null) return;

    await brands.attachDocument(
      claimId,
      documentType,
      MultipartFile.fromBytes(file.bytes!, filename: file.name),
    );

    // Closed rather than refreshed in place: the sheet was opened with a claim
    // that has since changed, and reopening it shows the new state rather than
    // patching the old one.
    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
  }
}
