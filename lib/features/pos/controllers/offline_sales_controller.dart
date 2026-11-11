import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/features/auth/controllers/auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/pending_pos_order.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/services/cart_service_interface.dart';

/// Outbox for POS sales made while the device was offline.
///
/// A sale rung up without connectivity is written to disk immediately and
/// replayed automatically as soon as the network comes back, so an outage
/// never loses a sale and never leaves the cashier guessing.
class OfflineSalesController extends ChangeNotifier {
  final CartServiceInterface cartServiceInterface;
  final SharedPreferences sharedPreferences;

  OfflineSalesController({required this.cartServiceInterface, required this.sharedPreferences});

  static const String _storageKey = 'offline_pos_orders';
  static const int _maxAttempts = 10;

  List<PendingPosOrder> _pending = <PendingPosOrder>[];
  List<PendingPosOrder> get pending => List.unmodifiable(_pending);

  int get pendingCount => _pending.length;
  bool get hasPending => _pending.isNotEmpty;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  String? _lastSyncMessage;
  String? get lastSyncMessage => _lastSyncMessage;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  /// Loads the outbox from disk and starts watching connectivity. Safe to call
  /// more than once.
  void initialise() {
    _load();
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final bool online = results.any((r) => r != ConnectivityResult.none);
      final bool cameBackOnline = online && !_isOnline;
      _isOnline = online;
      notifyListeners();
      if (cameBackOnline && hasPending) {
        syncPending();
      }
    });
  }

  void _load() {
    final List<String> raw = sharedPreferences.getStringList(_storageKey) ?? <String>[];
    _pending = raw.map(PendingPosOrder.decode).whereType<PendingPosOrder>().toList();
    notifyListeners();
  }

  Future<void> _persist() async {
    await sharedPreferences.setStringList(_storageKey, _pending.map((o) => o.encode()).toList());
  }

  /// Queues a sale that could not be sent. Returns the queued entry.
  Future<PendingPosOrder> enqueue({
    required Map<String, dynamic> orderBody,
    required double orderAmount,
    required String customerName,
  }) async {
    final PendingPosOrder order = PendingPosOrder(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      body: orderBody,
      createdAt: DateTime.now(),
      orderAmount: orderAmount,
      customerName: customerName,
    );
    _pending = [..._pending, order];
    await _persist();
    notifyListeners();
    return order;
  }

  Future<void> remove(String id) async {
    _pending = _pending.where((o) => o.id != id).toList();
    await _persist();
    notifyListeners();
  }

  /// Whether there is a session to replay these sales under.
  ///
  /// Before the first frame there is no navigator to read a provider from, and
  /// a sync that early has nothing to authenticate with anyway.
  bool _hasSession() {
    final BuildContext? context = Get.context;
    if (context == null) {
      return false;
    }

    return Provider.of<AuthController>(context, listen: false).isLoggedIn();
  }

  /// Replays every queued sale. Entries that fail stay queued (with the attempt
  /// count bumped) unless they have exhausted [_maxAttempts], which keeps a
  /// permanently rejected order from blocking the ones behind it forever.
  Future<int> syncPending() async {
    if (_isSyncing || _pending.isEmpty) return 0;

    // A queued sale belongs to the session that took it. The queue outlives a
    // sign-out — it has its own storage key — so without this a returning
    // connection replayed every pending order with no credential, ten times
    // each, and the seller was not even signed in to see it fail.
    if (!_hasSession()) return 0;

    _isSyncing = true;
    notifyListeners();

    int synced = 0;
    final List<PendingPosOrder> remaining = <PendingPosOrder>[];

    for (final PendingPosOrder order in _pending) {
      try {
        final dynamic response = await cartServiceInterface.placeOrderRaw(order.body);
        final int? statusCode = response?.response?.statusCode as int?;
        if (statusCode == 200) {
          synced++;
          continue;
        }
        // A rejected session is not a reason to burn an attempt: the sale is
        // still good, and it will go through once the seller signs back in.
        if (statusCode == 401) {
          remaining.add(order);
          continue;
        }

        final PendingPosOrder retried = order.copyWith(
          attempts: order.attempts + 1,
          lastError: response?.error?.toString(),
        );
        if (retried.attempts < _maxAttempts) remaining.add(retried);
      } catch (e) {
        final PendingPosOrder retried = order.copyWith(attempts: order.attempts + 1, lastError: e.toString());
        if (retried.attempts < _maxAttempts) remaining.add(retried);
      }
    }

    _pending = remaining;
    await _persist();

    _isSyncing = false;
    _lastSyncMessage = synced > 0 ? 'sales_synced' : null;
    notifyListeners();
    return synced;
  }

  Future<void> clear() async {
    _pending = <PendingPosOrder>[];
    await _persist();
    notifyListeners();
  }
}
