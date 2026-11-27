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

  /// The sentence an answer that is NOT a JSON object carries, or null when it
  /// carries none.
  ///
  /// Several seller v3 endpoints answer `response()->json('some sentence')`,
  /// which is a bare JSON string and not an object -- a refused close of a
  /// withdraw request is one ("Withdraw request is invalid", 403), and its own
  /// success answer is another. A page is deliberately not a sentence: an HTML
  /// error page from a proxy is not something to show a seller.
  static String? _textOfANonObjectBody(dynamic body) {
    if (body is! String) {
      return null;
    }

    final String text = body.trim();

    return text.isEmpty || text.startsWith('<') ? null : text;
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
                  // A refusal is not always a JSON object. `close-withdraw-request`
                  // answers a bare JSON string, and `containsKey` on a String is a
                  // NoSuchMethodError -- which the `on FormatException` below does
                  // not hold, and which is raised from inside the calling
                  // repository's own catch block, so it escaped the repository: the
                  // seller tapped "close request", the server refused, and the app
                  // threw with nothing shown and the button left spinning (K-V1).
                  //
                  // An object is read exactly as it always was, key before errors
                  // before message, so no answer that used to work reads
                  // differently now.
                  if (error.response!.data is Map) {
                    if (error.response!.data.containsKey('key')) {
                      errorDescription = error.response!.data['key'];
                    } else if (error.response!.data['errors'] != null) {
                      ErrorResponse errorResponse =
                          ErrorResponse.fromJson(error.response?.data);
                      errorDescription = errorResponse.errors?[0].message;
                    } else {
                      errorDescription = error.response!.data['message'];
                    }
                  } else {
                    errorDescription =
                        _textOfANonObjectBody(error.response!.data) ??
                            'something_went_wrong';
                  }
                  break;
                case 401:
                  if (kDebugMode) {
                    print("==401==>>401");
                  }

                  if (error.response!.data.containsKey('loginStatus')) {
                    errorDescription = error.response!.data['loginStatus'];
                  } else if (error.response!.data['errors'] != null) {
                    ErrorResponse errorResponse =
                        ErrorResponse.fromJson(error.response?.data);
                    errorDescription = errorResponse.errors?[0].message;
                  } else {
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
                  errorDescription =
                      _messageFromBody(error) ?? 'something_went_wrong';
                  break;
                case 404:
                  if (error.response!.data['errors'] != null) {
                    ErrorResponse errorResponse =
                        ErrorResponse.fromJson(error.response?.data);
                    errorDescription = errorResponse.errors?[0].message;
                  } else {
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
                  errorDescription =
                      _messageFromBody(error) ?? 'service_unavailable';
                  break;
                case 429:
                  errorDescription = 'too_many_requests';
                  break;
                default:
                  ErrorResponse errorResponse =
                      ErrorResponse.fromJson(error.response!.data);
                  if (errorResponse.errors != null &&
                      errorResponse.errors!.isNotEmpty) {
                    errorDescription = errorResponse;
                  } else {
                    errorDescription = 'something_went_wrong';
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
              errorDescription = _isOfflineError(error)
                  ? 'no_internet_connection'
                  : 'something_went_wrong';
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
