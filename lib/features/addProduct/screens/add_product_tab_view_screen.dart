import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/features/addProduct/domain/models/add_product_model.dart';
import 'package:syriacosmeticsmanger/features/addProduct/domain/models/edt_product_model.dart';
import 'package:syriacosmeticsmanger/features/addProduct/domain/models/product_general_info_data_model.dart';
import 'package:syriacosmeticsmanger/features/addProduct/screens/add_product_next_screen.dart';
import 'package:syriacosmeticsmanger/features/addProduct/screens/add_product_screen.dart';
import 'package:syriacosmeticsmanger/features/addProduct/screens/add_product_seo_screen.dart';
import 'package:syriacosmeticsmanger/features/addProduct/widgets/add_product_tabbar_widget.dart';
import 'package:syriacosmeticsmanger/features/ai/widgets/genertate_count_widget.dart';
import 'package:syriacosmeticsmanger/features/product/domain/models/product_model.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';

class AddProductTabView extends StatefulWidget {
  final Product? product;
  final AddProductModel? addProduct;
  final EditProductModel? editProduct;
  final bool fromHome;
  const AddProductTabView({super.key, this.product, this.addProduct, this.editProduct, required this.fromHome});

  @override
  State<AddProductTabView> createState() => _AddProductTabViewState();
}

class _AddProductTabViewState extends State<AddProductTabView>  with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<AddProductScreenState> _firstTabKey = GlobalKey<AddProductScreenState>();
  final GlobalKey<AddProductNextScreenState> _secondTabKey = GlobalKey<AddProductNextScreenState>();

  ProductGeneralInfoData? productGeneralInfoData;
  ProductCombinedData? productCombinedData;




  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fetchDataFromFirstTab();
          _fetchDataFromSecondTab();
        });
      }
    });
  }


  void _fetchDataFromFirstTab() {
    ProductGeneralInfoData? latestData = _firstTabKey.currentState?.getCurrentFormData();
    setState(() {
      productGeneralInfoData = latestData;
    });

    debugPrint("---->>$productCombinedData");
    debugPrint("---->>${productCombinedData?.title}");
    debugPrint("---->>${productCombinedData?.description}");
  }

  void _fetchDataFromSecondTab() {
    ProductCombinedData? data = _secondTabKey.currentState?.getCurrentFormData();
    setState(() {
      productCombinedData = data;
    });
  }

  void _navigateToTab(int index) {
    if(index ==1 ) {
      _fetchDataFromFirstTab();
    }

    _tabController.animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);

    debugPrint("Current Locale: ${locale.languageCode}");

    final List<Tab> productTabs = [
      Tab(
        text: getTranslated('general_info', context),
      ),
      Tab(
        text: getTranslated('variations', context),
      ),
      Tab(
        text: getTranslated('seo', context),
      ),
    ];
    debugPrint("general_info => ${getTranslated('general_info', context)}");
    debugPrint("variations => ${getTranslated('variations', context)}");
    debugPrint("seo => ${getTranslated('seo', context)}");
    return DefaultTabController(
      length: productTabs.length,
      child: Scaffold(
        appBar: CustomAppBarWidget(
          centerTitle: false,
          title: widget.product != null ? getTranslated('update_product', context) : getTranslated('add_product', context),
          widget: const GeneratesLeftCount(),
          isFilter: true,
          isAction: true,
          onBackPressed: () {
            Navigator.of(context).pop();
          },
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault, vertical: Dimensions.paddingSizeSmall),
              height: 60,
              child: AddProductTitleBar(
                tabController: _tabController,
                tabs: productTabs,
              ),
            ),

            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: <Widget>[
                  AddProductScreen(product: widget.product, addProduct: widget.addProduct, fromHome: widget.fromHome, onTabChanged: _navigateToTab, key: _firstTabKey),

                  AddProductNextScreen(
                    key: _secondTabKey,
                    categoryId: productGeneralInfoData?.categoryId,
                    subCategoryId:  productGeneralInfoData?.subCategoryId,
                    subSubCategoryId: productGeneralInfoData?.subSubCategoryId,
                    brandId: productGeneralInfoData?.brandId,
                    unit: productGeneralInfoData?.unit,
                    product: widget.product,
                    addProduct: productGeneralInfoData?.addProduct,
                    title: productGeneralInfoData?.title,
                    description: productGeneralInfoData?.description,
                    onTabChanged: _navigateToTab,
                  ),

                  AddProductSeoScreen(
                    unitPrice: productCombinedData?.unitPrice,
                    tax: productCombinedData?.tax,
                    unit: productCombinedData?.unit,
                    categoryId: productCombinedData?.categoryId,
                    subCategoryId: productCombinedData?.subCategoryId,
                    subSubCategoryId: productCombinedData?.subSubCategoryId,
                    brandyId: productCombinedData?.brandId,
                    discount: productCombinedData?.discount,
                    currentStock: productCombinedData?.currentStock,
                    minimumOrderQuantity: productCombinedData?.minimumOrderQuantity,
                    shippingCost: productCombinedData?.shippingCost,
                    product: widget.product,
                    addProduct: productCombinedData?.addProduct,
                    title: productCombinedData?.title,
                    description: productCombinedData?.description,
                    onTabChanged: _navigateToTab,
                  ),
                ],
              ),
            )

          ],
        ),




      ),
    );
  }
}