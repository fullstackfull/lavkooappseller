import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/product_scan_refusal_model.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// Tells the seller that the scanned code belongs to more than one of their products, and what they can do about it.
/// The sheet closes itself before it calls either callback.
Future<void> showAmbiguousCodeSheet({
  required BuildContext context,
  required List<ScanCandidateModel> candidates,
  required bool canChooseCountry,
  required ValueChanged<String> onCountryChosen,
  required VoidCallback onOpenProductList,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Dimensions.radiusLarge)),
    ),
    builder: (_) => AmbiguousCodeSheetWidget(
      candidates: candidates,
      canChooseCountry: canChooseCountry,
      onCountryChosen: onCountryChosen,
      onOpenProductList: onOpenProductList,
    ),
  );
}

/// With [canChooseCountry] the products sit in different countries, so each one can be tapped to scan again for its
/// country. Without it several products share the code inside one country, which no scan can settle: the seller is
/// pointed to the product list instead.
class AmbiguousCodeSheetWidget extends StatelessWidget {
  const AmbiguousCodeSheetWidget({
    super.key,
    required this.candidates,
    required this.canChooseCountry,
    required this.onCountryChosen,
    required this.onOpenProductList,
  });

  final List<ScanCandidateModel> candidates;
  final bool canChooseCountry;
  final ValueChanged<String> onCountryChosen;
  final VoidCallback onOpenProductList;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? explanation = canChooseCountry
        ? getTranslated('scan_shared_code_choose_country', context)
        : getTranslated('scan_shared_code_open_list', context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          getTranslated('scan_shared_code_title', context) ?? '',
                          style: robotoMedium.copyWith(
                            fontSize: Dimensions.fontSizeLarge,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                      const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                      Text(
                        explanation ?? '',
                        style: robotoRegular.copyWith(color: theme.textTheme.headlineLarge?.color),
                      ),
                      const SizedBox(height: Dimensions.paddingSizeDefault),
                      for (final ScanCandidateModel candidate in candidates)
                        _CandidateRowWidget(
                          candidate: candidate,
                          onTap: canChooseCountry && candidate.marketCode != null
                              ? () => _chooseCountry(context, candidate.marketCode!)
                              : null,
                        ),
                    ],
                  ),
                ),
              ),
              if (!canChooseCountry) ...[
                const SizedBox(height: Dimensions.paddingSizeSmall),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () => _openProductList(context),
                  child: Text(getTranslated('scan_open_product_list', context) ?? '', textAlign: TextAlign.center),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _chooseCountry(BuildContext context, String countryCode) {
    Navigator.of(context).pop();
    onCountryChosen(countryCode);
  }

  void _openProductList(BuildContext context) {
    Navigator.of(context).pop();
    onOpenProductList();
  }
}

class _CandidateRowWidget extends StatelessWidget {
  const _CandidateRowWidget({required this.candidate, required this.onTap});

  static const double _minimumTapTarget = 48;

  final ScanCandidateModel candidate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final BorderRadius borderRadius = BorderRadius.circular(Dimensions.radiusDefault);
    final String? countryName = _countryName(context, candidate);
    final bool isChoice = onTap != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
      child: Semantics(
        button: isChoice,
        child: Material(
          color: isChoice ? theme.cardColor : theme.hintColor.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: isChoice ? BorderSide(color: theme.hintColor.withValues(alpha: 0.3)) : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: borderRadius,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _minimumTapTarget),
              child: Padding(
                padding: const EdgeInsets.all(Dimensions.paddingSize),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _productName(candidate),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: robotoRegular.copyWith(color: theme.textTheme.bodyLarge?.color),
                          ),
                          if (countryName != null)
                            Text(
                              countryName,
                              style: robotoRegular.copyWith(
                                fontSize: Dimensions.fontSizeSmall,
                                color: theme.textTheme.headlineLarge?.color,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isChoice) ...[
                      const SizedBox(width: Dimensions.paddingSizeSmall),
                      Icon(Icons.chevron_right, color: theme.hintColor),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _productName(ScanCandidateModel candidate) {
    if (candidate.name.isNotEmpty) {
      return candidate.name;
    }
    return candidate.id == null ? '-' : '#${candidate.id}';
  }

  String? _countryName(BuildContext context, ScanCandidateModel candidate) {
    return switch (MarketScope.fromCountryCode(candidate.country)) {
      MarketScope.saudiArabia => getTranslated('scan_country_sa', context),
      MarketScope.unitedArabEmirates => getTranslated('scan_country_ae', context),
      MarketScope.kuwait => getTranslated('scan_country_kw', context),
      MarketScope.qatar => getTranslated('scan_country_qa', context),
      MarketScope.bahrain => getTranslated('scan_country_bh', context),
      MarketScope.oman => getTranslated('scan_country_om', context),
      MarketScope.allMarkets || null => candidate.country,
    };
  }
}
