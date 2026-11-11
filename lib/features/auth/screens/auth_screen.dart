import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/features/auth/controllers/auth_controller.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/images.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';
import 'package:syriacosmeticsmanger/features/auth/screens/login_screen.dart';
import 'package:syriacosmeticsmanger/core/animations/app_animations.dart';


class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Provider.of<AuthController>(context, listen: false).isActiveRememberMe;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Consumer<AuthController>(
        builder: (context, auth, child) {
          return Stack(
            children: [

              // Vibrant background gradient

              // Floating glowing blob top right
              Positioned(
                top: -size.height * 0.1,
                right: -size.width * 0.15,
                child: Container(
                  width: size.width * 0.7,
                  height: size.width * 0.7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Theme.of(context).primaryColor.withValues(alpha: 0.15),
                        Colors.transparent,
                      ]
                    )
                  ),
                ),
              ),

              // Floating glowing blob bottom left
              Positioned(
                bottom: -size.height * 0.1,
                left: -size.width * 0.15,
                child: Container(
                  width: size.width * 0.7,
                  height: size.width * 0.7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15),
                        Colors.transparent,
                      ]
                    )
                  ),
                ),
              ),

              // Main content
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeExtraLarge),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: Dimensions.paddingSizeExtraLarge),
                          // Logo Section
                          Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: Hero(
                              tag: 'logo',
                              child: Image.asset(
                                Images.logoWithAppName,
                                width: 220,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ).animateSectionEntrance(index: 0),
                          const SizedBox(height: Dimensions.paddingSizeLarge),

                          // App Title
                      /*
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                getTranslated('seller', context)!,
                                style: robotoMedium.copyWith(
                                  fontSize: Dimensions.fontSizeExtraLargeTwenty,
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                              Text(
                                getTranslated('app', context)!,
                                style: robotoMedium.copyWith(
                                  color: Theme.of(context).primaryColor,
                                  fontSize: Dimensions.fontSizeExtraLargeTwenty,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ).animateSectionEntrance(index: 1),
                       */
                          const SizedBox(height: Dimensions.paddingSizeExtraLarge),

                          // Login Container Card (Glassmorphism inspired)
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  getTranslated('login', context)!,
                                  style: titilliumBold.copyWith(
                                    fontSize: Dimensions.fontSizeOverlarge,
                                    color: Theme.of(context).textTheme.bodyLarge?.color,
                                  ),
                                ),
                                const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                                Text(
                                  getTranslated('manage_your_business_from_app', context)!,
                                  style: titilliumRegular.copyWith(
                                    fontSize: Dimensions.fontSizeDefault,
                                    color: Theme.of(context).hintColor,
                                  ),
                                ),
                                const SizedBox(height: Dimensions.paddingSizeExtraLarge),
                                const LoginScreen(),
                              ],
                            ),
                          const SizedBox(height: Dimensions.paddingSizeExtraLarge),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}



