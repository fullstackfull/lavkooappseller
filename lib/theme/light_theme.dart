import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syriacosmeticsmanger/core/animations/app_animations.dart';
import 'package:syriacosmeticsmanger/theme/app_glass.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';

/// Single source of truth for the app font. Cairo carries Arabic and Latin in
/// one family, so mixed strings keep one weight and one baseline.
const String kAppFontFamily = 'Cairo';

const Color _primaryColor = Color(0xFF1F7A55);
const Color _secondaryColor = Color(0xFFF58300);

final ThemeData light = ThemeData(
  useMaterial3: true,
  fontFamily: kAppFontFamily,
  primaryColor: _primaryColor,
  brightness: Brightness.light,
  highlightColor: Colors.white,
  hintColor: const Color(0xFF8EA39A),
  disabledColor: const Color(0xFF34403B),
  canvasColor: const Color(0xFFFCFCFC),
  cardColor: const Color(0xFFFFFFFF),
  splashColor: Colors.transparent,
  // Transparent so the AmbientBackground wash shows through the app shell.
  scaffoldBackgroundColor: Colors.transparent,
  bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.transparent),

  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Color(0xFF0F1B16)),  // Text color primary
    bodyMedium: TextStyle(color: _primaryColor),      // Text color secondary
    bodySmall: TextStyle(color: Color(0xFF8EA39A)),   // Text color light grey
    headlineMedium: TextStyle(color: Color(0xFF9AAFA6)),
    headlineLarge: TextStyle(color: Color(0xFF5A7369)),
  ),

  colorScheme: const ColorScheme.light(
    primary: _primaryColor,
    secondary: _secondaryColor,
    error: Color(0xFFE84545),
    tertiary: Color(0xFFFFBB38),                 // Warning
    tertiaryContainer: Color(0xFF618878),
    onTertiaryContainer: Color(0xFF04BB7B),      // Success
    primaryContainer: Color(0xFF9AECC6),
    secondaryContainer: Color(0xFFEFF2F6),
    surface: Color(0xFFFFFFFF),
    surfaceTint: Color(0xFF1D8F5F),
    onPrimary: Color(0xFF3A8F6B),
    onSecondary: Color(0xFFFC9926),
    outline: Color(0xff348D68),                  // Info / pending
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    iconTheme: IconThemeData(color: Color(0xFF0F1B16)),
    titleTextStyle: TextStyle(
      fontFamily: kAppFontFamily,
      fontWeight: FontWeight.w700,
      fontSize: Dimensions.fontSizeLarge,
      color: Color(0xFF0F1B16),
    ),
    systemOverlayStyle: SystemUiOverlayStyle.dark,
  ),

  cardTheme: CardThemeData(
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.radiusLarge)),
  ),

  dialogTheme: DialogThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.radiusXLarge)),
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFF4F6F9),
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
      borderSide: const BorderSide(color: Color(0xFFE4E9F0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(Dimensions.radiusMedium),
      borderSide: const BorderSide(color: _primaryColor, width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(Dimensions.radiusMedium),
      borderSide: const BorderSide(color: Color(0xFFE84545)),
    ),
    hintStyle: const TextStyle(color: Color(0xFF9AAFA6), fontFamily: kAppFontFamily),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 0,
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
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

  dividerTheme: const DividerThemeData(color: Color(0xFFE9EDF3), thickness: 1, space: 1),

  pageTransitionsTheme: const PageTransitionsTheme(builders: {
    TargetPlatform.android: PremiumPageTransitionsBuilder(),
    TargetPlatform.iOS: PremiumPageTransitionsBuilder(),
    TargetPlatform.fuchsia: PremiumPageTransitionsBuilder(),
    TargetPlatform.macOS: PremiumPageTransitionsBuilder(),
    TargetPlatform.windows: PremiumPageTransitionsBuilder(),
    TargetPlatform.linux: PremiumPageTransitionsBuilder(),
  }),

  extensions: const <ThemeExtension<dynamic>>[AppGlass.lightTokens],
);
