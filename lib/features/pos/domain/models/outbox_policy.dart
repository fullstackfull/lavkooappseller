import 'package:syriacosmeticsmanger/features/pos/domain/models/pending_pos_order.dart';

/// What the offline outbox does with a sale it could not send. A queued sale is the only record of money taken at the counter, so it is never dropped: after [maxAttempts] failed replays it stops
/// being replayed by itself and stays on the device, with its last error, until the seller retries it or removes it. An earlier version deleted it after the tenth failure without a word, and the
/// seller never learned that a sale had not been recorded.
class OutboxPolicy {
  const OutboxPolicy._();

  static const int maxAttempts = 10;

  /// Whether the sale has used its attempts: it is shown to the seller as a sale that could not be sent.
  static bool hasFailed(PendingPosOrder order) => order.attempts >= maxAttempts;

  /// A sale that has failed is not replayed by every return of the connection; the seller decides.
  static bool isReplayedAutomatically(PendingPosOrder order) => !hasFailed(order);

  static List<PendingPosOrder> failedAmong(List<PendingPosOrder> pending) => pending.where(hasFailed).toList();

  /// The queue with every failed sale given its attempts back, so that the next replay tries it again; the others are as they were.
  static List<PendingPosOrder> withFailedSalesReopened(List<PendingPosOrder> pending) => pending.map((PendingPosOrder order) => hasFailed(order) ? order.copyWith(attempts: 0) : order).toList();
}
