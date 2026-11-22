import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The scan change is additive: the parts of the scan that must stay as they were are pinned here, in the source, so that
/// a later edit that touches them has to say so.
const String _controllerPath = 'lib/features/pos/controllers/barcode_scan_controller.dart';
const String _repositoryPath = 'lib/features/pos/domain/repository/cart_repository.dart';

const List<String> _newFiles = <String>[
  'lib/features/pos/domain/models/product_scan_refusal_model.dart',
  'lib/features/pos/widgets/ambiguous_code_sheet_widget.dart',
];

/// The branch of the scan that handles a product, as it was before the scan learnt to refuse: text, spacing aside.
const String _productBranchAsItWas = '''
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
}''';

String _squeezed(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

String _read(String path) => File(path).readAsStringSync();

/// The source of the files that can send a request to the app's own server, without the tests.
Iterable<File> _libraryFiles() =>
    Directory('lib').listSync(recursive: true).whereType<File>().where((File file) => file.path.endsWith('.dart'));

void main() {
  test('a scan that finds a product still handles it with the code it always had', () {
    final String controller = _read(_controllerPath);
    final int start = controller.indexOf('if(response.response?.statusCode == 200) {');
    final int end = controller.indexOf('}else if(response.error is AmbiguousScanCodeError)');

    expect(start, isNonNegative);
    expect(end, greaterThan(start));
    expect(_squeezed(controller.substring(start, end + 1)), _squeezed(_productBranchAsItWas));
  });

  test('a failure that is not a refusal still goes to the app error handler', () {
    final String controller = _squeezed(_read(_controllerPath));

    expect(controller, contains('}else { ApiChecker.checkApi( response); } _isLoading = false; notifyListeners(); }'));
  });

  test('no new place dereferences the navigator context: the seven it had are the seven it has', () {
    expect('Get.context!'.allMatches(_read(_controllerPath)).length, 7);
  });

  test('only the cart repository asks the server for the scan', () {
    final List<String> askers = _libraryFiles()
        .where((File file) => _read(file.path).contains('getProductFromProductCode'))
        .map((File file) => file.path)
        .toList()
      ..sort();

    expect(askers, <String>[_repositoryPath, 'lib/utill/app_constants.dart']);
  });

  test('the request is the code, plus a country only when the repository was given or found one', () {
    final String repository = _squeezed(_read(_repositoryPath));

    expect(repository, contains(r"final String? scanCountry = country ?? _marketCountryCode();"));
    expect(repository, contains(r"final String countryQuery = scanCountry == null ? '' : '&country=$scanCountry';"));
    expect(repository, contains(r"'${AppConstants.getProductFromProductCode}?code=$productCode$countryQuery'"));
    expect(repository, contains('SellerMarketChoice(preferences, enabled: storefrontsEnabled).current().countryCode'));
  });

  test('the repository follows the storefront flag unless it is told otherwise, and the flag ships off', () {
    final String repository = _squeezed(_read(_repositoryPath));

    expect(repository, contains('this.storefrontsEnabled = StorefrontConfig.enabled'));
    expect(_read('lib/features/storefront/storefront_config.dart'),
        contains("bool.fromEnvironment('GCC_STOREFRONTS_ENABLED', defaultValue: false)"));
  });

  test('nothing in the new code prints, logs or reaches the network on its own', () {
    for (final String path in _newFiles) {
      final String source = _read(path);

      expect(source, isNot(contains('print(')), reason: path);
      expect(source, isNot(contains('debugPrint(')), reason: path);
      expect(source, isNot(contains('dioClient')), reason: path);
      expect(source, isNot(contains('http')), reason: path);
    }
  });
}
