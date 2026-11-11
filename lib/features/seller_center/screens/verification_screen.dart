import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/features/seller_center/controllers/seller_center_controller.dart';
import 'package:syriacosmeticsmanger/features/seller_center/domain/models/verification_models.dart';
import 'package:syriacosmeticsmanger/features/seller_center/widgets/status_pill_widget.dart';
import 'package:syriacosmeticsmanger/features/seller_center/widgets/submit_document_sheet_widget.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// KYC: what the seller has submitted, what each document's review said, and
/// what is still outstanding before payouts unlock.
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  @override
  void initState() {
    Provider.of<SellerCenterController>(context, listen: false).getVerification();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: getTranslated('verification', context)),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Theme.of(context).primaryColor,
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const SubmitDocumentSheetWidget(),
        ),
        icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
        label: Text(getTranslated('submit_document', context)!,
            style: robotoMedium.copyWith(color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: () => Provider.of<SellerCenterController>(context, listen: false).getVerification(),
        color: Theme.of(context).cardColor,
        backgroundColor: Theme.of(context).primaryColor,
        child: Consumer<SellerCenterController>(
          builder: (context, sellerCenter, _) {
            final VerificationStatusModel? verification = sellerCenter.verification;
            if (verification == null) {
              return ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * .6,
                  child: Center(child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                  )),
                ),
              ]);
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault,
                  Dimensions.paddingSizeDefault, Dimensions.floatingNavClearance),
              children: [
                _CardWidget(children: [
                  Row(children: [
                    Text(getTranslated('verification_status', context)!,
                        style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge,
                            color: Theme.of(context).textTheme.bodyLarge?.color)),
                    const Spacer(),
                    StatusPillWidget(status: verification.overallStatus),
                  ]),
                  if (verification.kycRequiredForPayout) ...[
                    const SizedBox(height: Dimensions.paddingSizeSmall),
                    Text(getTranslated('kyc_required_for_payout_note', context)!,
                        style: robotoRegular.copyWith(
                            fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
                  ],
                ]),

                if (verification.outstandingDocuments.isNotEmpty) ...[
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  _CardWidget(children: [
                    Text(getTranslated('required_documents', context)!,
                        style: robotoMedium.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color)),
                    const SizedBox(height: Dimensions.paddingSizeSmall),
                    Wrap(
                      spacing: Dimensions.paddingSizeSmall,
                      runSpacing: Dimensions.paddingSizeSmall,
                      children: verification.outstandingDocuments.map((type) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Dimensions.paddingSizeSmall, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.tertiary.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(Dimensions.radiusPill),
                        ),
                        child: Text(getTranslated(type, context) ?? type,
                            style: robotoRegular.copyWith(
                                fontSize: Dimensions.fontSizeSmall,
                                color: Theme.of(context).colorScheme.tertiary)),
                      )).toList(),
                    ),
                  ]),
                ],

                const SizedBox(height: Dimensions.paddingSizeSmall),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeSmall),
                  child: Text(getTranslated('submitted_documents', context)!,
                      style: robotoMedium.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color)),
                ),

                if (verification.documents.isEmpty)
                  _CardWidget(children: [
                    Text(getTranslated('no_document_submitted_yet', context)!,
                        style: robotoRegular.copyWith(color: Theme.of(context).hintColor)),
                  ])
                else
                  ...verification.documents.map((document) => Padding(
                    padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                    child: _DocumentCardWidget(document: document),
                  )),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DocumentCardWidget extends StatelessWidget {
  final VerificationDocumentModel document;
  const _DocumentCardWidget({required this.document});

  @override
  Widget build(BuildContext context) {
    return _CardWidget(children: [
      Row(children: [
        Expanded(
          child: Text(getTranslated(document.documentType ?? '', context) ?? document.documentType ?? '',
              style: robotoMedium.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color)),
        ),
        StatusPillWidget(status: document.status),
      ]),

      if (document.documentNumber != null && document.documentNumber!.isNotEmpty) ...[
        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
        Text(document.documentNumber!,
            style: robotoRegular.copyWith(
                fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
      ],

      if (document.expiresAt != null) ...[
        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
        Text('${getTranslated('expires_at', context)}: ${document.expiresAt}',
            style: robotoRegular.copyWith(
                fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
      ],

      // The reason a document was turned down is the one thing a seller must be
      // able to read — it is what tells them how to fix the resubmission.
      if (document.status == 'rejected' && document.rejectionReason != null) ...[
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.error.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
          ),
          child: Text(document.rejectionReason!,
              style: robotoRegular.copyWith(
                  fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).colorScheme.error)),
        ),
      ],
    ]);
  }
}

class _CardWidget extends StatelessWidget {
  final List<Widget> children;
  const _CardWidget({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        boxShadow: [
          BoxShadow(color: Theme.of(context).primaryColor.withValues(alpha: .05),
              spreadRadius: -3, blurRadius: 12, offset: Offset.fromDirection(0, 6)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}
