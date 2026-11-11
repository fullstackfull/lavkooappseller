import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/error_response.dart';


class ApiErrorHandler {
  /// DioExceptionType.unknown wraps whatever the transport threw. A SocketException
  /// underneath means the device could not reach the server at all, which deserves
  /// the "no internet" message rather than a generic failure.
  static bool _isOfflineError(DioException error) {
    final Object? cause = error.error;
    if (cause is SocketException) return true;
    return cause.toString().contains('SocketException');
  }

  /// Safely reads a 'message' string out of a response body whose shape is not
  /// guaranteed (Laravel returns JSON maps, proxies and 500s often return HTML).
  static String? _messageFromBody(DioException error) {
    final dynamic data = error.response?.data;
    if (data is Map && data['message'] != null) {
      final String message = data['message'].toString();
      if (message.isNotEmpty) return message;
    }
    return null;
  }

  static dynamic getMessage(dynamic error) {
    dynamic errorDescription = "";
    if (error is Exception) {
      try {
        if (error is DioException) {
          switch (error.type) {
            case DioExceptionType.cancel:
              errorDescription = 'request_cancelled';
              break;
            case DioExceptionType.connectionTimeout:
              errorDescription = 'connection_timeout';
              break;
            case DioExceptionType.sendTimeout:
              errorDescription = 'connection_timeout';
              break;
            case DioExceptionType.receiveTimeout:
              errorDescription = 'connection_timeout';
              break;
            case DioExceptionType.badResponse:
              switch (error.response!.statusCode) {
              case 403:
                if (kDebugMode) {
                  print("===403===>>${error.response!.data}");
                }
                  if(error.response!.data.containsKey('key')){
                    errorDescription = error.response!.data['key'];
                  }else if(error.response!.data['errors'] != null){
                    ErrorResponse errorResponse = ErrorResponse.fromJson(error.response?.data);
                    errorDescription = errorResponse.errors?[0].message;
                  }else{
                    errorDescription = error.response!.data['message'];
                  }
                  break;
                case 401:

                  if (kDebugMode) {
                    print("==401==>>401");
                  }


                  if(error.response!.data.containsKey('loginStatus')) {
                    errorDescription = error.response!.data['loginStatus'];
                  } else if(error.response!.data['errors'] != null){
                    ErrorResponse errorResponse = ErrorResponse.fromJson(error.response?.data);
                    errorDescription = errorResponse.errors?[0].message;
                  } else{
                    errorDescription = error.response!.data['message'];
                  }

                  errorDescription ??= 'unauthorized';

                  if (kDebugMode) {
                    print("===ErrorDescription====>>$errorDescription");
                  }

                  break;
                case 405:
                  if (kDebugMode) {
                    print("==Responce=405=>>${error.response!.data}");
                  }
                  errorDescription = _messageFromBody(error) ?? 'something_went_wrong';
                  break;
                case 404:
                  if(error.response!.data['errors'] != null){
                    ErrorResponse errorResponse = ErrorResponse.fromJson(error.response?.data);
                    errorDescription = errorResponse.errors?[0].message;
                  }else{
                    errorDescription = error.response!.data['message'];
                  }
                  break;
                case 500:
                  if (kDebugMode) {
                    print("==Responce=500=>>${error.response!.data}");
                  }
                  errorDescription = _messageFromBody(error) ?? 'server_error';
                  break;
                case 503:
                  errorDescription = _messageFromBody(error) ?? 'service_unavailable';
                  break;
                case 429:
                  errorDescription = 'too_many_requests';
                  break;
                default:
                  ErrorResponse errorResponse = ErrorResponse.fromJson(error.response!.data);
                  if (errorResponse.errors != null && errorResponse.errors!.isNotEmpty) {
                    errorDescription = errorResponse;
                  } else {errorDescription = 'something_went_wrong';
                  }
              }
              break;
            case DioExceptionType.badCertificate:
              errorDescription = 'secure_connection_failed';
              break;
            case DioExceptionType.connectionError:
              errorDescription = 'no_internet_connection';
              break;
            case DioExceptionType.unknown:
              errorDescription = _isOfflineError(error) ? 'no_internet_connection' : 'something_went_wrong';
              break;
          }
        } else {
          errorDescription = 'something_went_wrong';
        }
      } on FormatException {
        errorDescription = 'something_went_wrong';
      }
    } else {
      errorDescription = 'something_went_wrong';
    }
    return errorDescription;
  }
}
