import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';

/// One market that has been stopped, as the server names it in the config answer (K-V4).
///
/// The platform has had ONE maintenance switch since it had one market, and that is what this app was told: `maintenance_mode`, with no
/// country in it. With six markets a seller whose market is stopped and a seller whose market is selling are told the same thing, and a
/// seller who works in both cannot tell which of them stopped -- the maintenance screen had no market in it at all.
///
/// The server sends this BESIDE the global block and never instead of it, keyed by country, because `/api/v1/config` deliberately resolves
/// no storefront of its own. A market that is selling is simply not in the map, and the whole key is absent while storefronts are off, so a
/// build that reads only the global block behaves exactly as before.
class StorefrontPause {
  const StorefrontPause({required this.country, required this.state, this.mode, this.message, this.until});

  /// The market's two-letter code, as the server writes it.
  final String country;

  /// What the market is: `paused` is the only state the server sends here.
  final String state;

  /// How it is stopped -- `maintenance`, `browse_only`, `redirect` -- or null when the server did not say.
  final String? mode;

  /// The text an operator wrote for whoever reads this screen, or null when they wrote none.
  final String? message;

  /// When the market is expected back, as the operator typed it, or null.
  final String? until;

  static StorefrontPause? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }

    final String country = (json['country'] ?? '').toString().trim().toUpperCase();
    final String state = (json['state'] ?? '').toString().trim();

    if (country.isEmpty || state.isEmpty) {
      return null;
    }

    return StorefrontPause(
      country: country,
      state: state,
      mode: _text(json['mode']),
      message: _text(json['message']),
      until: _text(json['until']),
    );
  }

  /// The markets the server says are stopped, by country code. An answer that carries no such key, or one this app cannot read, is no
  /// markets at all -- never an exception, because the config answer is what the app starts on.
  static Map<String, StorefrontPause> mapFromJson(Object? json) {
    if (json is! Map) {
      return const <String, StorefrontPause>{};
    }

    final Map<String, StorefrontPause> paused = <String, StorefrontPause>{};

    for (final Object? entry in json.values) {
      final StorefrontPause? pause = StorefrontPause.fromJson(entry);

      if (pause != null) {
        paused[pause.country] = pause;
      }
    }

    return paused;
  }

  static String? _text(Object? value) {
    final String text = (value ?? '').toString().trim();

    return text.isEmpty ? null : text;
  }
}

/// What the app asks about the markets that are stopped.
extension StorefrontPauseLookup on Map<String, StorefrontPause> {
  /// The stop of the market the seller is working in, or null when that market is selling, when the seller is on All Markets (which is no
  /// one market and so cannot be stopped), or when the server sent nothing.
  StorefrontPause? ofMarket(MarketScope? scope) {
    final String? code = scope?.countryCode;

    return code == null ? null : this[code];
  }
}
