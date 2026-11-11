import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/features/transaction/domain/models/transaction_model.dart';
import 'package:syriacosmeticsmanger/helper/report_export_helper.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/transaction/widgets/transaction_shimmer_widget.dart';
import 'package:syriacosmeticsmanger/helper/color_helper.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/features/transaction/controllers/transaction_controller.dart';
import 'package:syriacosmeticsmanger/theme/controllers/theme_controller.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/no_data_screen.dart';
import 'package:syriacosmeticsmanger/features/transaction/widgets/transaction_widget.dart';
import 'package:syriacosmeticsmanger/core/animations/app_animations.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {


  void _loadData(BuildContext context){
    final TransactionController controller = Provider.of<TransactionController>(context, listen: false);
    controller.getTransactionList(context, 'all','','');
    controller.initMonthTypeList();
    controller.initYearList();
  }

  Future<void> _pickDateRange(BuildContext context, TransactionController controller) async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: controller.fromDate != null && controller.toDate != null
          ? DateTimeRange(start: controller.fromDate!, end: controller.toDate!)
          : null,
      helpText: getTranslated('select_date_range', context),
    );
    if (picked != null && context.mounted) {
      await controller.applyDateRange(context, picked.start, picked.end);
    }
  }

  Future<void> _export(BuildContext context, TransactionController controller) async {
    final List<TransactionModel> list = controller.transactionList ?? <TransactionModel>[];
    if (list.isEmpty) return;

    await ReportExportHelper.shareCsv(
      context: context,
      fileNamePrefix: 'transactions',
      headers: <String>[
        getTranslated('id', context) ?? 'ID',
        getTranslated('date', context) ?? 'Date',
        getTranslated('amount', context) ?? 'Amount',
        getTranslated('status', context) ?? 'Status',
        getTranslated('note', context) ?? 'Note',
      ],
      rows: list.map((TransactionModel t) => <Object?>[
        t.id,
        t.createdAt,
        t.amount,
        t.approved == 1 ? 'approved' : t.approved == 2 ? 'denied' : 'pending',
        t.transactionNote,
      ]).toList(),
    );
  }

  double filterHeight = 45;


  TextEditingController searchController = TextEditingController();


  @override
  void initState() {
    super.initState();
    _loadData(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, result) async {},
      child: Scaffold(
        appBar: CustomAppBarWidget(title: getTranslated('transactions', context), isAction: true),
        body: Consumer<TransactionController>(
          builder: (context, transactionProvider, child) {

            return Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Dimensions.paddingSize, Dimensions.paddingSizeSmall, Dimensions.paddingSize, 0),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDateRange(context, transactionProvider),
                        icon: const Icon(Icons.date_range_rounded, size: Dimensions.iconSizeDefault),
                        label: Text(
                          transactionProvider.hasDateFilter
                              ? '${DateFormat('yyyy/MM/dd').format(transactionProvider.fromDate!)} - ${DateFormat('yyyy/MM/dd').format(transactionProvider.toDate!)}'
                              : getTranslated('select_date_range', context) ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall),
                        ),
                      ),
                    ),
                    if (transactionProvider.hasDateFilter)
                      IconButton(
                        tooltip: getTranslated('clear_filter', context),
                        onPressed: () => transactionProvider.applyDateRange(context, null, null),
                        icon: const Icon(Icons.filter_alt_off_rounded, size: Dimensions.iconSizeMedium),
                      ),
                    IconButton(
                      tooltip: getTranslated('export_csv', context),
                      onPressed: (transactionProvider.transactionList?.isEmpty ?? true)
                          ? null
                          : () => _export(context, transactionProvider),
                      icon: const Icon(Icons.ios_share_rounded, size: Dimensions.iconSizeMedium),
                    ),
                  ]),
                ),
                SizedBox(height: 65,
                  child: ListView(
                    shrinkWrap: true,
                    scrollDirection: Axis.horizontal,
                    children: const [
                      TransactionTypeButton(text: 'all', index: 0),
                      TransactionTypeButton(text: 'pending', index: 1),
                      TransactionTypeButton(text: 'approved', index: 2),
                      TransactionTypeButton(text: 'denied', index: 3),
                    ],
                  )),

                Expanded(child: transactionProvider.transactionList != null ? transactionProvider.transactionList!.isNotEmpty ?

                 ListView.builder(
                     itemCount: transactionProvider.transactionList!.length,
                    itemBuilder: (context, index) => TransactionWidget(transactionModel: transactionProvider.transactionList![index]).animateListEntrance(index),
                 ) : const NoDataScreen() : const TransactionShimmerWidget(),
                ),
              ],
            );
          }
        ),
      ),
    );
  }
}

class TransactionTypeButton extends StatelessWidget {
  final String text;
  final int index;
  const TransactionTypeButton({super.key, required this.text, required this.index,});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeExtraSmall, vertical: Dimensions.paddingSizeMedium),
        child: InkWell(
          onTap: (){
            Provider.of<TransactionController>(context, listen: false).setIndex(context, index);
          },
          child: Consumer<TransactionController>(builder: (context, transactionProvider, child) {
            return Container(
              height: 45,
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeLarge,),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: transactionProvider.transactionTypeIndex == index ? Theme.of(context).primaryColor : Provider.of<ThemeController>(context).darkTheme ?
                ColorHelper.blendColors(Colors.white, Theme.of(context).highlightColor, 0.9) :
                Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(Dimensions.paddingSizeLarge),
              ),
              child: Text(getTranslated(text, context)!, style: transactionProvider.transactionTypeIndex == index
                  ? titilliumBold.copyWith(color: transactionProvider.transactionTypeIndex == index
                  ? Theme.of(context).colorScheme.secondaryContainer : Theme.of(context).textTheme.bodyLarge?.color):
              robotoRegular.copyWith(color: transactionProvider.transactionTypeIndex == index
                  ? Theme.of(context).colorScheme.secondaryContainer : Theme.of(context).textTheme.bodyLarge?.color)),
            );
          },
          ),
        ),
      ),
    );
  }
}