import 'package:flutter/foundation.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/platform_default_market.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/seller_market_grant.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/platform_default_market_source.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/seller_principal_source.dart';
import 'package:syriacosmeticsmanger/features/storefront/seller_market_choice.dart';

/// What happens once the seller works in another market: what belonged to the market left is dropped, and what belongs to the
/// market entered is loaded.
typedef MarketSwitchHandler = Future<void> Function();

/// The market the seller works in, and the one way to change it.
class SellerMarketController extends ChangeNotifier {
  SellerMarketController({
    required SellerMarketChoice marketChoice,
    required MarketSwitchHandler onMarketSwitched,
    SellerPrincipalSource? principalSource,
    PlatformDefaultMarketSource? defaultMarketSource,
  })  : _marketChoice = marketChoice,
        _onMarketSwitched = onMarketSwitched,
        _principalSource = principalSource,
        _defaultMarketSource = defaultMarketSource;

  final SellerMarketChoice _marketChoice;
  final MarketSwitchHandler _onMarketSwitched;
  final SellerPrincipalSource? _principalSource;
  final PlatformDefaultMarketSource? _defaultMarketSource;
  Future<void>? _lastHandled;
  SellerMarketGrant _grant = const SellerMarketGrant.unrestricted();

  /// The market the seller works in, which is the choice the device holds and nothing else. There is one controller for the whole app
  /// and it outlives a sign-out, while the choice does not: holding the market apart from the device would label the screens with the
  /// market of the seller who signed out, and the requests of those screens name the stored choice.
  MarketScope get market => _marketChoice.current();

  SellerMarketGrant get grant => _grant;

  /// The markets to offer: the markets the token carries, and every GCC market while it carries no grant — which is what the app
  /// has always offered. Narrowing the list keeps a seller from picking a market the server would refuse; it is not what stops
  /// them reaching it.
  List<MarketScope> get markets => _grant.narrow(MarketScope.gccMarkets);

  /// Asks the server for the markets this token carries, and takes the answer. A build with no source never asks and stays
  /// unrestricted, which is the app as it was before markets existed.
  Future<void> refreshGrant() async {
    final SellerPrincipalSource? source = _principalSource;
    if (source == null) {
      return;
    }

    await applyGrant(await source.grant());
  }

  /// Asks the server which market the platform serves whoever has chosen none, and remembers the answer, so that moving the default on
  /// the server moves a seller who has chosen no market (A1-03). A seller who has chosen one is not moved and nothing notifies: their
  /// choice outranks the default and always did. A build with no source never asks.
  Future<void> refreshPlatformDefault() async {
    final PlatformDefaultMarketSource? source = _defaultMarketSource;
    if (source == null) {
      return;
    }

    final PlatformDefaultMarket answer = await source.defaultMarket();
    if (!answer.answered) {
      return;
    }

    final MarketScope marketBefore = market;
    await _marketChoice.rememberPlatformDefault(answer.market);

    if (market != marketBefore) {
      notifyListeners();
    }
  }

  /// Takes the grant the server answered. A seller working in a market the grant does not hold is moved to the first market it
  /// does, and the screens are reloaded for it, because leaving them on a market every request will be refused in would show a
  /// seller an empty app with no reason given. A grant that holds nothing moves nobody: there is nowhere to move to.
  Future<void> applyGrant(SellerMarketGrant grant) async {
    _grant = grant;

    if (grant.allows(market)) {
      notifyListeners();
      return;
    }

    final List<MarketScope> granted = markets;
    if (granted.isEmpty) {
      notifyListeners();
      return;
    }

    await choose(granted.first);
    notifyListeners();
  }

  /// Saves [scope] as the market to work in. Moving to another market tells the screens and then hands over to the switch handler,
  /// which starts only once the handler of the switch before it has finished; choosing the market already worked in changes nothing
  /// but the saved choice. False when the market could not be saved.
  Future<bool> choose(MarketScope scope) async {
    // A market the token does not carry is not saved: the server refuses every request for it anyway, and saving it would leave
    // the app working in a market whose every screen answers 403.
    if (!_grant.allows(scope)) {
      return false;
    }

    final MarketScope marketLeft = market;
    if (!await _marketChoice.choose(scope)) {
      return false;
    }
    if (scope == marketLeft) {
      return true;
    }

    notifyListeners();
    await _handleSwitch();
    return true;
  }

  /// One switch is handled at a time, in the order the markets were chosen, so that what the handler of an older market loads can never
  /// land after, and over, what the handler of the newer market loaded. A handler that fails does not stop the ones behind it.
  Future<void> _handleSwitch() {
    final Future<void>? previous = _lastHandled;
    final Future<void> handled = previous == null ? _onMarketSwitched() : previous.then((_) => _onMarketSwitched());
    _lastHandled = handled.then((_) {}, onError: (Object _) {});
    return handled;
  }
}
