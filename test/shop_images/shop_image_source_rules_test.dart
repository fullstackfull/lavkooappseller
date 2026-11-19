import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/utill/shop_image_rules.dart';

/// The two forms that ask a seller for shop images, and the screen that refuses a registration without one.
const String _registrationFormPath = 'lib/features/auth/widgets/info_field_widget.dart';
const String _registrationScreenPath = 'lib/features/auth/screens/registration_screen.dart';
const String _shopFormPath = 'lib/features/shop/screens/shop_update_screen.dart';

/// Each slot of a form, as the block of the form that asks for it: from the label of the slot to the label of the next.
const Map<ShopImageSlot, List<String>> _registrationBlocks = <ShopImageSlot, List<String>>{
  ShopImageSlot.profileImage: <String>["getTranslated('store_logo'", "getTranslated('store_image'"],
  ShopImageSlot.logo: <String>["getTranslated('store_image'", "getTranslated('store_banner'"],
  ShopImageSlot.banner: <String>["getTranslated('store_banner'", 'activeTheme != "default"'],
  ShopImageSlot.secondaryBanner: <String>['activeTheme != "default"', ''],
};

const Map<ShopImageSlot, List<String>> _shopFormBlocks = <ShopImageSlot, List<String>>{
  ShopImageSlot.logo: <String>["getTranslated('shop_logo'", "getTranslated('shop_cover'"],
  ShopImageSlot.banner: <String>["getTranslated('shop_cover'", 'activeTheme == "theme_aster"'],
  ShopImageSlot.secondaryBanner: <String>['activeTheme == "theme_aster"', 'activeTheme == "theme_fashion"'],
  ShopImageSlot.offerBanner: <String>['activeTheme == "theme_fashion"', ''],
};

String _read(String path) => File(path).readAsStringSync();

/// The part of [source] that asks for one slot: from [anchors] first to [anchors] last, the last being the end of the
/// file when it is empty.
String _blockOf(String source, List<String> anchors) {
  final int start = source.indexOf(anchors.first);
  expect(start, isNonNegative, reason: 'the block does not start: ${anchors.first}');

  if (anchors.last.isEmpty) {
    return source.substring(start);
  }

  final int end = source.indexOf(anchors.last, start + anchors.first.length);
  expect(end, greaterThan(start), reason: 'the block does not end: ${anchors.last}');
  return source.substring(start, end);
}

/// Every ratio and size a slot of either form can state, so that a block can be asked for the ones that are not its own.
const List<String> _everyRuleText = <String>[
  "'image_ratio'",
  "'image_ratio3'",
  "'ratio_1_1'",
  "'ratio_4_1'",
  "'image_size'",
  "'image_size_2_mb'",
  "'jpg_png_less_then_1_mb'",
  "'(3:1)'",
  "'(7:1)'",
];

/// The ratio and the size [rule] states, written as the form writes them.
List<String> _ruleTextsOf(ShopImageRule rule) => <String>[
      if (rule.ratioLabelKey != null) "'${rule.ratioLabelKey}'",
      if (rule.ratioLabel != null) "'${rule.ratioLabel}'",
      "'${rule.sizeLabelKey}'",
    ];

void main() {
  group('the table states what the two forms state today', () {
    test('each slot of registration states the ratio and the size the table holds for it, and no other', () {
      final String source = _read(_registrationFormPath);

      for (final MapEntry<ShopImageSlot, List<String>> block in _registrationBlocks.entries) {
        final String asked = _blockOf(source, block.value);
        final List<String> own = _ruleTextsOf(ShopImageRules.inRegistration(block.key));

        for (final String text in own) {
          expect(asked, contains(text), reason: '${block.key} does not state $text');
        }
        for (final String text in _everyRuleText.where((String text) => !own.contains(text))) {
          expect(asked, isNot(contains(text)), reason: '${block.key} also states $text');
        }
      }
    });

    test('each slot of the shop form states the ratio and the size the table holds for it, and no other', () {
      final String source = _read(_shopFormPath);

      for (final MapEntry<ShopImageSlot, List<String>> block in _shopFormBlocks.entries) {
        final String asked = _blockOf(source, block.value);
        final List<String> own = _ruleTextsOf(ShopImageRules.inShopUpdate(block.key));

        for (final String text in own) {
          expect(asked, contains(text), reason: '${block.key} does not state $text');
        }
        for (final String text in _everyRuleText.where((String text) => !own.contains(text))) {
          expect(asked, isNot(contains(text)), reason: '${block.key} also states $text');
        }
      }
    });
  });

  group('the storefronts each form asks a slot on', () {
    test('the shop form offers its two extra banners on the themes the table names', () {
      final String source = _read(_shopFormPath);

      expect(
        source,
        contains('if(Provider.of<SplashController>(context, listen: false).configModel?.activeTheme == "theme_aster")'),
      );
      expect(
        source,
        contains(
            'if(Provider.of<SplashController>(context, listen: false).configModel?.activeTheme == "theme_fashion")'),
      );
    });

    test('registration offers its secondary banner on every theme but the default one', () {
      expect(
        _read(_registrationFormPath),
        contains('Provider.of<SplashController>(context,listen: false).configModel!.activeTheme != "default" ?'),
      );
    });

    test('registration refuses a registration without the secondary banner on the same themes', () {
      expect(
        _read(_registrationScreenPath),
        contains('authController.secondaryBanner == null && '
            'Provider.of<SplashController>(context,listen: false).configModel!.activeTheme != "default"'),
      );
    });
  });
}
