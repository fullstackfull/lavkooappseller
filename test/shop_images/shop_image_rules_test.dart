import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/splash/domain/models/config_model.dart';
import 'package:syriacosmeticsmanger/utill/shop_image_rules.dart';

/// What the two seller forms tell a seller about each image they ask for, as they told it on main (d556fb4), before the
/// rules were moved out of the widget trees. A seller on a Saudi shop must read exactly this after the move.
///
/// Registration (info_field_widget.dart): the profile image and the shop logo say `image_ratio`, the shop banner and
/// the secondary banner say `image_ratio3`, and all four say `image_size_2_mb`. The secondary banner is asked for, and
/// required (registration_screen.dart), while the config's active theme is not `default`.
///
/// The shop form (shop_update_screen.dart): the logo says `jpg_png_less_then_1_mb` and `ratio_1_1`, the cover the same
/// size and `ratio_4_1`; the secondary banner says `image_size` and the written `(3:1)` and is asked for on
/// `theme_aster` only; the offer banner says `image_size` and the written `(7:1)` and is asked for on `theme_fashion`
/// only.
const List<String?> _everyThemeTheConfigCanHold = <String?>[
  'theme_aster',
  'theme_fashion',
  'default',
  'a_theme_the_app_has_never_heard_of',
  '',
  null,
];

const List<String> _languages = <String>['en', 'ar'];

ConfigModel _configOfTheme(String? activeTheme) => ConfigModel()..activeTheme = activeTheme;

Map<String, dynamic> _languageFile(String code) =>
    jsonDecode(File('assets/language/$code.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('the images each form asks a seller for', () {
    test('registration asks for four slots and the shop form for four', () {
      expect(ShopImageRules.registrationSlots, <ShopImageSlot>[
        ShopImageSlot.profileImage,
        ShopImageSlot.logo,
        ShopImageSlot.banner,
        ShopImageSlot.secondaryBanner,
      ]);
      expect(ShopImageRules.shopUpdateSlots, <ShopImageSlot>[
        ShopImageSlot.logo,
        ShopImageSlot.banner,
        ShopImageSlot.secondaryBanner,
        ShopImageSlot.offerBanner,
      ]);
    });

    test('a form asked for an image it never asks for names the slot it was asked for', () {
      expect(
        () => ShopImageRules.inRegistration(ShopImageSlot.offerBanner),
        throwsA(isA<ArgumentError>()
            .having((ArgumentError refusal) => refusal.invalidValue, 'invalidValue', ShopImageSlot.offerBanner)
            .having((ArgumentError refusal) => refusal.message, 'message', contains('registration'))),
      );
      expect(
        () => ShopImageRules.inShopUpdate(ShopImageSlot.profileImage),
        throwsA(isA<ArgumentError>()
            .having((ArgumentError refusal) => refusal.invalidValue, 'invalidValue', ShopImageSlot.profileImage)
            .having((ArgumentError refusal) => refusal.message, 'message', contains('shop form'))),
      );
    });
  });

  group('the ratio and the size each slot states', () {
    test('registration states a translated ratio and a 2 MB limit for all four of its slots', () {
      expect(ShopImageRules.inRegistration(ShopImageSlot.profileImage).ratioLabelKey, 'image_ratio');
      expect(ShopImageRules.inRegistration(ShopImageSlot.logo).ratioLabelKey, 'image_ratio');
      expect(ShopImageRules.inRegistration(ShopImageSlot.banner).ratioLabelKey, 'image_ratio3');
      expect(ShopImageRules.inRegistration(ShopImageSlot.secondaryBanner).ratioLabelKey, 'image_ratio3');

      for (final ShopImageSlot slot in ShopImageRules.registrationSlots) {
        expect(ShopImageRules.inRegistration(slot).sizeLabelKey, 'image_size_2_mb', reason: '$slot');
        expect(ShopImageRules.inRegistration(slot).ratioLabel, isNull, reason: '$slot');
      }
    });

    test('the shop form states a translated ratio and a 1 MB limit for the logo and the cover', () {
      expect(ShopImageRules.inShopUpdate(ShopImageSlot.logo).ratioLabelKey, 'ratio_1_1');
      expect(ShopImageRules.inShopUpdate(ShopImageSlot.logo).sizeLabelKey, 'jpg_png_less_then_1_mb');
      expect(ShopImageRules.inShopUpdate(ShopImageSlot.logo).ratioLabel, isNull);

      expect(ShopImageRules.inShopUpdate(ShopImageSlot.banner).ratioLabelKey, 'ratio_4_1');
      expect(ShopImageRules.inShopUpdate(ShopImageSlot.banner).sizeLabelKey, 'jpg_png_less_then_1_mb');
      expect(ShopImageRules.inShopUpdate(ShopImageSlot.banner).ratioLabel, isNull);
    });

    test('the shop form writes the ratio of its two extra banners out, and translates only the size', () {
      expect(ShopImageRules.inShopUpdate(ShopImageSlot.secondaryBanner).ratioLabel, '(3:1)');
      expect(ShopImageRules.inShopUpdate(ShopImageSlot.secondaryBanner).ratioLabelKey, isNull);
      expect(ShopImageRules.inShopUpdate(ShopImageSlot.secondaryBanner).sizeLabelKey, 'image_size');

      expect(ShopImageRules.inShopUpdate(ShopImageSlot.offerBanner).ratioLabel, '(7:1)');
      expect(ShopImageRules.inShopUpdate(ShopImageSlot.offerBanner).ratioLabelKey, isNull);
      expect(ShopImageRules.inShopUpdate(ShopImageSlot.offerBanner).sizeLabelKey, 'image_size');
    });

    test('the two forms still disagree about the shop banner, 3:1 against 4:1, as they did before', () {
      expect(ShopImageRules.inRegistration(ShopImageSlot.banner).ratioLabelKey, 'image_ratio3');
      expect(ShopImageRules.inShopUpdate(ShopImageSlot.banner).ratioLabelKey, 'ratio_4_1');
    });

    test('every key a form states is in both language files', () {
      final Map<String, Map<String, dynamic>> languages = <String, Map<String, dynamic>>{
        for (final String code in _languages) code: _languageFile(code),
      };

      final List<ShopImageRule> rules = <ShopImageRule>[
        for (final ShopImageSlot slot in ShopImageRules.registrationSlots) ShopImageRules.inRegistration(slot),
        for (final ShopImageSlot slot in ShopImageRules.shopUpdateSlots) ShopImageRules.inShopUpdate(slot),
      ];

      expect(rules, hasLength(8));

      for (final ShopImageRule rule in rules) {
        for (final String code in _languages) {
          expect(languages[code]!.containsKey(rule.sizeLabelKey), isTrue, reason: '$code: ${rule.sizeLabelKey}');
          if (rule.ratioLabelKey != null) {
            expect(languages[code]!.containsKey(rule.ratioLabelKey), isTrue, reason: '$code: ${rule.ratioLabelKey}');
          }
        }
      }
    });
  });

  group('the storefronts a slot is asked on', () {
    test('registration asks for the profile image, the logo and the banner whatever the config holds', () {
      for (final String? theme in _everyThemeTheConfigCanHold) {
        for (final ShopImageSlot slot in <ShopImageSlot>[
          ShopImageSlot.profileImage,
          ShopImageSlot.logo,
          ShopImageSlot.banner,
        ]) {
          expect(ShopImageRules.inRegistration(slot).isAskedOf(_configOfTheme(theme)), isTrue, reason: '$slot: $theme');
        }
      }
    });

    test('registration asks for the secondary banner on every theme but the default one', () {
      bool asked(String? theme) =>
          ShopImageRules.inRegistration(ShopImageSlot.secondaryBanner).isAskedOf(_configOfTheme(theme));

      expect(asked('theme_aster'), isTrue);
      expect(asked('theme_fashion'), isTrue);
      expect(asked('a_theme_the_app_has_never_heard_of'), isTrue);
      expect(asked(''), isTrue);
      expect(asked(null), isTrue);
      expect(asked('default'), isFalse);
    });

    test('the shop form asks for the logo and the cover whatever the config holds', () {
      for (final String? theme in _everyThemeTheConfigCanHold) {
        for (final ShopImageSlot slot in <ShopImageSlot>[ShopImageSlot.logo, ShopImageSlot.banner]) {
          expect(ShopImageRules.inShopUpdate(slot).isAskedOf(_configOfTheme(theme)), isTrue, reason: '$slot: $theme');
        }
      }
    });

    test('the shop form asks for the secondary banner on theme_aster and on nothing else', () {
      bool asked(String? theme) =>
          ShopImageRules.inShopUpdate(ShopImageSlot.secondaryBanner).isAskedOf(_configOfTheme(theme));

      expect(asked('theme_aster'), isTrue);
      expect(asked('theme_fashion'), isFalse);
      expect(asked('default'), isFalse);
      expect(asked('a_theme_the_app_has_never_heard_of'), isFalse);
      expect(asked(''), isFalse);
      expect(asked(null), isFalse);
    });

    test('the shop form asks for the offer banner on theme_fashion and on nothing else', () {
      bool asked(String? theme) =>
          ShopImageRules.inShopUpdate(ShopImageSlot.offerBanner).isAskedOf(_configOfTheme(theme));

      expect(asked('theme_fashion'), isTrue);
      expect(asked('theme_aster'), isFalse);
      expect(asked('default'), isFalse);
      expect(asked('a_theme_the_app_has_never_heard_of'), isFalse);
      expect(asked(''), isFalse);
      expect(asked(null), isFalse);
    });

    test('a config the app has not loaded yet is read as a config that names no theme', () {
      expect(ShopImageRules.inShopUpdate(ShopImageSlot.secondaryBanner).isAskedOf(null), isFalse);
      expect(ShopImageRules.inShopUpdate(ShopImageSlot.offerBanner).isAskedOf(null), isFalse);
      expect(ShopImageRules.inShopUpdate(ShopImageSlot.logo).isAskedOf(null), isTrue);
      expect(ShopImageRules.inRegistration(ShopImageSlot.secondaryBanner).isAskedOf(null), isTrue);
    });
  });
}
