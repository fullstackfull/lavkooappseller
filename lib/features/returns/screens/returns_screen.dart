import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/no_data_screen.dart';
import 'package:syriacosmeticsmanger/features/returns/controllers/return_controller.dart';
import 'package:syriacosmeticsmanger/features/returns/domain/models/return_models.dart';
import 'package:syriacosmeticsmanger/features/returns/screens/return_details_screen.dart';
import 'package:syriacosmeticsmanger/features/returns/widgets/return_widgets.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// The goods coming back to this shop.
///
/// A refund used to move money and leave the units unaccounted for. This is
/// where they are followed: authorised, on their way, arrived — restocked or
/// not — or refused.
class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  @override
  void initState() {
    super.initState();
    Provider.of<ReturnController>(context, listen: false).getReturns(clearStatus: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: getTranslated('returns', context)),
      body: Consumer<ReturnController>(
        builder: (context, returns, _) {
          final List<ReturnShipmentModel> shipments = returns.returns;

          return Column(children: [
            if (returns.statuses.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                  children: [
                    _chip(context, returns, null, getTranslated('all', context) ?? ''),
                    ...returns.statuses.map((status) => _chip(
                          context, returns, status,
                          getTranslated('return_status_$status', context) ?? status,
                        )),
                  ],
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => returns.getReturns(),
                color: Theme.of(context).cardColor,
                backgroundColor: Theme.of(context).primaryColor,
                child: shipments.isEmpty
                    ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * .6,
                          child: Center(
                            child: returns.isLoading
                                ? CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor))
                                : Column(mainAxisSize: MainAxisSize.min, children: [
                                    const NoDataScreen(),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeLarge),
                                      // Nothing coming back is a good day, not an
                                      // empty state to decorate.
                                      child: Text(getTranslated('no_returns_yet', context) ?? '',
                                          textAlign: TextAlign.center,
                                          style: robotoRegular.copyWith(
                                              fontSize: Dimensions.fontSizeSmall,
                                              color: Theme.of(context).hintColor)),
                                    ),
                                  ]),
                          ),
                        ),
                      ])
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                        itemCount: shipments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: Dimensions.paddingSizeSmall),
                        itemBuilder: (context, index) => ReturnCardWidget(
                          shipment: shipments[index],
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ReturnDetailsScreen(returnId: shipments[index].id),
                          )),
                        ),
                      ),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _chip(BuildContext context, ReturnController returns, String? status, String label) {
    final bool isSelected = returns.status == status;

    return Padding(
      padding: const EdgeInsets.only(right: Dimensions.paddingSizeExtraSmall),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        labelStyle: robotoMedium.copyWith(
          fontSize: Dimensions.fontSizeExtraSmall,
          color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).hintColor,
        ),
        onSelected: (_) => status == null
            ? returns.getReturns(clearStatus: true)
            : returns.getReturns(status: status),
      ),
    );
  }
}
