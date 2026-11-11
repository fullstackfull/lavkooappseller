import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_snackbar_widget.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/features/auth/controllers/auth_controller.dart';
import 'package:syriacosmeticsmanger/features/auth/screens/auth_screen.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';

class ApiChecker {
  static void checkApi(ApiResponse apiResponse, {bool firebaseResponse = false}) {
    // The navigator may not be mounted yet (errors during startup) or may be
    // gone already (errors resolving after teardown). Either way there is no
    // context to show anything with, so bail out instead of crashing on `!`.
    final BuildContext? context = Get.context;
    if (context == null) {
      debugPrint('ApiChecker: no navigator context, dropping error "${apiResponse.error}"');
      return;
    }

    if (apiResponse.error.toString() == 'unauthorized') {
      final AuthController authController = Provider.of<AuthController>(context, listen: false);

      // One sign-out, not one per rejected request. A dashboard load fires
      // about twenty authenticated calls at once, so an expired token arrived
      // here twenty times and started twenty concurrent session wipes — each
      // one able to land on a session the seller had already signed back into.
      // The latch guarded only the navigation; now it guards the wipe as well.
      if (authController.isUnAuthorize == false) {
        authController.setUnAuthorize(true, update: true);
        authController.clearSharedData();

        try {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthScreen()),
            (route) => false,
          );
        } catch (ex) {
          debugPrint("===RouteException==>>$ex");
        }
      }
      return;
    }

    String? errorMessage;
    if (apiResponse.error is String) {
      errorMessage = apiResponse.error.toString();
    } else {
      try {
        errorMessage = apiResponse.error.errors[0].message;
      } catch (_) {
        errorMessage = null;
      }
    }

    if (firebaseResponse) {
      errorMessage = errorMessage?.replaceAll('_', ' ');
    }

    // An empty message used to mean "show nothing", which silently swallowed
    // every connectivity failure. Fall back to a generic translated message so
    // a failed request is never invisible.
    if (errorMessage == null || errorMessage.trim().isEmpty) {
      errorMessage = 'something_went_wrong';
    }

    // Known keys resolve to the active language; anything else (a message the
    // server produced) passes through getTranslated unchanged.
    final String? displayMessage = getTranslated(errorMessage, context);

    showCustomSnackBarWidget(displayMessage, context, sanckBarType: SnackBarType.error);
  }
}
