import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/features/product/screens/most_popular_product_screen.dart';
import 'package:syriacosmeticsmanger/features/product/screens/top_selling_product_screen.dart';

class ProductListScreen extends StatelessWidget {
  final String title;
  final bool isPopular;
  const ProductListScreen({super.key, required this.title, this.isPopular = false});

  @override
  Widget build(BuildContext context) {
    final ScrollController scrollController = ScrollController();

    return Scaffold(
      appBar: CustomAppBarWidget(title: getTranslated(title, context)),
      body: SingleChildScrollView(
        controller: scrollController,
        child: Container(child: isPopular?
         const MostPopularProductScreen():
         TopSellingProductScreen(scrollController: scrollController)),
      ),
    );
  }
}
