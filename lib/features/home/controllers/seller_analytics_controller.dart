import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/home/domain/services/seller_analytics_service_interface.dart';
import 'package:syriacosmeticsmanger/features/order/domain/models/business_analytics_filter_data.dart';
import 'package:syriacosmeticsmanger/helper/api_checker.dart';

/// Home-dashboard analytics: order statistics and the earning-statistics chart.
///
/// This state used to live in [BankInfoController] for historical reasons; it
/// has nothing to do with bank information, so it now has its own controller.
class SellerAnalyticsController extends ChangeNotifier {
  final SellerAnalyticsServiceInterface sellerAnalyticsServiceInterface;
  SellerAnalyticsController({required this.sellerAnalyticsServiceInterface});

  BusinessAnalyticsFilterDataModel? _businessAnalyticsFilterData;
  BusinessAnalyticsFilterDataModel? get businessAnalyticsFilterData => _businessAnalyticsFilterData;

  int _analyticsIndex = 0;
  int get analyticsIndex => _analyticsIndex;

  int _revenueFilterTypeIndex = 0;
  int get revenueFilterTypeIndex => _revenueFilterTypeIndex;

  List<double?>? _userEarnings;
  List<double?>? get userEarnings => _userEarnings;

  List<double?>? _userCommissions;
  List<double?>? get userCommissions => _userCommissions;

  double _lim = 0.0;
  double get lim => _lim;

  bool _isEarningStatisticsLoading = false;
  bool get isEarningStatisticsLoading => _isEarningStatisticsLoading;

  void setAnalyticsFilterName(String? filterName, {bool notify = true}) {
    getAnalyticsFilterData(filterName);
    if (notify) {
      notifyListeners();
    }
  }

  void setAnalyticsFilterType(int index, {bool notify = true}) {
    _analyticsIndex = index;
    if (notify) {
      _businessAnalyticsFilterData = null;
      notifyListeners();
    }
  }

  Future<void> getAnalyticsFilterData(String? type) async {
    ApiResponse response = await sellerAnalyticsServiceInterface.getOrderStatistics(type);
    if (response.response != null && response.response!.statusCode == 200) {
      _businessAnalyticsFilterData = BusinessAnalyticsFilterDataModel.fromJson(response.response!.data);
    } else {
      ApiChecker.checkApi(response);
    }
    notifyListeners();
  }

  void setRevenueFilterName(String? filterName, {bool notify = true}) {
    String? callingString;
    if (filterName == 'this_year') {
      callingString = 'yearEarn';
    } else if (filterName == 'this_month') {
      callingString = 'MonthEarn';
    } else if (filterName == 'this_week') {
      callingString = 'WeekEarn';
    }
    getDashboardRevenueData(callingString);
    if (notify) {
      notifyListeners();
    }
  }

  void setRevenueFilterType(int index, {bool notify = true}) {
    _revenueFilterTypeIndex = index;
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> getDashboardRevenueData(String? filterType) async {
    _isEarningStatisticsLoading = true;
    ApiResponse apiResponse = await sellerAnalyticsServiceInterface.getEarningStatistics(filterType);
    _isEarningStatisticsLoading = false;
    if (apiResponse.response != null && apiResponse.response!.data != null && apiResponse.response!.statusCode == 200) {
      _userEarnings = _parseAmounts(apiResponse.response!.data['seller_earn']);
      _userCommissions = _parseAmounts(apiResponse.response!.data['commission_earn']);
      _lim = _maxAmount(_userEarnings!, _userCommissions!);
    } else {
      ApiChecker.checkApi(apiResponse);
    }
    notifyListeners();
  }

  /// The API mixes ints and numeric strings in one array; a leading 0 keeps
  /// the chart's first point on the axis, matching the legacy behaviour.
  List<double?> _parseAmounts(dynamic amounts) {
    final List<double?> parsed = [0];
    for (dynamic amount in amounts) {
      parsed.add(double.tryParse(amount.toString()) ?? 0);
    }
    return parsed;
  }

  double _maxAmount(List<double?> earnings, List<double?> commissions) {
    double max = 0;
    for (double? value in [...earnings, ...commissions]) {
      if (value != null && value > max) {
        max = value;
      }
    }
    return max;
  }
}
