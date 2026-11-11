import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syriacosmeticsmanger/core/animations/app_animations.dart';
import 'package:syriacosmeticsmanger/theme/app_glass.dart';
import 'package:syriacosmeticsmanger/theme/light_theme.dart' show kAppFontFamily;
import 'package:syriacosmeticsmanger/utill/dimensions.dart';

const Color _primaryColor = Color(0xFF3FAE7F);
const Color _secondaryColor = Color(0xFFF58300);

final ThemeData dark = ThemeData(
  useMaterial3: true,
  fontFamily: kAppFontFamily,
  primaryColor: _primaryColor,
  brightness: Brightness.dark,
  highlightColor: const Color(0xFF151E1A),
  hintColor: const Color(0xFF9AB2A8),
  canvasColor: const Color(0xFF0F1713),
  cardColor: const Color(0xFF141E19),
  splashColor: Colors.transparent,
  scaffoldBackgroundColor: Colors.transparent,
  bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.transparent),

  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Color(0xFFE9EEF4)),
    bodyMedium: TextStyle(color: Color(0xFFE9EEF4)),
    bodySmall: TextStyle(color: Color(0xFF9AB2A8)),
    headlineMedium: TextStyle(color: Color(0xFF9AB2A8)),
    headlineLarge: TextStyle(color: Color(0xFFB9CEC5)),
  ),

  colorScheme: const ColorScheme.dark(
    primary: _primaryColor,
    secondary: _secondaryColor,
    tertiary: Color(0xFFFFBB38),                 // Warning
    tertiaryContainer: Color(0xFF202F29),
    onTertiaryContainer: Color(0xFF2FD79B),      // Success
    primaryContainer: Color(0xFF208458),
    // Was near-white in the old dark theme, which made placeholder blocks glow.
    secondaryContainer: Color(0xFF18241F),
    surface: Color(0xFF111B17),
    outline: Color(0xff478F71),                  // Info / pending
    surfaceTint: Color(0xff478F71),
    onPrimary: Color(0xFF08120E),
    onSecondary: Color(0xFFFC9926),
    error: Color(0xFFFF7B7B),
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    iconTheme: IconThemeData(color: Color(0xFFE9EEF4)),
    titleTextStyle: TextStyle(
      fontFamily: kAppFontFamily,
      fontWeight: FontWeight.w700,
      fontSize: Dimensions.fontSizeLarge,
      color: Color(0xFFE9EEF4),
    ),
    systemOverlayStyle: SystemUiOverlayStyle.light,
  ),

  cardTheme: CardThemeData(
    color: const Color(0xFF141E19),
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.radiusLarge)),
  ),

  dialogTheme: DialogThemeData(
    backgroundColor: const Color(0xFF141E19),
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.radiusXLarge)),
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF15201C),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: Dimensions.paddingSize,
      vertical: Dimensions.paddingSize,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(Dimensions.radiusMedium),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(Dimensions.radiusMedium),
      borderSide: const BorderSide(color: Color(0xFF1D2B25)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(Dimensions.radiusMedium),
      borderSide: const BorderSide(color: _primaryColor, width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(Dimensions.radiusMedium),
      borderSide: const BorderSide(color: Color(0xFFFF7B7B)),
    ),
    hintStyle: const TextStyle(color: Color(0xFF8AA399), fontFamily: kAppFontFamily),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 0,
      backgroundColor: _primaryColor,
      foregroundColor: const Color(0xFF08120E),
      padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeMedium),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.radiusMedium)),
      textStyle: const TextStyle(fontFamily: kAppFontFamily, fontWeight: FontWeight.w600),
    ),
  ),

  snackBarTheme: const SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    elevation: 0,
  ),

  dividerTheme: const DividerThemeData(color: Color(0xFF1A2621), thickness: 1, space: 1),

  pageTransitionsTheme: const PageTransitionsTheme(builders: {
    TargetPlatform.android: PremiumPageTransitionsBuilder(),
    TargetPlatform.iOS: PremiumPageTransitionsBuilder(),
    TargetPlatform.fuchsia: PremiumPageTransitionsBuilder(),
    TargetPlatform.macOS: PremiumPageTransitionsBuilder(),
    TargetPlatform.windows: PremiumPageTransitionsBuilder(),
    TargetPlatform.linux: PremiumPageTransitionsBuilder(),
  }),

  extensions: const <ThemeExtension<dynamic>>[AppGlass.darkTokens],
);
