import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_button_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_snackbar_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/textfeild/custom_text_feild_widget.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_mfa_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_state_widgets.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_texts.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_second_factor_formatters.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// The second step of the platform admin's sign-in: the code of an authenticator app, or one of the recovery codes.
///
/// The password was accepted and there is no session yet. What the server gave for this step is held by the
/// controller, in memory, and is never given to this screen; nothing typed here is kept, sent anywhere
/// but to the server, or put in a route, and the field is emptied when the screen is left. The keyboard is
/// asked not to correct, suggest or remember what is typed, and the field takes no part in autofill.
class PlatformAdminSecondFactorScreen extends StatefulWidget {
  const PlatformAdminSecondFactorScreen({super.key});

  @override
  State<PlatformAdminSecondFactorScreen> createState() => _PlatformAdminSecondFactorScreenState();
}

class _PlatformAdminSecondFactorScreenState extends State<PlatformAdminSecondFactorScreen> {
  final TextEditingController _code = TextEditingController();
  final FocusNode _codeFocus = FocusNode();
  late final PlatformAdminController _controller;
  late PlatformAdminMfaMethod _method;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = Provider.of<PlatformAdminController>(context, listen: false);
    _method = _controller.secondFactorMethods.contains(PlatformAdminMfaMethod.totp)
        ? PlatformAdminMfaMethod.totp
        : PlatformAdminMfaMethod.recoveryCode;
    _controller.addListener(_planNextLook);
    _planNextLook();
  }

  @override
  void dispose() {
    _controller.removeListener(_planNextLook);
    _timer?.cancel();
    _code.clear();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  bool get _usingRecoveryCode => _method == PlatformAdminMfaMethod.recoveryCode;

  /// Looks at the clock when the controller next has something to say about it: the wait the API asked for ends, or the challenge does.
  void _planNextLook() {
    _timer?.cancel();
    final Duration? next = _controller.secondFactorNextCheck;
    if (next != null) _timer = Timer(next, _lookAtTheClock);
  }

  void _lookAtTheClock() {
    _controller.expireSecondFactorIfOver();
    if (!mounted) return;

    setState(() {});
    _planNextLook();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _controller.cancelSecondFactor();
      },
      child: Scaffold(
        appBar: CustomAppBarWidget(
          title: getTranslated('platform_admin_title', context),
          onBackPressed: _controller.cancelSecondFactor,
        ),
        body: SafeArea(
          child: Consumer<PlatformAdminController>(
            builder: (BuildContext context, PlatformAdminController controller, _) {
              final PlatformAdminFailure? failure = controller.secondFactorFailure;
              final bool waiting = controller.secondFactorWait != null;
              final bool canSwitch = controller.secondFactorMethods.length == PlatformAdminMfaMethod.values.length;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(Dimensions.paddingSizeExtraLarge),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    getTranslated('platform_admin_mfa_title', context)!,
                    style: titilliumBold.copyWith(
                      fontSize: Dimensions.fontSizeOverlarge,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                  Text(
                    _usingRecoveryCode
                        ? getTranslated('platform_admin_mfa_subtitle_recovery', context)!
                        : getTranslated('platform_admin_mfa_subtitle_totp', context)!,
                    style: titilliumRegular.copyWith(color: Theme.of(context).hintColor),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                  if (failure != null) ...[
                    PlatformAdminFailureBanner(
                      failure: failure,
                      message: PlatformAdminTexts.secondFactorFailure(context, failure,
                          triesLeft: controller.secondFactorTriesLeft),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeDefault),
                  ],
                  _codeField(context),
                  const SizedBox(height: Dimensions.paddingSizeExtraLarge),
                  CustomButtonWidget(
                    borderRadius: 16,
                    backgroundColor: waiting ? Theme.of(context).hintColor : Theme.of(context).primaryColor,
                    btnTxt: getTranslated('platform_admin_mfa_verify_button', context),
                    isLoading: controller.isVerifyingSecondFactor,
                    onTap: waiting ? null : _submit,
                  ),
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  if (canSwitch)
                    Center(
                      child: TextButton(
                        onPressed: controller.isVerifyingSecondFactor ? null : _switchMethod,
                        child: Text(
                          _usingRecoveryCode
                              ? getTranslated('platform_admin_mfa_use_code', context)!
                              : getTranslated('platform_admin_mfa_use_recovery', context)!,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  Center(
                    child: TextButton(
                      onPressed: controller.isVerifyingSecondFactor ? null : controller.cancelSecondFactor,
                      child: Text(
                        getTranslated('platform_admin_mfa_back_to_sign_in', context)!,
                        textAlign: TextAlign.center,
                        style: robotoRegular.copyWith(color: Theme.of(context).hintColor),
                      ),
                    ),
                  ),
                ]),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _codeField(BuildContext context) {
    return CustomTextFieldWidget(
      key: ValueKey<PlatformAdminMfaMethod>(_method),
      border: false,
      fillColor: Theme.of(context).primaryColor.withValues(alpha: 0.04),
      prefixIcon: _usingRecoveryCode ? Icons.vpn_key_outlined : Icons.pin_outlined,
      hintText: _usingRecoveryCode
          ? getTranslated('platform_admin_mfa_recovery_hint', context)
          : getTranslated('platform_admin_mfa_code_hint', context),
      focusNode: _codeFocus,
      controller: _code,
      textInputType: _usingRecoveryCode ? TextInputType.text : TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: <TextInputFormatter>[
        _usingRecoveryCode ? platformRecoveryCodeInputFormatter : const PlatformCodeInputFormatter(),
      ],
      maxSize: _usingRecoveryCode ? platformRecoveryCodeMaxLength : PlatformSecondFactorInput.codeLength,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      onFieldSubmit: (_) => _submit(),
    );
  }

  void _switchMethod() {
    setState(() {
      _method = _usingRecoveryCode ? PlatformAdminMfaMethod.totp : PlatformAdminMfaMethod.recoveryCode;
      _code.clear();
    });
  }

  Future<void> _submit() async {
    final String? value = _usingRecoveryCode
        ? PlatformSecondFactorInput.recoveryCode(_code.text)
        : PlatformSecondFactorInput.code(_code.text);

    if (value == null) {
      showCustomSnackBarWidget(
        _usingRecoveryCode
            ? getTranslated('platform_admin_mfa_enter_recovery', context)
            : getTranslated('platform_admin_mfa_enter_code', context),
        context,
        sanckBarType: SnackBarType.warning,
      );
      return;
    }

    await _controller.verifySecondFactor(method: _method, code: value);

    // A code that was refused is not tried again. One that never got an answer is kept, to be sent again.
    if (mounted && _controller.secondFactorFailure?.kind == PlatformAdminFailureKind.unauthenticated) _code.clear();
  }
}
