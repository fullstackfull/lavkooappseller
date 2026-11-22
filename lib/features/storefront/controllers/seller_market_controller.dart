import 'package:flutter/foundation.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/seller_market_choice.dart';

/// What happens once the seller works in another market: what belonged to the market left is dropped, and what belongs to the
/// market entered is loaded.
typedef MarketSwitchHandler = Future<void> Function();

/// The market the seller works in, and the one way to change it.
class SellerMarketController extends ChangeNotifier {
  SellerMarketController({
    required SellerMarketChoice marketChoice,
    required MarketSwitchHandler onMarketSwitched,
  })  : _marketChoice = marketChoice,
        _onMarketSwitched = onMarketSwitched,
        _market = marketChoice.current();

  final SellerMarketChoice _marketChoice;
  final MarketSwitchHandler _onMarketSwitched;
  MarketScope _market;
  Future<void>? _lastHandled;

  MarketScope get market => _market;

  List<MarketScope> get markets => MarketScope.gccMarkets;

  /// Saves [scope] as the market to work in. Moving to another market tells the screens and then hands over to the switch handler,
  /// which starts only once the handler of the switch before it has finished; choosing the market already worked in changes nothing
  /// but the saved choice. False when the market could not be saved.
  Future<bool> choose(MarketScope scope) async {
    if (!await _marketChoice.choose(scope)) {
      return false;
    }
    if (scope == _market) {
      return true;
    }

    _market = scope;
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
