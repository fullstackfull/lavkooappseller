import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

class DioClient {
  final String baseUrl;
  final LoggingInterceptor loggingInterceptor;
  final SharedPreferences sharedPreferences;

  Dio? dio;
  String? token;
  String _language = 'en';

  /// Every live client, so a language change updates them all at once.
  static final Set<DioClient> _instances = <DioClient>{};

  /// Called when the user switches language so subsequent requests carry it.
  static void setLanguage(String languageCode) {
    for (final DioClient client in _instances) {
      client._language = languageCode;
      client.dio?.options.headers[AppConstants.langKey] = languageCode;
      client.dio?.options.headers['X-localization'] = languageCode;
      client.dio?.options.headers['Accept-Language'] = languageCode;
    }
  }

  DioClient(this.baseUrl,
      Dio? dioC, {
        required this.loggingInterceptor,
        required this.sharedPreferences,
      }) {
    token = sharedPreferences.getString(AppConstants.token);
    _language = sharedPreferences.getString(AppConstants.languageCode) ?? 'en';
    dio = dioC ?? Dio();
    dio!
      ..options.baseUrl = baseUrl
      ..options.connectTimeout = const Duration(seconds: 60)
      ..options.receiveTimeout = const Duration(seconds: 60)
      ..options.headers = {
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
        // An absent token used to be interpolated as the literal string
        // 'Bearer null', which the seller middleware rejects with a 401 — the
        // same 401 a genuinely expired session gives, so the cause was
        // indistinguishable from the symptom.
        'Authorization': 'Bearer ${token ?? ''}',
        // Without a localization header every server-rendered string (category
        // names, order statuses, validation messages, push notifications)
        // came back in the panel's default language.
        AppConstants.langKey: _language,
        'X-localization': _language,
        'Accept-Language': _language,
      };
    _instances.add(this);
    // The logging interceptor stringifies every response body; that cost (and
    // the token in the log) has no place in a release build.
    if (kDebugMode) {
      dio!.interceptors.add(loggingInterceptor);
    }
  }

  /// Point the client at a new session token.
  ///
  /// Only the Authorization entry is touched. Repositories used to assign a
  /// whole new header map here, which silently dropped the three localization
  /// headers for the rest of the session.
  ///
  /// A blank token is ignored rather than installed. Callers hand this the
  /// result of reading the session out of shared preferences, which is empty
  /// while that write is still in flight — and this client is a singleton, so
  /// one caller reading a moment too early used to blank the credential for
  /// every request that followed, turning a good session into a wall of 401s.
  /// Signing out is a deliberate act and goes through [clearAuthToken].
  void updateAuthToken(String? sessionToken) {
    if (sessionToken == null || sessionToken.trim().isEmpty) {
      return;
    }

    token = sessionToken;
    dio?.options.headers['Authorization'] = 'Bearer $sessionToken';
  }

  /// Drop the credential on sign-out, so the next request cannot be made with
  /// the session that was just abandoned.
  void clearAuthToken() {
    token = null;
    dio?.options.headers['Authorization'] = 'Bearer ';
  }

  Future<Response> get(String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      var response = await dio!.get(
        uri,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } on SocketException catch (e) {
      throw SocketException(e.toString());
    } on FormatException catch (_) {
      throw const FormatException("Unable to process the data");
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> post(String uri, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      var response = await dio!.post(
        uri,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );

      return response;
    } on FormatException {
      throw const FormatException("Unable to process the data");
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> postMultipart(String uri, {
    Map<String, dynamic>? data,
    List<MultipartWithKey>? files,
    String? fileKey,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    Map<String, dynamic>? otherFiles
  }) async {
    debugPrint('apiCall ==> url=> $uri \nparams---> $queryParameters\nheader=> ${dio!.options.headers}');

    try {
      // List<MultipartFile> fileList = [];
      //
      // if(files != null) {
      //   for(int i = 0; i < files.length; i++) {
      //     fileList.add(MultipartFile.fromBytes(
      //       await files[i]!.readAsBytes(),
      //       filename: files[i]!.name,
      //     ));
      //   }
      // }



      for(int i = 0; i < (files?.length ?? 0); i++) {
        data?.addAll({files![i].key : files[i].multipartFile});
      }


      // if(files?.isNotEmpty ?? false) {
      //   data?.addAll({
      //     '${fileKey ?? 'image'}[]' : files,
      //   });
      // }

    } catch(e) {
      debugPrint('----exImage---$e-----');
      rethrow;
    }

    try {


      for(int i=0; i<FormData.fromMap(data ?? {}).fields.length; i++){

        debugPrint("=====FromData==$i=>>${FormData.fromMap(data ?? {}).fields[i]}");

      }


      var response = await dio!.post(
        uri,
        // data: data,
        data: FormData.fromMap(data ?? {}),
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } on FormatException catch (_) {
      throw const FormatException("Unable to process the data");
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> put(String uri, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      var response = await dio!.put(
        uri,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } on FormatException catch (_) {
      throw const FormatException("Unable to process the data");
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> delete(String uri, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      var response = await dio!.delete(
        uri,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response;
    } on FormatException catch (_) {
      throw const FormatException("Unable to process the data");
    } catch (e) {
      rethrow;
    }
  }

}

class MultipartWithKey{
  final String key;
  final MultipartFile? multipartFile;

  MultipartWithKey({required this.key, this.multipartFile});


}
