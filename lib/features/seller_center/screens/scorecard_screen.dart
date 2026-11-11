import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/features/seller_center/controllers/seller_center_controller.dart';
import 'package:syriacosmeticsmanger/features/seller_center/domain/models/seller_center_models.dart';
import 'package:syriacosmeticsmanger/features/seller_center/widgets/tier_badge_widget.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// The full performance scorecard — the same metrics and health tier the
/// admin sees, so the seller always knows where they stand and why.
class ScorecardScreen extends StatefulWidget {
  const ScorecardScreen({super.key});

  @override
  State<ScorecardScreen> createState() => _ScorecardScreenState();
}

class _ScorecardScreenState extends State<ScorecardScreen> {
  @override
  void initState() {
    if (Provider.of<SellerCenterController>(context, listen: false).overview == null) {
      Provider.of<SellerCenterController>(context, listen: false).getSellerCenterOverview();
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: getTranslated('seller_center', context)),
      body: RefreshIndicator(
        onRefresh: () {
          final SellerCenterController sellerCenter = Provider.of<SellerCenterController>(context, listen: false);
          // First load (or a failed one) needs the whole overview; after that a
          // pull only refreshes the performance metrics.
          return sellerCenter.overview == null
              ? sellerCenter.getSellerCenterOverview()
              : sellerCenter.getScorecard();
        },
        color: Theme.of(context).cardColor,
        backgroundColor: Theme.of(context).primaryColor,
        child: Consumer<SellerCenterController>(
          builder: (context, sellerCenter, _) {
            final ScorecardModel? scorecard = sellerCenter.scorecard;
            if (scorecard == null) {
              // Scrollable so pull-to-refresh still works when the first
              // request failed and the screen is stuck on this state.
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * .6,
                    child: Center(child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                    )),
                  ),
                ],
              );
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              children: [
                _SectionCardWidget(children: [
                  Row(children: [
                    Text(getTranslated('performance', context)!,
                      style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge,
                          color: Theme.of(context).textTheme.bodyLarge?.color),
                    ),
                    const Spacer(),
                    TierBadgeWidget(tier: scorecard.tier, fontSize: Dimensions.fontSizeDefault),
                  ]),
                  const SizedBox(height: Dimensions.paddingSizeDefault),
                  Row(children: [
                    _CountStatWidget(title: 'total_orders', value: '${scorecard.ordersTotal}'),
                    _CountStatWidget(title: 'rating', value: scorecard.avgRating != null
                        ? scorecard.avgRating!.toStringAsFixed(1) : '-'),
                    _CountStatWidget(title: 'reviews', value: '${scorecard.reviewCount}'),
                  ]),
                ]),
                const SizedBox(height: Dimensions.paddingSizeSmall),

                _SectionCardWidget(children: [
                  // Fulfilment has no ceiling — it is the one rate a seller wants
                  // high, so there is no line to be over.
                  _RateRowWidget(title: 'fulfillment_rate', rate: scorecard.fulfillmentRate,
                      color: Theme.of(context).colorScheme.onTertiaryContainer),
                  _RateRowWidget(title: 'cancellation_rate', rate: scorecard.cancellationRate,
                      ceiling: scorecard.ceilingFor('cancellation_rate'),
                      color: _riskColor(context, scorecard, 'cancellation_rate', scorecard.cancellationRate)),
                  _RateRowWidget(title: 'return_rate', rate: scorecard.returnRate,
                      ceiling: scorecard.ceilingFor('return_rate'),
                      color: _riskColor(context, scorecard, 'return_rate', scorecard.returnRate)),
                  _RateRowWidget(title: 'refund_rate', rate: scorecard.refundRate,
                      ceiling: scorecard.ceilingFor('refund_rate'),
                      color: _riskColor(context, scorecard, 'refund_rate', scorecard.refundRate)),
                ]),
                const SizedBox(height: Dimensions.paddingSizeSmall),

                if (scorecard.openBreaches.isNotEmpty)
                  _SectionCardWidget(children: [
                    Text(getTranslated('lines_you_are_currently_over', context)!,
                      style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge,
                          color: Theme.of(context).textTheme.bodyLarge?.color)),
                    const SizedBox(height: Dimensions.paddingSizeSmall),
                    // The record a suspension would rest on. It was written daily
                    // and shown nowhere, so a seller learned about a breach when
                    // somebody acted on it.
                    ...scorecard.openBreaches.map((SlaBreachModel breach) => _DetailRowWidget(
                      title: breach.metric,
                      // The measurement beside the line it crossed. A breach
                      // without its threshold is an accusation; with it, a task.
                      value: '${_asMetric(breach.metric, breach.actualValue)}'
                          ' / ${_asMetric(breach.metric, breach.threshold)}',
                      valueColor: Theme.of(context).colorScheme.error,
                    )),
                  ]),
                const SizedBox(height: Dimensions.paddingSizeSmall),

                _SectionCardWidget(children: [
                  _DetailRowWidget(title: 'delivered', value: '${scorecard.delivered}'),
                  _DetailRowWidget(title: 'canceled', value: '${scorecard.canceled}'),
                  _DetailRowWidget(title: 'returned', value: '${scorecard.returned}'),
                  _DetailRowWidget(title: 'failed', value: '${scorecard.failed}'),
                  Divider(height: Dimensions.paddingSizeLarge, color: Theme.of(context).hintColor.withValues(alpha: .15)),
                  _DetailRowWidget(title: 'moderation_strikes', value: '${scorecard.moderationStrikes}',
                      valueColor: scorecard.moderationStrikes > 0 ? Theme.of(context).colorScheme.error : null),
                  _DetailRowWidget(title: 'verification',
                      value: getTranslated(sellerCenter.overview?.verificationStatus ?? scorecard.kycStatus ?? 'unverified', context) ?? ''),
                ]),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Colour a rate against the marketplace's published ceiling, never against a
  /// number written into this screen.
  ///
  /// The app used to carry its own amber and red thresholds. A market that
  /// lowered its cancellation ceiling to 8% then had a phone calling 10%
  /// comfortable, a web panel calling it a breach, and the platform opening one
  /// — three answers to a question with one correct answer.
  ///
  /// With no published ceiling the rate is drawn plainly. Judging it against a
  /// guess is the bug, not the absence of a colour.
  Color _riskColor(BuildContext context, ScorecardModel scorecard, String metric, double rate) {
    // The server's own verdict wins where it has one. It evaluates on the same
    // metrics but with the rounding and the grace the policy actually applies,
    // so a client that recomputed the comparison could disagree with the breach
    // the platform just opened.
    if (scorecard.isOverTheLine(metric)) {
      return Theme.of(context).colorScheme.error;
    }

    final double? ceiling = scorecard.ceilingFor(metric);

    if (ceiling == null || ceiling <= 0) {
      return Theme.of(context).colorScheme.onTertiaryContainer;
    }
    if (rate > ceiling) {
      return Theme.of(context).colorScheme.error;
    }
    // Approaching is worth a warning: the point of showing the line is that a
    // seller can stop short of it.
    if (rate >= ceiling * .8) {
      return Theme.of(context).colorScheme.tertiary;
    }
    return Theme.of(context).colorScheme.onTertiaryContainer;
  }

  /// A metric in the units it is actually in.
  ///
  /// Every SLA line but one is a rate; the rating is a rating. Printing "3.5" as
  /// "350.0%" would make the one metric a seller understands instantly the one
  /// that reads as nonsense.
  String _asMetric(String metric, double value) => metric.endsWith('_rating')
      ? value.toStringAsFixed(2)
      : '${(value * 100).toStringAsFixed(1)}%';
}

class _SectionCardWidget extends StatelessWidget {
  final List<Widget> children;
  const _SectionCardWidget({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
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

class _CountStatWidget extends StatelessWidget {
  final String title;
  final String value;
  const _CountStatWidget({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(value, style: robotoBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge,
            color: Theme.of(context).textTheme.bodyLarge?.color)),
        const SizedBox(height: 2),
        Text(getTranslated(title, context)!,
          style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor),
          maxLines: 1, overflow: TextOverflow.ellipsis,
        ),
      ]),
    );
  }
}

class _RateRowWidget extends StatelessWidget {
  final String title;
  final double rate;
  final Color color;

  /// The marketplace's published limit, or null when it has not published one.
  final double? ceiling;

  const _RateRowWidget({required this.title, required this.rate, required this.color, this.ceiling});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeExtraSmall),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(getTranslated(title, context)!,
              style: robotoRegular.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color)),
          Text('${(rate * 100).toStringAsFixed(1)}%', style: robotoMedium.copyWith(color: color)),
        ]),
        // The ceiling in words beside the bar, because the bar alone cannot say
        // where the line is: a rate is a statistic, a rate beside its limit is a
        // position.
        if (ceiling != null && ceiling! > 0)
          Text('${getTranslated('ceiling_is', context) ?? ''} ${(ceiling! * 100).toStringAsFixed(1)}%',
              style: robotoRegular.copyWith(
                  fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
        ClipRRect(
          borderRadius: BorderRadius.circular(Dimensions.radiusPill),
          child: LinearProgressIndicator(
            // Scaled to the ceiling rather than to 100%, so a bar that looks
            // full means "at the line" rather than "every order cancelled".
            value: _fill(),
            minHeight: 6,
            backgroundColor: Theme.of(context).hintColor.withValues(alpha: .12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ]),
    );
  }

  double _fill() {
    if (ceiling == null || ceiling! <= 0) {
      return rate.clamp(0, 1).toDouble();
    }

    return (rate / ceiling!).clamp(0, 1).toDouble();
  }
}

class _DetailRowWidget extends StatelessWidget {
  final String title;
  final String value;
  final Color? valueColor;
  const _DetailRowWidget({required this.title, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeExtraSmall),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        // Falls back to the key rather than asserting it away. Some titles here
        // are metric names the server chose, so a marketplace that adds an SLA
        // line the app has no copy for must show its name, not crash.
        Text(getTranslated(title, context) ?? title,
            style: robotoRegular.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color)),
        Text(value, style: robotoMedium.copyWith(
            color: valueColor ?? Theme.of(context).textTheme.bodyLarge?.color)),
      ]),
    );
  }
}
