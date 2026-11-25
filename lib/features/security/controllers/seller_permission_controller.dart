import 'package:flutter/foundation.dart';
import 'package:syriacosmeticsmanger/features/security/domain/models/seller_permission_scope.dart';
import 'package:syriacosmeticsmanger/features/security/domain/seller_permission_source.dart';
import 'package:syriacosmeticsmanger/features/security/seller_permission_config.dart';

/// What the signed-in role may use, held once for the whole app (K-08).
///
/// A staff member whose role grants two permissions used to meet the app of an owner and a 403 toast behind every third entry of
/// it. The entries a role cannot use are now left out of the screen instead, which is a courtesy and not a boundary: the server
/// refuses the same requests it always refused.
class SellerPermissionController extends ChangeNotifier {
  SellerPermissionController({SellerPermissionSource? source, bool enabled = SellerPermissionConfig.enabled})
      : _source = source,
        _enabled = enabled;

  final SellerPermissionSource? _source;
  final bool _enabled;
  SellerPermissionScope _scope = const SellerPermissionScope.unrestricted();

  SellerPermissionScope get scope => _scope;

  /// Asks the server who is signed in and takes the answer. A build whose role screens are off, and a container with no client,
  /// ask nothing and stay unrestricted, which is the app as it was before roles reached the screens.
  Future<void> refresh() async {
    final SellerPermissionSource? source = _source;
    if (!_enabled || source == null) {
      return;
    }

    apply(await source.scope());
  }

  /// Takes [scope] and tells the screens. Signing out hands back [SellerPermissionScope.unrestricted], so the next seller to use
  /// the phone is never shown the screens of the role that signed out.
  void apply(SellerPermissionScope scope) {
    _scope = scope;
    notifyListeners();
  }
}
