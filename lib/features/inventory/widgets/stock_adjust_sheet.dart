import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_button_widget.dart';
import 'package:syriacosmeticsmanger/features/inventory/controllers/inventory_controller.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// Correcting a stock level, with the reason it changed.
///
/// The reason is not optional here because it is not optional in the ledger: a
/// history of unexplained corrections is barely more useful than no history. The
/// direction is chosen explicitly rather than typed as a minus sign, which is
/// the kind of thing people get wrong at speed and only notice a week later.
class StockAdjustSheet extends StatefulWidget {
  final int productId;
  final String? productName;
  final int currentStock;

  const StockAdjustSheet({
    super.key,
    required this.productId,
    required this.currentStock,
    this.productName,
  });

  @override
  State<StockAdjustSheet> createState() => _StockAdjustSheetState();
}

class _StockAdjustSheetState extends State<StockAdjustSheet> {
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool _isAdding = true;
  String? _reason;
  String? _refusal;

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int get _quantity => int.tryParse(_quantityController.text.trim()) ?? 0;

  /// What the level will read once this lands, shown before it does. The number
  /// people check is the result, not the change.
  int get _resulting => widget.currentStock + (_isAdding ? _quantity : -_quantity);

  Future<void> _submit(InventoryController inventory) async {
    if (_quantity <= 0 || _reason == null) return;

    final String? refusal = await inventory.adjust(
      productId: widget.productId,
      delta: _isAdding ? _quantity : -_quantity,
      reason: _reason!,
      note: _noteController.text.trim(),
    );

    if (!mounted) return;

    if (refusal == null) {
      Navigator.of(context).pop(true);
      return;
    }

    // Shown in place rather than as a snackbar over a closed sheet: the seller
    // still has the numbers in front of them and can correct the entry.
    setState(() => _refusal = refusal);
  }

  @override
  Widget build(BuildContext context) {
    final InventoryController inventory = Provider.of<InventoryController>(context);
    final List<String> reasons = inventory.reasons;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Dimensions.radiusLarge)),
        ),
        padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(getTranslated('correct_stock', context) ?? '',
              style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge)),
          if (widget.productName != null) ...[
            const SizedBox(height: 2),
            Text(widget.productName!,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: robotoRegular.copyWith(
                    fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
          ],
          const SizedBox(height: Dimensions.paddingSizeDefault),

          Row(children: [
            Expanded(
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment<bool>(value: true, label: Text(getTranslated('add', context) ?? '')),
                  ButtonSegment<bool>(value: false, label: Text(getTranslated('remove', context) ?? '')),
                ],
                selected: {_isAdding},
                onSelectionChanged: (selection) => setState(() => _isAdding = selection.first),
              ),
            ),
          ]),
          const SizedBox(height: Dimensions.paddingSizeDefault),

          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() => _refusal = null),
            decoration: InputDecoration(
              labelText: getTranslated('quantity', context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),

          Row(children: [
            Text('${getTranslated('current_stock', context) ?? ''}: ${widget.currentStock}',
                style: robotoRegular.copyWith(
                    fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
            const Spacer(),
            if (_quantity > 0)
              Text('${getTranslated('will_become', context) ?? ''} $_resulting',
                  style: robotoMedium.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall,
                      color: _resulting < 0
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).primaryColor)),
          ]),
          const SizedBox(height: Dimensions.paddingSizeDefault),

          Wrap(spacing: Dimensions.paddingSizeExtraSmall, children: reasons.map((reason) => ChoiceChip(
                label: Text(getTranslated('reason_$reason', context) ?? reason),
                selected: _reason == reason,
                onSelected: (_) => setState(() => _reason = reason),
              )).toList()),
          const SizedBox(height: Dimensions.paddingSizeDefault),

          TextField(
            controller: _noteController,
            maxLength: 255,
            decoration: InputDecoration(
              labelText: getTranslated('note_optional', context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
            ),
          ),

          if (_refusal != null) ...[
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Text(_refusal!,
                style: robotoRegular.copyWith(
                    fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: Dimensions.paddingSizeDefault),

          CustomButtonWidget(
            btnTxt: getTranslated('apply', context),
            isLoading: inventory.isAdjusting,
            // A reason is required, so the button says so by staying inert until
            // one is chosen.
            onTap: (_quantity <= 0 || _reason == null || inventory.isAdjusting) ? null : () => _submit(inventory),
          ),
        ]),
      ),
    );
  }
}
