import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/exception/api_error_handler.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/customer_body.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/place_order_body.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/product_scan_refusal_model.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/temporary_cart_for_customer_model.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/repository/cart_repository_interface.dart';
import 'package:syriacosmeticsmanger/features/storefront/seller_market_choice.dart';
import 'package:syriacosmeticsmanger/features/storefront/storefront_config.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';


class CartRepository implements CartRepositoryInterface{
  final DioClient? dioClient;
  final SharedPreferences? sharedPreferences;
  final bool storefrontsEnabled;
  CartRepository({required this.dioClient, required this.sharedPreferences, this.storefrontsEnabled = StorefrontConfig.enabled});

  @override
  Future<ApiResponse> getCouponDiscount(String couponCode, int? userId, double orderAmount) async {
    try {
      final response = await dioClient!.post(AppConstants.getCouponDiscount,
      data: {
        'code' : couponCode,
        'user_id' : userId,
        'order_amount' : orderAmount
      });
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> placeOrder(PlaceOrderBody placeOrderBody) async {
    if (kDebugMode) {
      print('order place===>${placeOrderBody.toJson()}');
    }
    try {
      final response = await dioClient!.post(AppConstants.placeOrderUri, data: placeOrderBody.toJson());
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> placeOrderRaw(Map<String, dynamic> orderBody) async {
    try {
      final response = await dioClient!.post(AppConstants.placeOrderUri, data: orderBody);
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> getProductFromScan(String? productCode, {String? country}) async {
    try {
      final String? scanCountry = country ?? _marketCountryCode();
      final String countryQuery = scanCountry == null ? '' : '&country=$scanCountry';
      final response = await dioClient!.get('${AppConstants.getProductFromProductCode}?code=$productCode$countryQuery');
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ProductScanRefusal.fromException(e) ?? ApiErrorHandler.getMessage(e));
    }
  }

  /// The market the seller works in, or null while storefronts are off: a request then carries no country at all.
  String? _marketCountryCode() {
    final SharedPreferences? preferences = sharedPreferences;
    if (preferences == null) {
      return null;
    }
    return SellerMarketChoice(preferences, enabled: storefrontsEnabled).current().countryCode;
  }

  @override
  Future<ApiResponse> getCustomerList(String type) async {
    try {
      final response = await dioClient!.get('${AppConstants.customerSearchUri}?type=$type');
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> customerSearch(String name) async {
    try {
      final response = await dioClient!.get('${AppConstants.customerSearchUri}?name=$name&type=all');
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> addNewCustomer(CustomerBody customerBody) async {
    try {
      final response = await dioClient!.post(AppConstants.addNewCustomer,
          data: {
            'f_name' : customerBody.fName,
            'l_name' : customerBody.lName,
            'email' : customerBody.email,
            'phone' : customerBody.phone,
            'country' : customerBody.country,
            'city' : customerBody.city,
            'zip_code' : customerBody.zipCode,
            'address' : customerBody.address,
          });
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  // List<TemporaryCartListModel> getCartList() {
  // void addToCartList(List<TemporaryCartListModel> cartProductList) {

  @override
  void addToCartList(List<TemporaryCartListModel> cartProductList) {
    List<String> carts = [];
    for (var cartModel in cartProductList) {
      carts.add(jsonEncode(cartModel));
    }
    sharedPreferences?.setStringList(AppConstants.cartList, carts);
  }

  @override
  List<TemporaryCartListModel> getCartList() {
    List<String>? carts = [];
    if(sharedPreferences!.containsKey(AppConstants.cartList)) {
      carts = sharedPreferences?.getStringList(AppConstants.cartList);
    }
    List<TemporaryCartListModel> cartList = [];
    carts?.forEach((cart) => cartList.add(TemporaryCartListModel.fromJson(jsonDecode(cart))));
    return cartList;
  }


  @override
  Future<ApiResponse> getInvoiceData(int? orderId) async {
    try {
      final response = await dioClient!.get('${AppConstants.invoice}?id=$orderId');
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> getTaxAmount(PlaceOrderBody? placeOrderBody) async {
    try {
      final response = await dioClient!.post(
        AppConstants.getTaxAmount,
        data: placeOrderBody
      );
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }


  @override
  Future add(value) {
    // TODO: implement add
    throw UnimplementedError();
  }

  @override
  Future delete(int id) {
    // TODO: implement delete
    throw UnimplementedError();
  }

  @override
  Future get(String id) {
    // TODO: implement get
    throw UnimplementedError();
  }

  @override
  Future getList({int? offset = 1}) {
    // TODO: implement getList
    throw UnimplementedError();
  }

  @override
  Future update(Map<String, dynamic> body, int id) {
    // TODO: implement update
    throw UnimplementedError();
  }

  @override
  Future<void> setBluetoothAddress(String? address) async {
    await sharedPreferences?.setString(AppConstants.bluetoothMacAddress, address ?? '');
  }
  @override
  String? getBluetoothAddress() => sharedPreferences?.getString(AppConstants.bluetoothMacAddress);

}