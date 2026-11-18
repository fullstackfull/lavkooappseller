import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/features/auth/controllers/auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/outbox_policy.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/pending_pos_order.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/pos_idempotency_key.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/pos_order_answer.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/services/cart_service_interface.dart';

/// Outbox for POS sales made while the device was offline.
///
/// A sale rung up without connectivity is written to disk immediately and
/// replayed automatically as soon as the network comes back, so an outage
/// never loses a sale and never leaves the cashier guessing.
class OfflineSalesController extends ChangeNotifier {
  final CartServiceInterface cartServiceInterface;
  final SharedPreferences sharedPreferences;

  /// Whether there is a session to replay sales under. The app reads it from the signed-in seller; a test says it.
  final bool Function()? _hasSessionOverride;

  OfflineSalesController({required this.cartServiceInterface, required this.sharedPreferences, bool Function()? hasSession}) : _hasSessionOverride = hasSession;

  static const String _storageKey = 'offline_pos_orders';

  /// The last error of a sale that the server refused without saying why; the sheet shows a general message for it.
  static const String refusedWithoutReason = 'sale_refused';

  List<PendingPosOrder> _pending = <PendingPosOrder>[];
  List<PendingPosOrder> get pending => List.unmodifiable(_pending);

  int get pendingCount => _pending.length;
  bool get hasPending => _pending.isNotEmpty;

  /// The sales that have used their attempts: kept, shown to the seller with their last error, and retried or removed by the seller (OutboxPolicy).
  List<PendingPosOrder> get failedSales => OutboxPolicy.failedAmong(_pending);
  int get failedCount => failedSales.length;

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

  /// Reads the queue from the disk, which [initialise] does together with the watch on the connection.
  @visibleForTesting
  void loadFromStorage() => _load();

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
    String? idempotencyKey,
  }) async {
    final PendingPosOrder order = PendingPosOrder(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      body: orderBody,
      createdAt: DateTime.now(),
      orderAmount: orderAmount,
      customerName: customerName,
      idempotencyKey: idempotencyKey ?? PosIdempotencyKey.generate(),
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
    final bool Function()? override = _hasSessionOverride;
    if (override != null) {
      return override();
    }

    final BuildContext? context = Get.context;
    if (context == null) {
      return false;
    }

    return Provider.of<AuthController>(context, listen: false).isLoggedIn();
  }

  /// Replays every queued sale that is still replayed by itself. A sale that fails stays queued with its attempt count bumped and its last error; once it has used its attempts (OutboxPolicy)
  /// it is not replayed again by the return of the connection, and it is not dropped either: it waits for the seller, so a permanently rejected sale never blocks the ones behind it and is never lost silently.
  Future<int> syncPending() async {
    if (_isSyncing || _pending.isEmpty) return 0;

    // A queued sale belongs to the session that took it. The queue outlives a
    // sign-out — it has its own storage key — so without this a returning
    // connection replayed every pending order with no credential, ten times
    // each, and the seller was not even signed in to see it fail.
    if (!_hasSession()) return 0;

    _isSyncing = true;
    notifyListeners();

    // A sale an earlier version queued has no key yet. It is given one before it is sent and the key is stored first, so that a replay whose answer is lost is replayed under the same key.
    if (_pending.any((PendingPosOrder order) => order.idempotencyKey == null)) {
      _pending = _pending.map((PendingPosOrder order) => order.idempotencyKey == null ? order.copyWith(idempotencyKey: PosIdempotencyKey.generate()) : order).toList();
      await _persist();
    }

    int synced = 0;
    final Set<String> syncedIds = <String>{};
    final Map<String, PendingPosOrder> replayed = <String, PendingPosOrder>{};

    // The loop walks the sales the queue held when it began; a sale is replayed, not removed, until the whole pass is over.
    for (final PendingPosOrder order in List<PendingPosOrder>.of(_pending)) {
      if (!OutboxPolicy.isReplayedAutomatically(order)) {
        continue;
      }

      try {
        final dynamic response = await cartServiceInterface.placeOrderRaw(order.body, idempotencyKey: order.idempotencyKey);
        final int? statusCode = response?.response?.statusCode as int?;
        if (statusCode == 200) {
          if (PosOrderAnswer.isPlaced(response?.response?.data)) {
            synced++;
            syncedIds.add(order.id);
            continue;
          }

          // The server answered but refused the sale (a product that is not available): nothing was recorded, so it is not synced. It fails like any other replay, with the reason.
          replayed[order.id] = order.copyWith(attempts: order.attempts + 1, lastError: PosOrderAnswer.refusalMessage(response?.response?.data) ?? refusedWithoutReason);
          continue;
        }
        // A rejected session is not a reason to burn an attempt: the sale is
        // still good, and it will go through once the seller signs back in.
        if (statusCode == 401) {
          continue;
        }

        replayed[order.id] = order.copyWith(attempts: order.attempts + 1, lastError: response?.error?.toString());
      } catch (e) {
        replayed[order.id] = order.copyWith(attempts: order.attempts + 1, lastError: e.toString());
      }
    }

    // The replay takes as long as the network does, and the seller goes on selling: a sale queued meanwhile, a failed sale removed, the failed sales reopened. The queue is rebuilt from what it
    // holds now, with only the outcome of this pass applied to it; assigning the list the pass began with would drop a sale that was queued while it ran.
    _pending = _pending.where((PendingPosOrder order) => !syncedIds.contains(order.id)).map((PendingPosOrder order) => replayed[order.id] ?? order).toList();
    await _persist();

    _isSyncing = false;
    _lastSyncMessage = synced > 0 ? 'sales_synced' : null;
    notifyListeners();
    return synced;
  }

  /// The seller asks for the sales that could not be sent to be tried again: each is given its attempts back and the queue is replayed.
  Future<int> retryFailedSales() async {
    _pending = OutboxPolicy.withFailedSalesReopened(_pending);
    await _persist();
    notifyListeners();

    return syncPending();
  }

  Future<void> clear() async {
    _pending = <PendingPosOrder>[];
    await _persist();
    notifyListeners();
  }
}
