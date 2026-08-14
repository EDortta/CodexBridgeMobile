/// Instants rendered as text, at the precision the reader needs.
///
/// Always UTC, never the device's locale or time zone: two operators reading
/// the same expiry — one of them over a shared screenshot — must read the same
/// instant, and an operational timestamp that shifts with the reader is a
/// timestamp that cannot be compared to a log line.
///
/// It lives in `core/` rather than in a feature because two features render
/// instants — a certificate's validity window (#21) and a session's expiry
/// (#22) — and a feature must never import another feature
/// (`docs/architecture/state-architecture.md`). Same argument that moved
/// `SecureKeyValueStore` here.
abstract final class UtcMoment {
  /// Minute precision: `2026-08-14 13:05 UTC`.
  ///
  /// Enough to decide whether a session is about to end; seconds would be
  /// noise on a value the operator compares against a wall clock.
  static String minute(DateTime moment) {
    final DateTime utc = moment.toUtc();
    return '${_date(utc)} ${_pad(utc.hour)}:${_pad(utc.minute)} UTC';
  }

  /// Calendar day: `2026-08-14 UTC`.
  ///
  /// Enough to spot an expired or not-yet-valid certificate.
  static String day(DateTime moment) => '${_date(moment.toUtc())} UTC';

  static String _date(DateTime utc) =>
      '${utc.year}-${_pad(utc.month)}-${_pad(utc.day)}';

  static String _pad(int value) => value.toString().padLeft(2, '0');
}
