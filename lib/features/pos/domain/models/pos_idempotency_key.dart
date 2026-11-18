import 'dart:math';

/// One key for each POS sale, sent with the sale and sent again, unchanged, when the sale is replayed from the offline outbox. The server answers a second submission of the same key with the
/// first order and debits the wallet once, so a sale whose answer was lost is not sold twice when the connection comes back. An earlier version sent no key: a sale whose request had reached the
/// server but whose answer had not reached the device was queued as unsent and recorded a second time on replay.
class PosIdempotencyKey {
  const PosIdempotencyKey._();

  /// The header the server reads the key from.
  static const String header = 'Idempotency-Key';

  static final RegExp _uuidVersion4 = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

  /// A random version-4 UUID, from a source that cannot be guessed unless a test gives it a seed.
  static String generate({Random? random}) {
    final Random source = random ?? Random.secure();
    final List<int> bytes = List<int>.generate(16, (_) => source.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final String hex = bytes.map((int byte) => byte.toRadixString(16).padLeft(2, '0')).join();

    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static bool isValid(String? key) => key != null && _uuidVersion4.hasMatch(key);
}
