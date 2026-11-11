import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_button_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_search_field_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/no_data_screen.dart';
import 'package:syriacosmeticsmanger/features/bulk_jobs/controllers/bulk_job_controller.dart';
import 'package:syriacosmeticsmanger/features/bulk_jobs/domain/models/bulk_job_models.dart';
import 'package:syriacosmeticsmanger/features/bulk_jobs/screens/bulk_job_receipt_screen.dart';
import 'package:syriacosmeticsmanger/features/bulk_jobs/widgets/bulk_job_widgets.dart';
import 'package:syriacosmeticsmanger/features/product/domain/models/product_model.dart';
import 'package:syriacosmeticsmanger/features/profile/controllers/profile_controller.dart';
import 'package:syriacosmeticsmanger/helper/debounce_helper.dart';
import 'package:syriacosmeticsmanger/localization/controllers/localization_controller.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/images.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// Choose the products, then choose what to do to them.
///
/// Selection comes first because it is the part a seller thinks about: which
/// products, found by searching, across as many pages as it takes. The change
/// itself is a short form at the end, and it names the number of products it is
/// about to touch — a bulk edit that does not say how much it is about to change
/// is the one people get wrong.
class BulkEditScreen extends StatefulWidget {
  const BulkEditScreen({super.key});

  @override
  State<BulkEditScreen> createState() => _BulkEditScreenState();
}

class _BulkEditScreenState extends State<BulkEditScreen> {
  final DebounceHelper _debounce = DebounceHelper(milliseconds: 500);
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreAtTheBottom);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _debounce.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _load({String? search, bool reload = true}) {
    final BulkJobController bulk = Provider.of<BulkJobController>(context, listen: false);
    bulk.getProducts(
      sellerId: '${Provider.of<ProfileController>(context, listen: false).userId}',
      languageCode: LocalizationController.apiLanguageCode(context),
      search: search,
      reload: reload,
    );
  }

  void _loadMoreAtTheBottom() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _load(reload: false);
    }
  }

  Future<void> _openOperationSheet(String type) async {
    final BulkJobModel? job = await showModalBottomSheet<BulkJobModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BulkOperationSheet(type: type),
    );

    if (job == null || !mounted) return;

    // Straight to the receipt. The result of a bulk change is not a snackbar —
    // it is a list of what did and did not happen.
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => BulkJobReceiptScreen(jobId: job.id, initialJob: job),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BulkJobController>(
      builder: (context, bulk, _) {
        final List<Product> products = bulk.products;

        return Scaffold(
          appBar: CustomAppBarWidget(
            title: bulk.selectedCount > 0
                ? '${bulk.selectedCount} ${getTranslated('bulk_selected', context) ?? ''}'
                : getTranslated('bulk_choose_products', context),
            isAction: bulk.selectedCount > 0,
            isTooltip: true,
            widget: bulk.selectedCount > 0
                ? IconButton(
                    onPressed: bulk.clearSelection,
                    tooltip: getTranslated('clear', context),
                    icon: const Icon(Icons.close),
                  )
                : null,
          ),
          body: Column(children: [
            Container(
              color: Theme.of(context).cardColor,
              padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeDefault, vertical: Dimensions.paddingSizeSmall),
              child: CustomSearchFieldWidget(
                controller: _searchController,
                hint: getTranslated('search_by_product_name', context),
                prefix: Images.iconsSearch,
                iconPressed: () {},
                onSubmit: (_) {},
                onChanged: (value) => _debounce.run(() => _load(search: value)),
              ),
            ),

            if (products.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall),
                child: Row(children: [
                  TextButton(
                    onPressed: bulk.selectLoaded,
                    // "Select all" on a paged list can only honestly mean the rows
                    // that are loaded, so it says so.
                    child: Text('${getTranslated('bulk_select_loaded', context) ?? ''} (${products.length})'),
                  ),
                  const Spacer(),
                  Text('${products.length}/${bulk.totalSize}',
                      style: robotoRegular.copyWith(
                          fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                ]),
              ),

            Expanded(
              child: products.isEmpty && !bulk.isLoadingProducts
                  ? const Center(child: NoDataScreen())
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: products.length + (bulk.isLoadingProducts ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= products.length) {
                          return Padding(
                            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                            child: Center(child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor))),
                          );
                        }

                        final Product product = products[index];
                        return BulkProductTileWidget(
                          product: product,
                          isSelected: bulk.isSelected(product.id),
                          onTap: () => bulk.toggle(product),
                        );
                      },
                    ),
            ),
          ]),
          bottomNavigationBar: bulk.selectedCount == 0
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                    child: Row(children: [
                      Expanded(
                        child: CustomButtonWidget(
                          btnTxt: getTranslated('bulk_change_price', context),
                          onTap: () => _openOperationSheet('price_update'),
                        ),
                      ),
                      const SizedBox(width: Dimensions.paddingSizeSmall),
                      Expanded(
                        child: CustomButtonWidget(
                          btnTxt: getTranslated('bulk_change_stock', context),
                          backgroundColor: Theme.of(context).cardColor,
                          fontColor: Theme.of(context).primaryColor,
                          borderColor: Theme.of(context).primaryColor,
                          onTap: () => _openOperationSheet('stock_update'),
                        ),
                      ),
                    ]),
                  ),
                ),
        );
      },
    );
  }
}

/// The change itself: a mode and a number.
///
/// Modes are offered rather than assumed because a seller running a seasonal
/// adjustment thinks in percent and a seller correcting a supplier change thinks
/// in money. Offering only one of the two turns the other into a spreadsheet
/// exercise, which is what a bulk tool exists to remove.
class _BulkOperationSheet extends StatefulWidget {
  final String type;
  const _BulkOperationSheet({required this.type});

  @override
  State<_BulkOperationSheet> createState() => _BulkOperationSheetState();
}

class _BulkOperationSheetState extends State<_BulkOperationSheet> {
  static const List<String> _priceModes = ['set', 'increase_percent', 'decrease_percent', 'increase_amount', 'decrease_amount'];
  static const List<String> _stockModes = ['set', 'increase', 'decrease'];

  final TextEditingController _valueController = TextEditingController();
  late String _mode = widget.type == 'price_update' ? _priceModes.first : _stockModes.first;

  bool get _isPrice => widget.type == 'price_update';

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _submit(BulkJobController bulk) async {
    final num? value = num.tryParse(_valueController.text.trim());
    if (value == null || value < 0) return;

    final BulkJobModel? job = _isPrice
        ? await bulk.submitPriceUpdate(mode: _mode, value: value)
        : await bulk.submitStockUpdate(mode: _mode, value: value.toInt());

    if (!mounted) return;
    Navigator.of(context).pop(job);
  }

  @override
  Widget build(BuildContext context) {
    final BulkJobController bulk = Provider.of<BulkJobController>(context);
    final List<String> modes = _isPrice ? _priceModes : _stockModes;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Dimensions.radiusLarge)),
        ),
        padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(getTranslated(_isPrice ? 'bulk_change_price' : 'bulk_change_stock', context) ?? '',
              style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge)),
          const SizedBox(height: 2),
          // Named before the change is made, not after: this is the number people
          // get wrong.
          Text('${bulk.selectedCount} ${getTranslated('bulk_products_will_change', context) ?? ''}',
              style: robotoRegular.copyWith(
                  fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
          const SizedBox(height: Dimensions.paddingSizeDefault),

          Wrap(spacing: Dimensions.paddingSizeExtraSmall, children: modes.map((mode) => ChoiceChip(
                label: Text(getTranslated('bulk_mode_$mode', context) ?? mode),
                selected: _mode == mode,
                onSelected: (_) => setState(() => _mode = mode),
              )).toList()),
          const SizedBox(height: Dimensions.paddingSizeDefault),

          TextField(
            controller: _valueController,
            keyboardType: TextInputType.numberWithOptions(decimal: _isPrice),
            inputFormatters: [
              FilteringTextInputFormatter.allow(_isPrice ? RegExp(r'^\d*\.?\d{0,2}') : RegExp(r'^\d*')),
            ],
            decoration: InputDecoration(
              labelText: getTranslated('value', context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeLarge),

          CustomButtonWidget(
            btnTxt: getTranslated('apply', context),
            isLoading: bulk.isSubmitting,
            onTap: bulk.isSubmitting ? null : () => _submit(bulk),
          ),
        ]),
      ),
    );
  }
}
