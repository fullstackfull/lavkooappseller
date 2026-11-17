import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

class PlatformChipOption<T> {
  final T value;
  final String label;

  const PlatformChipOption({required this.value, required this.label});
}

/// A row of pills of which one is chosen, with the look of the period chips of the
/// reports. They wrap onto more lines instead of scrolling, so that at a large text
/// size no choice is hidden off the edge of the screen.
class PlatformChipRow<T> extends StatelessWidget {
  final List<PlatformChipOption<T>> options;
  final T? selected;
  final ValueChanged<T> onSelected;

  const PlatformChipRow({super.key, required this.options, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Dimensions.paddingSizeExtraSmall,
      runSpacing: Dimensions.paddingSizeExtraSmall,
      children: options.map((PlatformChipOption<T> option) => _chip(context, option)).toList(),
    );
  }

  Widget _chip(BuildContext context, PlatformChipOption<T> option) {
    final bool isSelected = option.value == selected;

    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: () => onSelected(option.value),
        borderRadius: BorderRadius.circular(Dimensions.radiusPill),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault, vertical: Dimensions.paddingSizeExtraSmall),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).hintColor.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(Dimensions.radiusPill),
          ),
          child: Text(
            option.label,
            style: (isSelected ? robotoBold : robotoRegular).copyWith(
              fontSize: Dimensions.fontSizeSmall,
              color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ),
      ),
    );
  }
}
