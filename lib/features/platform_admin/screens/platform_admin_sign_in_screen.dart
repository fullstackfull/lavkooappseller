import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_button_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_snackbar_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/textfeild/custom_text_feild_widget.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_state_widgets.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_texts.dart';
import 'package:syriacosmeticsmanger/helper/email_checker.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// What a device is called in the list of sessions until the admin names it.
abstract final class PlatformAdminDeviceName {
  static const String base = 'Lavkoo Seller';

  /// The most the API takes.
  static const int maxLength = 100;

  static String suggested({TargetPlatform? platform}) => '$base (${_label(platform ?? defaultTargetPlatform)})';

  static String _label(TargetPlatform platform) => switch (platform) {
        TargetPlatform.android => 'Android',
        TargetPlatform.iOS => 'iOS',
        TargetPlatform.macOS => 'macOS',
        _ => platform.name,
      };
}

/// The platform admin's own sign-in: the admin's e-mail and password, and a name
/// for this phone.
///
/// Nothing here is the seller's login: it asks the platform admin API, it keeps
/// no e-mail and offers no "remember me", and a password stays in the field
/// only until the request has been sent.
class PlatformAdminSignInScreen extends StatefulWidget {
  const PlatformAdminSignInScreen({super.key});

  @override
  State<PlatformAdminSignInScreen> createState() => _PlatformAdminSignInScreenState();
}

class _PlatformAdminSignInScreenState extends State<PlatformAdminSignInScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _deviceName = TextEditingController(text: PlatformAdminDeviceName.suggested());
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _deviceNameFocus = FocusNode();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _deviceName.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _deviceNameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: getTranslated('platform_admin_title', context)),
      body: SafeArea(
        child: Consumer<PlatformAdminController>(
          builder: (BuildContext context, PlatformAdminController controller, _) {
            final PlatformAdminFailure? failure = controller.signInFailure;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(Dimensions.paddingSizeExtraLarge),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  getTranslated('platform_admin_title', context)!,
                  style: titilliumBold.copyWith(
                    fontSize: Dimensions.fontSizeOverlarge,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                Text(
                  getTranslated('platform_admin_sign_in_subtitle', context)!,
                  style: titilliumRegular.copyWith(color: Theme.of(context).hintColor),
                ),
                const SizedBox(height: Dimensions.paddingSizeLarge),
                if (controller.sessionEnded) ...[
                  PlatformAdminNote(
                    text: getTranslated('platform_admin_session_ended', context)!,
                    icon: Icons.lock_clock_outlined,
                  ),
                  const SizedBox(height: Dimensions.paddingSizeDefault),
                ],
                if (failure != null) ...[
                  PlatformAdminFailureBanner(
                    failure: failure,
                    message: PlatformAdminTexts.signInFailure(context, failure),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeDefault),
                ],
                CustomTextFieldWidget(
                  border: false,
                  fillColor: Theme.of(context).primaryColor.withValues(alpha: 0.04),
                  prefixIcon: Icons.email_outlined,
                  hintText: getTranslated('enter_email_address', context),
                  focusNode: _emailFocus,
                  nextNode: _passwordFocus,
                  textInputType: TextInputType.emailAddress,
                  controller: _email,
                ),
                const SizedBox(height: Dimensions.paddingSizeDefault),
                // The hint of this field is a row of dots, which a screen reader cannot read as "password".
                Semantics(
                  label: getTranslated('password', context),
                  child: CustomTextFieldWidget(
                    border: false,
                    fillColor: Theme.of(context).primaryColor.withValues(alpha: 0.04),
                    isPassword: true,
                    prefixIcon: Icons.lock_open,
                    hintText: getTranslated('password_hint', context),
                    focusNode: _passwordFocus,
                    nextNode: _deviceNameFocus,
                    controller: _password,
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeDefault),
                CustomTextFieldWidget(
                  border: false,
                  fillColor: Theme.of(context).primaryColor.withValues(alpha: 0.04),
                  prefixIcon: Icons.phone_android_outlined,
                  hintText: getTranslated('platform_admin_device_name_hint', context),
                  focusNode: _deviceNameFocus,
                  textInputAction: TextInputAction.done,
                  maxSize: PlatformAdminDeviceName.maxLength,
                  controller: _deviceName,
                  onFieldSubmit: (_) => _submit(),
                ),
                const SizedBox(height: Dimensions.paddingSizeExtraLarge),
                CustomButtonWidget(
                  borderRadius: 16,
                  backgroundColor: Theme.of(context).primaryColor,
                  btnTxt: getTranslated('platform_admin_sign_in_button', context),
                  isLoading: controller.stage == PlatformAdminStage.signingIn,
                  onTap: _submit,
                ),
              ]),
            );
          },
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final String email = _email.text.trim();
    final String password = _password.text;
    final String deviceName = _deviceName.text.trim();

    final String? problem = _problemWith(email: email, password: password, deviceName: deviceName);
    if (problem != null) {
      showCustomSnackBarWidget(problem, context, sanckBarType: SnackBarType.warning);
      return;
    }

    final bool signedIn = await Provider.of<PlatformAdminController>(context, listen: false).signIn(
      email: email,
      password: password,
      deviceName: deviceName,
    );

    if (!signedIn && mounted) _password.clear();
  }

  String? _problemWith({required String email, required String password, required String deviceName}) {
    if (email.isEmpty) return getTranslated('enter_email_address', context);
    if (EmailChecker.isNotValid(email)) return getTranslated('enter_valid_email', context);
    if (password.isEmpty) return getTranslated('enter_password', context);
    if (deviceName.isEmpty) return getTranslated('platform_admin_enter_device_name', context);
    return null;
  }
}
