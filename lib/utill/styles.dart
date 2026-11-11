import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/theme/app_glass.dart';
import 'package:syriacosmeticsmanger/theme/light_theme.dart' show kAppFontFamily;
import 'package:syriacosmeticsmanger/utill/dimensions.dart';

const titilliumRegular = TextStyle(
  fontFamily: kAppFontFamily,
  fontWeight: FontWeight.w400,
  fontSize: Dimensions.fontSizeDefault,
);


const titilliumSemiBold = TextStyle(
  fontFamily: kAppFontFamily,
  fontSize: Dimensions.fontSizeLarge,
  fontWeight: FontWeight.w500,
);

const titilliumBold = TextStyle(
  fontFamily: kAppFontFamily,
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w600,
);
const titilliumItalic = TextStyle(
  fontFamily: kAppFontFamily,
  fontSize: Dimensions.fontSizeDefault,
  fontStyle: FontStyle.italic,
);

const robotoHintRegular = TextStyle(
    fontFamily: kAppFontFamily,
    fontWeight: FontWeight.w400,
    fontSize: Dimensions.fontSizeSmall,
    color: Colors.grey
);
const robotoRegular = TextStyle(
  fontFamily: kAppFontFamily,
  fontWeight: FontWeight.w400,
  fontSize: Dimensions.fontSizeDefault,
);
const robotoRegularMainHeadingAddProduct = TextStyle(
  fontFamily: kAppFontFamily,
  fontWeight: FontWeight.w400,
  fontSize: Dimensions.fontSizeDefault,
);

const robotoRegularForAddProductHeading = TextStyle(
  fontFamily: kAppFontFamily,
  color: Color(0xFF9D9D9D),
  fontWeight: FontWeight.w400,
  fontSize: Dimensions.fontSizeSmall,
);

const robotoTitleRegular = TextStyle(
  fontFamily: kAppFontFamily,
  fontWeight: FontWeight.w400,
  fontSize: Dimensions.fontSizeLarge,
);

const robotoSmallTitleRegular = TextStyle(
  fontFamily: kAppFontFamily,
  fontWeight: FontWeight.w400,
  fontSize: Dimensions.fontSizeSmall,
);

const robotoBold = TextStyle(
  fontFamily: kAppFontFamily,
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w600,
);

 const robotoMedium = TextStyle(
  fontFamily: kAppFontFamily,
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w500,
);


class ThemeShadow {
  static List<BoxShadow> getShadow(BuildContext context) => AppGlass.of(context).shadowSoft;
  static List<BoxShadow> getMediumShadow(BuildContext context) => AppGlass.of(context).shadowMedium;
  static List<BoxShadow> getStrongShadow(BuildContext context) => AppGlass.of(context).shadowStrong;
}

/// Shimmer placeholder colours that follow the active brightness, replacing the
/// hardcoded light-grey pair that glowed white in dark mode.
class ShimmerColors {
  static Color base(BuildContext context) => AppGlass.of(context).shimmerBase;
  static Color highlight(BuildContext context) => AppGlass.of(context).shimmerHighlight;
}
