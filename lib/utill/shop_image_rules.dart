import 'package:syriacosmeticsmanger/features/splash/domain/models/config_model.dart';

/// An image a seller is asked for. The two forms that ask for shop images, registration and the shop form, name their
/// own slots from this list.
enum ShopImageSlot {
  profileImage,
  logo,
  banner,
  secondaryBanner,
  offerBanner,
}

/// The storefronts a slot is asked on.
///
/// Today the backend serves one theme to the whole platform, so the answer is read from the config the app already
/// holds. Once a theme is served per country (GCC-07) that value stops being single, and this class is the only place
/// in the app that has to be told where a seller's theme comes from. The seller's own bundled light and dark theme is
/// a different thing and is untouched by it; the scope of the seller app's theme is owner decision R-117, still open.
class ShopImageAudience {
  const ShopImageAudience.everyStorefront()
      : _themes = const <String>{},
        _asksWhenNamed = false;

  const ShopImageAudience.themes(this._themes) : _asksWhenNamed = true;

  const ShopImageAudience.everyStorefrontExcept(this._themes) : _asksWhenNamed = false;

  final Set<String> _themes;
  final bool _asksWhenNamed;

  bool asks(String? activeTheme) => _themes.contains(activeTheme) == _asksWhenNamed;
}

/// What a form tells a seller about one slot: the ratio it wants, the file size it allows, and the storefronts it is
/// asked on.
///
/// A form that translates the ratio carries [ratioLabelKey]. The two extra banners of the shop form write the ratio the
/// same way in every language and carry [ratioLabel] instead. [sizeLabelKey] is always a translation key.
class ShopImageRule {
  const ShopImageRule.translatedRatio({
    required String this.ratioLabelKey,
    required this.sizeLabelKey,
    this.audience = const ShopImageAudience.everyStorefront(),
  }) : ratioLabel = null;

  const ShopImageRule.writtenRatio({
    required String this.ratioLabel,
    required this.sizeLabelKey,
    this.audience = const ShopImageAudience.everyStorefront(),
  }) : ratioLabelKey = null;

  final String? ratioLabelKey;
  final String? ratioLabel;
  final String sizeLabelKey;
  final ShopImageAudience audience;

  bool isAskedOf(ConfigModel? config) => audience.asks(config?.activeTheme);
}

/// The image rules of the two seller forms, keyed by image slot. A form reads its rule from here, so that a ratio, a
/// size and the storefronts a slot is asked on are stated once, in one table, and no widget tree decides one for
/// itself.
///
/// The two forms disagree about the shop banner: registration states a ratio of 3:1 for it and the shop form 4:1. The
/// disagreement is theirs and is kept as it is; this table only moves it out of the widget trees, where it was invisible.
class ShopImageRules {
  const ShopImageRules._();

  static const Map<ShopImageSlot, ShopImageRule> _registration = <ShopImageSlot, ShopImageRule>{
    ShopImageSlot.profileImage: ShopImageRule.translatedRatio(
      ratioLabelKey: 'image_ratio',
      sizeLabelKey: 'image_size_2_mb',
    ),
    ShopImageSlot.logo: ShopImageRule.translatedRatio(
      ratioLabelKey: 'image_ratio',
      sizeLabelKey: 'image_size_2_mb',
    ),
    ShopImageSlot.banner: ShopImageRule.translatedRatio(
      ratioLabelKey: 'image_ratio3',
      sizeLabelKey: 'image_size_2_mb',
    ),
    ShopImageSlot.secondaryBanner: ShopImageRule.translatedRatio(
      ratioLabelKey: 'image_ratio3',
      sizeLabelKey: 'image_size_2_mb',
      audience: ShopImageAudience.everyStorefrontExcept(<String>{'default'}),
    ),
  };

  static const Map<ShopImageSlot, ShopImageRule> _shopUpdate = <ShopImageSlot, ShopImageRule>{
    ShopImageSlot.logo: ShopImageRule.translatedRatio(
      ratioLabelKey: 'ratio_1_1',
      sizeLabelKey: 'jpg_png_less_then_1_mb',
    ),
    ShopImageSlot.banner: ShopImageRule.translatedRatio(
      ratioLabelKey: 'ratio_4_1',
      sizeLabelKey: 'jpg_png_less_then_1_mb',
    ),
    ShopImageSlot.secondaryBanner: ShopImageRule.writtenRatio(
      ratioLabel: '(3:1)',
      sizeLabelKey: 'image_size',
      audience: ShopImageAudience.themes(<String>{'theme_aster'}),
    ),
    ShopImageSlot.offerBanner: ShopImageRule.writtenRatio(
      ratioLabel: '(7:1)',
      sizeLabelKey: 'image_size',
      audience: ShopImageAudience.themes(<String>{'theme_fashion'}),
    ),
  };

  static ShopImageRule inRegistration(ShopImageSlot slot) => _registration[slot]!;

  static ShopImageRule inShopUpdate(ShopImageSlot slot) => _shopUpdate[slot]!;

  static Iterable<ShopImageSlot> get registrationSlots => _registration.keys;

  static Iterable<ShopImageSlot> get shopUpdateSlots => _shopUpdate.keys;
}
