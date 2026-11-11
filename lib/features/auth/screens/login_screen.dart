import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_button_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/textfeild/custom_text_feild_widget.dart';
import 'package:syriacosmeticsmanger/features/more/screens/html_view_screen.dart';
import 'package:syriacosmeticsmanger/features/splash/domain/models/business_pages_model.dart';
import 'package:syriacosmeticsmanger/helper/email_checker.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/features/auth/controllers/auth_controller.dart';
import 'package:syriacosmeticsmanger/features/splash/controllers/splash_controller.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_snackbar_widget.dart';
import 'package:syriacosmeticsmanger/features/auth/screens/registration_screen.dart';
import 'package:syriacosmeticsmanger/features/dashboard/screens/dashboard_screen.dart';
import 'package:syriacosmeticsmanger/features/auth/screens/forget_password_screen.dart';
import 'package:syriacosmeticsmanger/core/animations/app_animations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  TextEditingController? _emailController;
  TextEditingController? _passwordController;
  GlobalKey<FormState>? _formKeyLogin;

  @override
  void initState() {
    super.initState();
    _formKeyLogin = GlobalKey<FormState>();

    if(_emailController == null) {
      _emailController = TextEditingController();
      _passwordController = TextEditingController();
    }

    if(!Provider.of<AuthController>(context, listen: false).isUnAuthorize) {
      final AuthController authController = Provider.of<AuthController>(context, listen: false);
      _emailController!.text = authController.getUserEmail();
      // The password now lives in the Keystore/Keychain, which is async-only,
      // so prefill it once the secure store has been read.
      authController.primeCredentialCache().then((_) {
        if (mounted) {
          setState(() => _passwordController!.text = authController.getUserPassword());
        }
      });
      authController.setUnAuthorize(true, update: false);
    }
  }

  @override
  void dispose() {
    _emailController!.dispose();
    _passwordController!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<AuthController>(context, listen: false).isActiveRememberMe;

    return Consumer<AuthController>(
      builder: (context, authProvider, child) => Form(
        key: _formKeyLogin,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeSmall),
          child: Column(
            children: [
              // Email Field Container
              Container(
                margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                child: CustomTextFieldWidget(
                  border: false,
                  fillColor: Theme.of(context).primaryColor.withValues(alpha: 0.04),
                  prefixIcon: Icons.email_outlined,

              //    prefixIconImage: Images.emailIcon,
                  hintText: getTranslated('enter_email_address', context),
                  focusNode: _emailFocus,
                  nextNode: _passwordFocus,
                  textInputType: TextInputType.emailAddress,
                  controller: _emailController,
                ),
              ).animateSectionEntrance(index: 0),
              const SizedBox(height: Dimensions.paddingSizeSmall),

              // Password Field Container
              Container(
                margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
                child: CustomTextFieldWidget(
                  border: false,
                  fillColor: Theme.of(context).primaryColor.withValues(alpha: 0.04),
                  isPassword: true,
                  prefixIcon: Icons.lock_open,
                  // prefixIconImage: Images.lock,
                  hintText: getTranslated('password_hint', context),
                  focusNode: _passwordFocus,
                  textInputAction: TextInputAction.done,
                  controller: _passwordController,
                ),
              ).animateSectionEntrance(index: 1),

              // Remember Me & Forget Password
              Container(
                margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeLarge),
                child: Consumer<AuthController>(
                  builder: (context, authProvider, child) => Row(
                    children: [
                      InkWell(
                        splashColor: Colors.transparent,
                        onTap: () => authProvider.toggleRememberMe(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: Dimensions.iconSizeDefault,
                              height: Dimensions.iconSizeDefault,
                              decoration: BoxDecoration(
                                color: authProvider.isActiveRememberMe
                                    ? Theme.of(context).primaryColor
                                    : Theme.of(context).cardColor,
                                border: Border.all(
                                  color: authProvider.isActiveRememberMe
                                      ? Theme.of(context).primaryColor
                                      : Theme.of(context).hintColor.withValues(alpha: .5),
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: authProvider.isActiveRememberMe
                                  ? Icon(
                                      Icons.done,
                                      color: Theme.of(context).colorScheme.secondaryContainer,
                                      size: Dimensions.iconSizeSmall,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            const SizedBox(width: Dimensions.paddingSizeSmall),
                            Text(
                              getTranslated('remember_me', context)!,
                              style: Theme.of(context).textTheme.displayMedium!.copyWith(
                                    fontSize: Dimensions.fontSizeDefault,
                                    color: Theme.of(context).hintColor,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        splashColor: Colors.transparent,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                        ),
                        child: Text(
                          getTranslated('forget_password', context)!,
                          style: robotoRegular.copyWith(
                            color: Theme.of(context).primaryColor,
                          //  decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animateSectionEntrance(index: 2),
              const SizedBox(height: Dimensions.paddingSizeButton),

              // Login Button
              (!authProvider.isLoading
                  ? SizedBox(
                  width: double.infinity,
                    child: Padding(

                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: CustomButtonWidget(
                          borderRadius: 16,
                          backgroundColor: Theme.of(context).primaryColor,
                          btnTxt: getTranslated('login', context),
                          onTap: () async {
                            String email = _emailController!.text.trim();
                            String password = _passwordController!.text.trim();
                            if (email.isEmpty) {
                              showCustomSnackBarWidget(
                                getTranslated('enter_email_address', context),
                                context,
                                sanckBarType: SnackBarType.warning,
                              );
                            } else if (EmailChecker.isNotValid(email)) {
                              showCustomSnackBarWidget(
                                getTranslated('enter_valid_email', context),
                                context,
                                sanckBarType: SnackBarType.warning,
                              );
                            } else if (password.isEmpty) {
                              showCustomSnackBarWidget(
                                getTranslated('enter_password', context),
                                context,
                                sanckBarType: SnackBarType.warning,
                              );
                            } else if (password.length < 6) {
                              showCustomSnackBarWidget(
                                getTranslated('password_should_be', context),
                                context,
                                sanckBarType: SnackBarType.warning,
                              );
                            } else {
                              authProvider.login(
                                context,
                                emailAddress: email,
                                password: password,
                              ).then((status) async {
                                if (status.response?.statusCode == 200) {
                                  if (authProvider.isActiveRememberMe) {
                                    authProvider.saveUserNumberAndPassword(email, password);
                                  } else {
                                    authProvider.clearUserEmailAndPassword();
                                  }
                                  Navigator.pushAndRemoveUntil(
                                    Get.context!,
                                    MaterialPageRoute(builder: (_) => const DashboardScreen()),
                                    (route) => false,
                                  );
                                }
                              });
                            }
                          },
                        ),
                      ),
                  )
                  : Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                      ),
                    )
              ).animateSectionEntrance(index: 3),

              // Seller Registration link
              (Provider.of<SplashController>(context, listen: false).configModel!.sellerRegistration == "1"
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeDefault),
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const RegistrationScreen()),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              getTranslated('dont_have_an_account', context)!,
                              style: robotoRegular.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color),
                            ),
                            const SizedBox(width: Dimensions.paddingSizeSmall),
                            Text(
                              getTranslated('registration_here', context)!,
                              style: robotoTitleRegular.copyWith(
                                color: Theme.of(context).primaryColor,
                               // decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox()
              ).animateSectionEntrance(index: 4),

              // Terms & Conditions
              Consumer<SplashController>(
                builder: (context, splashController, _) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeButton),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HtmlViewScreen(
                              page: getPageBySlug('terms-and-conditions', splashController.defaultBusinessPages),
                            ),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            getTranslated('terms_and_condition', context)!,
                            style: robotoMedium.copyWith(
                              color: Theme.of(context).primaryColor,
                          //    decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ).animateSectionEntrance(index: 5),
            ],
          ),
        ),
      ),
    );
  }

  BusinessPageModel? getPageBySlug(String slug, List<BusinessPageModel>? pagesList) {
    BusinessPageModel? pageModel;
    if (pagesList != null && pagesList.isNotEmpty) {
      for (var page in pagesList) {
        if (page.slug == slug) {
          pageModel = page;
        }
      }
    }
    return pageModel;
  }
}
