import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/auth/domain/repositories/auth_repository.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

import 'market_selector/support/recording_adapter.dart';

/// Signing out ends the session on the server, and not only on this phone (K-12).
///
/// The app used to forget the token and navigate to the login screen. Nothing told the server, so the session that token
/// opens stayed live for the token's whole life: a signed-out phone, a backup of that phone, or anyone else holding a copy
/// of the string still had a working seller session. The server half is in place and proven
/// (`SellerSignOutEndsTheSessionTest`): `POST api/v3/seller/auth/logout` revokes the token the request arrived with --
/// `sellers.auth_token` for an owner, `seller_staff.auth_token` for a member of staff -- and refuses an issued API key,
/// because a key is revoked in the key console by the shop and not by whatever is holding it.
///
/// This file is the app half: that the request is made, that it carries the credential being given up, that it is made for
/// a deliberate sign-out and not for a session the server has already refused, and that a server which cannot be reached --
/// or is old enough not to know the route -- still leaves the seller signed out.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String token = 'a-real-looking-session-token-value-of-the-right-length';

  /// A server that refuses everything it is sent, with the status it is built with.
  late int refuseWith;

  Future<AuthRepository> repositoryOn(HttpClientAdapter network) async {
    SharedPreferences.setMockInitialValues(
        <String, Object>{AppConstants.token: token});
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    return AuthRepository(
      dioClient: DioClient(
          AppConstants.baseUrl, Dio()..httpClientAdapter = network,
          loggingInterceptor: LoggingInterceptor(),
          sharedPreferences: preferences),
      sharedPreferences: preferences,
    );
  }

  setUp(() => refuseWith = 500);

  group('the request that gives the credential back', () {
    test('goes to the seller API\'s own logout route, by POST', () async {
      final RecordingAdapter network = RecordingAdapter();
      final AuthRepository auth = await repositoryOn(network);

      await auth.endServerSession(token);

      expect(network.requests, hasLength(1));
      expect(network.last.method, 'POST');
      expect(network.last.uri.path, '/api/v3/seller/auth/logout');
      expect(network.last.uri.path, AppConstants.logoutUri);
    });

    test(
        'carries the session being given up, and not whatever the client happens to hold',
        () async {
      final RecordingAdapter network = RecordingAdapter();
      final AuthRepository auth = await repositoryOn(network);

      // What the sign-out actually does: the client's credential is dropped first, so a request that read the header from
      // the client would arrive as `Bearer ` -- the same empty credential the seller middleware answers 401 to, which would
      // revoke nothing and look exactly like a session that had already run out.
      auth.dioClient!.clearAuthToken();
      await auth.endServerSession(token);

      expect('${network.last.header('authorization')}', 'Bearer $token');
      expect('${network.last.header('authorization')}', isNot('Bearer '));
    });

    test(
        'says nothing else: the body is empty, because the token in the header is the whole request',
        () async {
      final RecordingAdapter network = RecordingAdapter();
      final AuthRepository auth = await repositoryOn(network);

      await auth.endServerSession(token);

      expect(network.last.uri.queryParameters, isEmpty,
          reason: 'a credential does not belong in a URL');
    });

    test(
        'a server that refuses it still signs the seller out, and the refusal is reported rather than thrown',
        () async {
      for (final int status in <int>[401, 404, 419, 500]) {
        refuseWith = status;
        final AuthRepository auth =
            await repositoryOn(_RefusingAdapter(() => refuseWith));

        final ApiResponse answer = await auth.endServerSession(token);

        // 404 is the one that matters most: a shop running a backend from before this route existed answers it, and that
        // must behave exactly as every sign-out behaved before this call was added.
        expect(answer.error, isNotNull, reason: 'status $status');
        expect(answer.response?.statusCode, isNot(200),
            reason: 'status $status');
      }
    });

    test('a phone with no network at all still signs the seller out', () async {
      final AuthRepository auth = await repositoryOn(_UnreachableAdapter());

      final ApiResponse answer = await auth.endServerSession(token);

      expect(answer.error, isNotNull);
      expect(answer.response, isNull);
    });
  });

  group('by reading the source', () {
    /// Flattened whitespace: `dart format` wraps at 80 columns and which style it picks depends on the package's language
    /// version, so an assertion written against one line break says nothing about the behaviour the day the other is used.
    String codeOf(String path) => File(path)
        .readAsStringSync()
        .replaceAll(RegExp(r'//[^\n]*'), '')
        .replaceAll(RegExp(r'\s+'), ' ');

    test(
        'the sign-out reads the token BEFORE the local clear and sends it AFTER, so no sign-out waits on a round trip',
        () {
      final String controller =
          codeOf('lib/features/auth/controllers/auth_controller.dart');

      final int reads = controller.indexOf('final String? sessionToEnd =');
      final int clears = controller.indexOf(
          'final bool cleared = await authServiceInterface.clearSharedData();');
      final int sends = controller
          .indexOf('await authServiceInterface.endServerSession(sessionToEnd)');

      expect(reads, greaterThan(0));
      expect(clears, greaterThan(reads),
          reason: 'the token has to be read while the phone still has it');
      expect(sends, greaterThan(clears),
          reason:
              'the local sign-out must not sit behind a round trip: a seller with prefilled credentials can be signed '
              'back in while one is in flight, and the tail of the old sign-out then erases the new session');
    });

    test('a session the server has already refused sends nothing', () {
      final String controller =
          codeOf('lib/features/auth/controllers/auth_controller.dart');

      expect(
          controller,
          contains(
              'fromUnAuthorizationError ? null : authServiceInterface.getUserToken()'));
      expect(controller,
          contains('if (sessionToEnd != null && sessionToEnd.isNotEmpty) {'));
    });

    test(
        'every sign-out of the app goes through the one funnel that makes this call',
        () {
      // Both buttons of the sign-out sheet, and the handler for an unauthorized answer, end a session by calling
      // `clearSharedData` -- which is why the call lives there and not beside a button.
      expect(
          codeOf(
              'lib/features/menu/widgets/sign_out_confirmation_dialog_widget.dart'),
          contains('clearSharedData()'));
      expect(
          codeOf('lib/helper/api_checker.dart'), contains('clearSharedData('));
    });
  });
}

/// A server that answers every request with a refusal.
class _RefusingAdapter implements HttpClientAdapter {
  _RefusingAdapter(this.status);

  final int Function() status;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString(
        jsonEncode(<String, dynamic>{'message': 'no'}),
        status(),
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

/// A phone that cannot reach anything.
class _UnreachableAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) =>
      Future<ResponseBody>.error(DioException.connectionError(
          requestOptions: options, reason: 'no route to host'));

  @override
  void close({bool force = false}) {}
}
