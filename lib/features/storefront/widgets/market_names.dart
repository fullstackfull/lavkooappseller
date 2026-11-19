import 'package:flutter/widgets.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';

/// The names of the markets in the language the seller reads.
abstract final class MarketNames {
  /// All Markets has no name to show: it is a way of looking, not a market to work in.
  static String? of(MarketScope scope, BuildContext context) => switch (scope) {
        MarketScope.allMarkets => null,
        MarketScope.saudiArabia => getTranslated('market_saudi_arabia', context),
        MarketScope.unitedArabEmirates => getTranslated('market_united_arab_emirates', context),
        MarketScope.kuwait => getTranslated('market_kuwait', context),
        MarketScope.qatar => getTranslated('market_qatar', context),
        MarketScope.bahrain => getTranslated('market_bahrain', context),
        MarketScope.oman => getTranslated('market_oman', context),
      };
}
