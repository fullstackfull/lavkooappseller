import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

/// The seller API rejects any Authorization header whose token is 30
/// characters or shorter, and answers with the same 401 an expired session
/// gives. A client that sends a malformed credential is therefore
/// indistinguishable from one whose session ran out — which is what made the
/// "logged in but every request is 401" state so hard to place.
Future<DioClient> _client({String? storedToken}) async {
  SharedPreferences.setMockInitialValues(
    storedToken == null ? <String, Object>{} : <String, Object>{AppConstants.token: storedToken},
  );

  return DioClient(
    AppConstants.baseUrl,
    Dio(),
    loggingInterceptor: LoggingInterceptor(),
    sharedPreferences: await SharedPreferences.getInstance(),
  );
}

String _authHeader(DioClient client) => '${client.dio!.options.headers['Authorization']}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DioClient auth header', () {
    test('never sends the literal string "Bearer null" when no token is stored', () async {
      final DioClient client = await _client();

      expect(_authHeader(client), 'Bearer ');
      expect(_authHeader(client), isNot(contains('null')));
    });

    test('carries the stored token on construction', () async {
      final DioClient client = await _client(storedToken: 'a-real-looking-session-token-value');

      expect(_authHeader(client), 'Bearer a-real-looking-session-token-value');
    });

    test('updateAuthToken swaps the credential and keeps the language headers', () async {
      final DioClient client = await _client(storedToken: 'first-session-token');
      final Object? languageBefore = client.dio!.options.headers[AppConstants.langKey];

      client.updateAuthToken('second-session-token');

      expect(_authHeader(client), 'Bearer second-session-token');
      expect(client.token, 'second-session-token');
      // Replacing the whole header map is what used to drop these, leaving the
      // rest of the session served in the panel's default language.
      expect(client.dio!.options.headers[AppConstants.langKey], languageBefore);
      expect(client.dio!.options.headers['X-localization'], isNotNull);
      expect(client.dio!.options.headers['Accept-Language'], isNotNull);
      expect(client.dio!.options.headers['Content-Type'], isNotNull);
    });

    test('a blank token never overwrites a working session', () async {
      // The dashboard reads the session out of shared preferences and hands it
      // straight to this client. While that write is still in flight the read
      // comes back empty, and this client is a singleton — so one caller
      // reading a moment too early used to blank the credential for every
      // request that followed. That is what turned a successful login into a
      // wall of 401s and bounced the seller back to the login screen.
      final DioClient client = await _client(storedToken: 'the-live-session-token');

      client.updateAuthToken('');
      expect(_authHeader(client), 'Bearer the-live-session-token');

      client.updateAuthToken('   ');
      expect(_authHeader(client), 'Bearer the-live-session-token');

      client.updateAuthToken(null);
      expect(_authHeader(client), 'Bearer the-live-session-token');
      expect(client.token, 'the-live-session-token');
    });

    test('clearAuthToken drops the credential so a signed-out client cannot reuse it', () async {
      final DioClient client = await _client(storedToken: 'session-to-abandon');

      client.clearAuthToken();

      expect(_authHeader(client), 'Bearer ');
      expect(_authHeader(client), isNot(contains('session-to-abandon')));
      expect(client.token, isNull);
    });
  });
}
