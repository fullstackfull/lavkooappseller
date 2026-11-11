import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/features/transaction/controllers/transaction_controller.dart';
import 'package:syriacosmeticsmanger/features/transaction/widgets/transaction_widget.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/core/animations/app_animations.dart';

class WalletTransactionListViewWidget extends StatelessWidget {
  final TransactionController? transactionProvider;
  final int? limit;
  const WalletTransactionListViewWidget({super.key, this.transactionProvider, this.limit});

  @override
  Widget build(BuildContext context) {
    final items = transactionProvider!.transactionList!;
    final count = limit != null ? items.length.clamp(0, limit!) : items.length;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (context, index) => TransactionWidget(transactionModel: transactionProvider!.transactionList![index]).animateListEntrance(index),
      separatorBuilder: (BuildContext context, int index) => const SizedBox(height: Dimensions.paddingSizeExtraSmall),
    );
  }
}
