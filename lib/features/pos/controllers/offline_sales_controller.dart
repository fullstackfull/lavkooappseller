import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/features/auth/controllers/auth_controller.dart';
import 'package:syriacosmeticsmanger/features/profile/controllers/profile_controller.dart';
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
///
/// The queue is one list on the device and it outlives a sign-out, so a sale carries the seller who took it: the server records a replayed sale under the seller of the session that sends it.
/// A seller's session lists, sends, retries and removes the sales of that seller, and the sales that have no seller; the sales of another seller stay queued until their seller signs in.
///
/// The app learns who is signed in from the profile: the id of the seller in its answer, which a sign-out forgets. Until the answer of the next session arrives, the sales of a seller are out of sight and
/// unsent, and a sale rung up in the meantime has no seller yet: it is given the seller of its own session when the answer comes. The answer needs a connection, so a sale rung up in a session that never
/// gets it keeps no seller, and when that session ends it is sent under whoever signs in next, as every sale was before.
class OfflineSalesController extends ChangeNotifier {
  final CartServiceInterface cartServiceInterface;
  final SharedPreferences sharedPreferences;

  /// Whether there is a session to replay sales under. The app reads it from the signed-in seller; a test says it.
  final bool Function()? _hasSessionOverride;

  /// The id of the seller who is signed in, or null while it is not known. The app reads it from the profile; a test says it.
  final String? Function()? _signedInSellerIdOverride;

  OfflineSalesController({required this.cartServiceInterface, required this.sharedPreferences, bool Function()? hasSession, String? Function()? signedInSellerId})
      : _hasSessionOverride = hasSession,
        _signedInSellerIdOverride = signedInSellerId;

  static const String _storageKey = 'offline_pos_orders';

  /// The last error of a sale that the server refused without saying why; the sheet shows a general message for it.
  static const String refusedWithoutReason = 'sale_refused';

  /// Every sale on the device, whoever took it.
  List<PendingPosOrder> _pending = <PendingPosOrder>[];

  /// The sales rung up while the app did not know who was signed in, each with the session it was rung up in: the seller of that session is given to it when the app learns who it is. A sale an earlier
  /// version queued is not among them.
  final Map<String, int> _awaitingSeller = <String, int>{};

  /// The profile of the app, once it has been found. The controller follows it, because its answer is what tells the app who is signed in.
  ProfileController? _profile;

  List<PendingPosOrder> get _ownSales {
    final String? sellerId = _signedInSellerId();

    return _pending.where((PendingPosOrder order) => order.belongsTo(sellerId)).toList();
  }

  /// The sales of the seller who is signed in. A sale another seller took is not listed, counted or shown as a failure here.
  List<PendingPosOrder> get pending => List.unmodifiable(_ownSales);

  int get pendingCount => _ownSales.length;
  bool get hasPending => _ownSales.isNotEmpty;

  /// The sales that have used their attempts: kept, shown to the seller with their last error, and retried or removed by the seller (OutboxPolicy).
  List<PendingPosOrder> get failedSales => OutboxPolicy.failedAmong(_ownSales);
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

  @override
  void dispose() {
    _profile?.removeListener(_sellerMayHaveChanged);
    super.dispose();
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
    final String? sellerId = _signedInSellerId();
    final PendingPosOrder order = PendingPosOrder(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      body: orderBody,
      createdAt: DateTime.now(),
      orderAmount: orderAmount,
      customerName: customerName,
      idempotencyKey: idempotencyKey ?? PosIdempotencyKey.generate(),
      sellerId: sellerId,
    );
    if (sellerId == null) {
      _awaitingSeller[order.id] = _sessionsEnded();
    }
    _pending = [..._pending, order];
    await _persist();
    notifyListeners();
    return order;
  }

  /// Removes a sale of the seller who is signed in; the id of a sale another seller took removes nothing.
  Future<void> remove(String id) async {
    final String? sellerId = _signedInSellerId();
    _pending = _pending.where((PendingPosOrder order) => order.id != id || !order.belongsTo(sellerId)).toList();
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

  /// The id of the seller who is signed in, or null while the app does not know it.
  ///
  /// The app keeps it only in the profile, which is fetched after the sign-in and which forgets it at a sign-out: before the answer of the new session arrives the seller is not known, and it is never
  /// the one who signed out.
  String? _signedInSellerId() {
    final String? Function()? override = _signedInSellerIdOverride;
    if (override != null) {
      return override();
    }

    return _followedProfile()?.userId?.toString();
  }

  /// The profile of the app, which the controller starts following the first time it is found: before the first frame there is no navigator to read a provider from.
  ProfileController? _followedProfile() {
    if (_profile == null) {
      final BuildContext? context = Get.context;
      if (context == null) {
        return null;
      }

      _profile = Provider.of<ProfileController>(context, listen: false)..addListener(_sellerMayHaveChanged);
    }

    return _profile;
  }

  void _sellerMayHaveChanged() {
    _giveSellerToSalesAwaitingIt();
    notifyListeners();
  }

  /// A sale rung up while the app did not know who was signed in is given the seller that the answer of its own session names. The seller is written on the sale and on the disk, so that a seller who signs
  /// in later does not take it for theirs; the answer of a later session names another seller and gives them none.
  void _giveSellerToSalesAwaitingIt() {
    final String? sellerId = _signedInSellerId();
    if (sellerId == null || _awaitingSeller.isEmpty) {
      return;
    }

    final int session = _sessionsEnded();
    _pending = _pending.map((PendingPosOrder order) => order.sellerId == null && _awaitingSeller[order.id] == session ? order.copyWith(sellerId: sellerId) : order).toList();
    _awaitingSeller.clear();
    _persist();
  }

  /// How many sessions had ended when this was asked, by the count of the profile; a test that says who is signed in has no profile and one session.
  int _sessionsEnded() => _followedProfile()?.sessionsEnded ?? 0;

  /// Replays every queued sale that is still replayed by itself. A sale that fails stays queued with its attempt count bumped and its last error; once it has used its attempts (OutboxPolicy)
  /// it is not replayed again by the return of the connection, and it is not dropped either: it waits for the seller, so a permanently rejected sale never blocks the ones behind it and is never lost silently.
  Future<int> syncPending() async {
    if (_isSyncing || !hasPending) return 0;

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
      // A sale another seller took stays queued, uncounted and unsent: sent now, the server would record it under this seller. The seller is asked again for each sale, because the replay takes
      // as long as the network does and another seller can sign in while it runs.
      if (!order.belongsTo(_signedInSellerId())) {
        continue;
      }

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

    // The replay takes as long as the network does, and the seller goes on selling: a sale queued meanwhile, a failed sale removed, the failed sales reopened, a sale given its seller. The queue is
    // rebuilt from what it holds now, with only the outcome of this pass applied to it; assigning the list the pass began with would drop a sale that was queued while it ran.
    _pending = _pending.where((PendingPosOrder order) => !syncedIds.contains(order.id)).map((PendingPosOrder order) => _withOutcome(order, replayed[order.id])).toList();
    await _persist();

    _isSyncing = false;
    _lastSyncMessage = synced > 0 ? 'sales_synced' : null;
    notifyListeners();
    return synced;
  }

  /// The sale as the queue holds it now, with the failed attempt that the pass counted against it.
  PendingPosOrder _withOutcome(PendingPosOrder current, PendingPosOrder? failedAttempt) => failedAttempt == null ? current : current.copyWith(attempts: failedAttempt.attempts, lastError: failedAttempt.lastError);

  /// The seller asks for the sales that could not be sent to be tried again: each of this seller's is given its attempts back and the queue is replayed. The failed sales of another seller are left as they are.
  Future<int> retryFailedSales() async {
    final Map<String, PendingPosOrder> reopened = <String, PendingPosOrder>{
      for (final PendingPosOrder order in OutboxPolicy.withFailedSalesReopened(_ownSales)) order.id: order,
    };
    _pending = _pending.map((PendingPosOrder order) => reopened[order.id] ?? order).toList();
    await _persist();
    notifyListeners();

    return syncPending();
  }

  /// Empties the queue of the seller who is signed in; the sales of another seller stay.
  Future<void> clear() async {
    final String? sellerId = _signedInSellerId();
    _pending = _pending.where((PendingPosOrder order) => !order.belongsTo(sellerId)).toList();
    await _persist();
    notifyListeners();
  }
}
