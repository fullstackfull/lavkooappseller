import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/transaction/domain/models/month_model.dart';
import 'package:syriacosmeticsmanger/features/transaction/domain/models/transaction_model.dart';
import 'package:syriacosmeticsmanger/features/transaction/domain/models/year_model.dart';
import 'package:syriacosmeticsmanger/features/transaction/domain/services/transaction_service_interface.dart';
import 'package:syriacosmeticsmanger/helper/api_checker.dart';
import 'package:syriacosmeticsmanger/helper/date_converter.dart';

class TransactionController extends ChangeNotifier {
  final TransactionServiceInterface transactionServiceInterface;

  TransactionController({required this.transactionServiceInterface});

  List<TransactionModel>? _transactionList;
  late List<TransactionModel> _allTransactionList;
  List<TransactionModel>? get transactionList => _transactionList;



  List<MonthModel>  _monthItemList = [];
  List<MonthModel> get monthItemList => _monthItemList;
  List<YearModel>  _yearList = [];
  List<YearModel> get yearList => _yearList;
  int _yearIndex = 0;
  int _monthIndex = 0;
  int get yearIndex => _yearIndex;
  int get monthIndex => _monthIndex;
  List<int?> _yearIds = [];
  List<int?> _monthIds = [];
  List<int?> get yearIds  => _yearIds;
  List<int?> get monthIds  => _monthIds;


  int _transactionTypeIndex = 0;
  int get transactionTypeIndex => _transactionTypeIndex;

  void setIndex(BuildContext context, int index) {
    _transactionTypeIndex = index;
    applyDateRange(context, _fromDate, _toDate);
    notifyListeners();
  }

  void setYearIndex(int index, bool notify) {
    _yearIndex = index;
    if(notify) {
      notifyListeners();
    }
  }

  void setMonthIndex(int index, bool notify) {
    _monthIndex = index;
    if(notify) {
      notifyListeners();
    }
  }


  /// The date range currently applied, exposed so the screen can show it.
  DateTime? _fromDate;
  DateTime? _toDate;
  DateTime? get fromDate => _fromDate;
  DateTime? get toDate => _toDate;
  bool get hasDateFilter => _fromDate != null || _toDate != null;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> getTransactionList(BuildContext context, status, from, to) async {
    _transactionList = null;
    _isLoading = true;
    notifyListeners();

    ApiResponse apiResponse = await transactionServiceInterface.getTransactionList(status, from, to);
    if (apiResponse.response != null && apiResponse.response!.statusCode == 200) {
      final List<TransactionModel> parsed = <TransactionModel>[];
      // Each record used to be parsed twice, once into each list.
      apiResponse.response!.data.forEach((transaction) {
        parsed.add(TransactionModel.fromJson(transaction));
      });
      _allTransactionList = parsed;
      _transactionList = List<TransactionModel>.from(parsed);
    } else {
      ApiChecker.checkApi(apiResponse);
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Applies a date range and reloads. Passing nulls clears the filter.
  Future<void> applyDateRange(BuildContext context, DateTime? from, DateTime? to) async {
    _fromDate = from;
    _toDate = to;
    final String fromText = from != null ? DateFormat('yyyy-MM-dd').format(from) : '';
    final String toText = to != null ? DateFormat('yyyy-MM-dd').format(to) : '';
    await getTransactionList(context, _statusForIndex(_transactionTypeIndex), fromText, toText);
  }

  String _statusForIndex(int index) {
    switch (index) {
      case 1: return 'pending';
      case 2: return 'approve';
      case 3: return 'deny';
      default: return 'all';
    }
  }

  void  filterTransaction(int month, int year, BuildContext context) async {
    if (month == 1) {
      _transactionList = [];
      _transactionList!.addAll(_allTransactionList);
    } else {
      _transactionList = [];
      for (var transaction in _allTransactionList) {
        if(DateConverter.getMonthIndex(transaction.createdAt!) == month && DateConverter.getYear(transaction.createdAt!) == year) {
          _transactionList!.add(transaction);

        }
      }

    }
    notifyListeners();
  }


  void initMonthTypeList() async {
    _monthIds = [];
    _monthIds.add(0);
    ApiResponse apiResponse = await transactionServiceInterface.getMonthTypeList();
    if (apiResponse.response != null && apiResponse.response!.statusCode == 200) {

      _monthItemList = [];
      _monthItemList.addAll(apiResponse.response!.data);
      _monthIndex = 0;
      for(int index = 0; index < _monthItemList.length; index++) {
        _monthIds.add(_monthItemList[index].id);
      }
      notifyListeners();
    } else {
      if (kDebugMode) {
        print(apiResponse.error.toString());
      }
    }
  }
  void initYearList() async {
    _yearIds = [];
    _yearIds.add(0);
    ApiResponse apiResponse = await transactionServiceInterface.getYearList();
    if (apiResponse.response != null && apiResponse.response!.statusCode == 200) {
      _yearList = [];
      _yearList.addAll(apiResponse.response!.data);

      _yearIndex = 0;
      for(int index = 0; index < _yearList.length; index++) {
        _yearIds.add(_yearList[index].id);
      }
      notifyListeners();
    } else {
      if (kDebugMode) {
        print(apiResponse.error.toString());
      }
    }
  }


  final int _selectedItem = 0;
  int get selectedItem => _selectedItem;
  String _startDate = 'dd-mm-yyyy';
  String get startDate => _startDate;
  String _endDate = 'dd-mm-yyyy';
  String get endDate => _endDate;

  Future <void> selectDate(BuildContext context, String startDate, String endDate) async {
    _startDate = startDate;
    _endDate = endDate;
    getTransactionList(context, 'all', _startDate, _endDate);
    notifyListeners();
  }



}
