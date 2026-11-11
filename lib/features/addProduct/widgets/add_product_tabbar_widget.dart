import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';

class AddProductTitleBar extends StatelessWidget {

  final TabController tabController;
  final List<Tab> tabs;

  const AddProductTitleBar({
    super.key,
    required this.tabController,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {

    return SizedBox(
      height: 60, // زودناها شوي بسبب وجود icon + text
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 0),
        child: TabBar(
          controller: tabController,
          tabs: tabs,

          labelPadding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeSmall,
          ),

          labelColor: Theme.of(context).cardColor,
          unselectedLabelColor: Colors.grey,

          indicatorColor: Theme.of(context).primaryColor,
          dividerColor: Colors.transparent,

          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: EdgeInsets.zero,

          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(
              Dimensions.radiusSmall,
            ),
            border: Border.all(
              color: Theme.of(context).primaryColor,
            ),
            color: Theme.of(context).primaryColor,
          ),
        ),
      ),
    );
  }
}