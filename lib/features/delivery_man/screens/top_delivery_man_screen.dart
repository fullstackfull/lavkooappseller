import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/features/delivery_man/controllers/delivery_man_controller.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/features/delivery_man/widgets/top_delivery_man_view_widget.dart';

class TopDeliveryMAnScreen extends StatelessWidget {
  const TopDeliveryMAnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: getTranslated('top_delivery_man_list', context),isBackButtonExist: true),
        body: RefreshIndicator(
          onRefresh: ()async{
            Provider.of<DeliveryManController>(context, listen: false).getTopDeliveryManList(context);
          },
          child: const SingleChildScrollView(
            child: TopDeliveryManViewWidget(),
          ),
        ));
  }
}
