import 'package:barcode_scan2/gen/protos/protos.pbenum.dart';
import 'package:barcode_scan2/model/android_options.dart';
import 'package:barcode_scan2/model/scan_options.dart';
import 'package:barcode_scan2/platform_wrapper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_snackbar_widget.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/cart_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/cart_model.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/product_scan_refusal_model.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/services/cart_service_interface.dart';
import 'package:syriacosmeticsmanger/features/pos/widgets/ambiguous_code_sheet_widget.dart';
import 'package:syriacosmeticsmanger/features/pos/widgets/product_variation_selection_dialog_widget.dart';
import 'package:syriacosmeticsmanger/features/product/controllers/product_controller.dart';
import 'package:syriacosmeticsmanger/features/product/domain/models/product_model.dart';
import 'package:syriacosmeticsmanger/features/product/screens/product_list_screen.dart';
import 'package:syriacosmeticsmanger/helper/api_checker.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';



Widget _productListPage(BuildContext context) => const ProductListMenuScreen();

class BarcodeScanController extends ChangeNotifier{
  final CartServiceInterface cartServiceInterface;
  final WidgetBuilder productListPage;
  BarcodeScanController({required this.cartServiceInterface, this.productListPage = _productListPage});


  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Product? _scanProduct ;
  Product? get scanProduct=>_scanProduct;



  Future<void> scanProductBarCode(BuildContext context) async{
    String? scannedProductBarCode;
    try{
      final result = await BarcodeScanner.scan(
        options: const ScanOptions(
          strings: {
            'cancel': 'cancel',
            'flash_on': 'flash on',
            'flash_off': 'flash off',
          },
          restrictFormat: [BarcodeFormat.code128],
          useCamera: -1,
          autoEnableFlash: false,
          android: AndroidOptions(
            aspectTolerance: 0.00,
            useAutoFocus: true,
          ),
        ),
      );
      scannedProductBarCode = result.rawContent;
    }
    on PlatformException{
      if (kDebugMode) {
        print('object');
      }
    }
    getProductFromScan(Get.context!, scannedProductBarCode);
  }


  Future<void> getProductFromScan(BuildContext context, String? productCode, {String? country}) async {
    _isLoading = true;
    ApiResponse response = await cartServiceInterface.getProductFromScan(productCode, country: country);

    if(response.response?.statusCode == 200) {
      _scanProduct = Product.fromJson(response.response!.data);
      Provider.of<ProductController>(Get.context!, listen: false).initData(_scanProduct!,1, Get.context!);
      if(scanProduct!.variation!.isNotEmpty || scanProduct!.digitalProductFileTypes!.isNotEmpty){
        showModalBottomSheet(context: Get.context!, isScrollControlled: true,
            backgroundColor: Theme.of(Get.context!).primaryColor.withValues(alpha:0),
            builder: (con) => CartBottomSheetWidget(product: _scanProduct, callback: () {
              showCustomSnackBarWidget(getTranslated('added_to_cart', context), context, isError: false);},));

      } else{
        CartModel cartModel = CartModel(_scanProduct!.unitPrice, _scanProduct!.discount, 1, _scanProduct!.tax, null,null,null,null, _scanProduct, _scanProduct!.taxModel);
        Provider.of<CartController>(Get.context!, listen: false).addToCart(Get.context!, cartModel);
      }

      _isLoading = false;
    }else if(response.error is AmbiguousScanCodeError) {
      _askWhichProduct(productCode, response.error as AmbiguousScanCodeError, countryWasChosen: country != null);
    }else if(response.error is ScanCountryRefusedError) {
      _explainRefusedCountry(response.error as ScanCountryRefusedError);
    }else {
      ApiChecker.checkApi( response);
    }
    _isLoading = false;
    notifyListeners();
  }

  /// No product is picked for the seller: the sheet lists the candidates and the seller decides.
  void _askWhichProduct(String? productCode, AmbiguousScanCodeError ambiguity, {required bool countryWasChosen}) {
    final BuildContext? navigatorContext = Get.context;
    if(navigatorContext == null) {
      return;
    }

    showAmbiguousCodeSheet(
      context: navigatorContext,
      candidates: ambiguity.candidates,
      canChooseCountry: ambiguity.spansCountries && !countryWasChosen,
      onCountryChosen: (String countryCode) => getProductFromScan(navigatorContext, productCode, country: countryCode),
      onOpenProductList: () => Navigator.of(navigatorContext).push(MaterialPageRoute(builder: productListPage)),
    );
  }

  /// Asking again would change nothing, so the seller is told and the scan ends.
  void _explainRefusedCountry(ScanCountryRefusedError refusal) {
    final BuildContext? navigatorContext = Get.context;
    if(navigatorContext == null) {
      return;
    }

    showCustomSnackBarWidget(
      refusal.serverMessage ?? getTranslated('scan_market_unavailable', navigatorContext),
      navigatorContext,
      sanckBarType: SnackBarType.error,
    );
  }

}