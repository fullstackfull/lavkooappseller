/// Reads a body the way the platform admin API promises it, and survives the
/// way it might not.
///
/// Nothing here throws. A shape the app did not expect must show up as a missing
/// value on a screen, not as an exception that carries the body to a crash
/// report.
abstract final class PlatformJson {
  static Map<String, dynamic> map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

  static List<Object?> list(Object? value) => value is List ? value : const <Object?>[];

  static List<Map<String, dynamic>> maps(Object? value) =>
      list(value).whereType<Map<dynamic, dynamic>>().map(map).toList();

  static String? string(Object? value) => value is String ? value : null;

  static List<String> strings(Object? value) => list(value).whereType<String>().toList();

  /// A whole number, from a number or from a string that is one. Anything else
  /// is null, so that "many" is never read as zero by accident here and is
  /// decided by the caller.
  static int? integer(Object? value) {
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.truncateToDouble()) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static int count(Object? value) => integer(value) ?? 0;

  static bool flag(Object? value) => value == true;

  /// A moment written as ISO 8601, kept in UTC. Anything else is no moment.
  static DateTime? moment(Object? value) {
    final String? text = string(value);
    return text == null ? null : DateTime.tryParse(text)?.toUtc();
  }
}
