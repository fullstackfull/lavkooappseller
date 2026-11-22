import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/auth/controllers/auth_controller.dart';
import 'package:syriacosmeticsmanger/features/auth/domain/services/auth_service_interface.dart';
import 'package:syriacosmeticsmanger/helper/api_checker.dart';

class _UnusedAuthService implements AuthServiceInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('the session latch does not use ${invocation.memberName}');
}

/// The real latch of the real controller, with the wipe of the session counted instead of run: the wipe reads the shop controller and the stored credentials, which this test is not about.
class _CountingAuthController extends AuthController {
  _CountingAuthController() : super(authServiceInterface: _UnusedAuthService());

  int wipes = 0;

  @override
  Future<bool> clearSharedData({bool fromUnAuthorizationError = false}) async {
    wipes++;

    return true;
  }
}

class _CountingObserver extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }
}

/// K-12: a dashboard load fires about twenty authenticated calls at once, so an expired token reaches [ApiChecker] twenty times. Each of them used to start a session wipe, and each wipe
/// could land on a session the seller had signed back into.
void main() {
  late _CountingAuthController auth;
  late _CountingObserver observer;

  Future<void> pumpApp(WidgetTester tester) async {
    auth = _CountingAuthController();
    observer = _CountingObserver();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: auth,
        child: MaterialApp(navigatorKey: navigatorKey, navigatorObservers: <NavigatorObserver>[observer], home: const Scaffold(body: SizedBox.shrink())),
      ),
    );
    observer.pushes = 0;
  }

  /// The answer the seller API gives when the token is no longer a session.
  ApiResponse expiredToken() => ApiResponse.withError('unauthorized');

  group('a burst of 401s', () {
    testWidgets('signs the seller out once: one wipe of the session and one trip to the sign-in screen', (WidgetTester tester) async {
      await pumpApp(tester);

      for (int request = 0; request < 20; request++) {
        ApiChecker.checkApi(expiredToken());
      }

      expect(auth.wipes, 1);
      expect(observer.pushes, 1);
      expect(auth.isUnAuthorize, isTrue);
    });

    testWidgets('signs the seller out again after the seller has signed in again', (WidgetTester tester) async {
      await pumpApp(tester);
      ApiChecker.checkApi(expiredToken());

      auth.setUnAuthorize(false);
      ApiChecker.checkApi(expiredToken());
      ApiChecker.checkApi(expiredToken());

      expect(auth.wipes, 2);
      expect(observer.pushes, 2);
    });
  });

  group('an answer that is not a 401', () {
    testWidgets('never wipes the session', (WidgetTester tester) async {
      await pumpApp(tester);

      ApiChecker.checkApi(ApiResponse.withError('Connection timed out'));
      await tester.pump();

      expect(auth.wipes, 0);
      expect(auth.isUnAuthorize, isFalse);
      expect(observer.pushes, 0);
    });
  });
}
