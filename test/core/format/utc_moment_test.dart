import 'package:codex_bridge_mobile/core/format/utc_moment.dart';
import 'package:flutter_test/flutter_test.dart';

/// The property these pin is not the string: it is that the string does not
/// depend on where the device is.
///
/// Two screens render instants — a session's expiry and a certificate's
/// validity window — and both are values an operator compares against a server
/// log. A rendering that shifted with the device's time zone would make the
/// same instant read differently on two phones side by side.
void main() {
  test('an instant renders the same however the device carries it', () {
    final DateTime utc = DateTime.utc(2026, 8, 14, 13, 5);
    // The same instant, expressed in local time. `toLocal()` is the shape a
    // DateTime arrives in from a JSON parse or a platform channel.
    final DateTime local = utc.toLocal();

    expect(UtcMoment.minute(local), UtcMoment.minute(utc));
    expect(UtcMoment.day(local), UtcMoment.day(utc));
  });

  test('minute precision names the day, the time and the zone', () {
    expect(
      UtcMoment.minute(DateTime.utc(2026, 8, 14, 13, 5)),
      '2026-08-14 13:05 UTC',
    );
  });

  test('single-digit parts are padded, so widths do not jump', () {
    expect(UtcMoment.minute(DateTime.utc(2026, 1, 2, 3, 4)), '2026-01-02 03:04 UTC');
    expect(UtcMoment.day(DateTime.utc(2026, 1, 2)), '2026-01-02 UTC');
  });

  test('midnight is a time, not an absence of one', () {
    // The failure this prevents: a formatter that drops a zeroed clock and
    // renders an expiry as a bare date the operator reads as "end of day".
    expect(
      UtcMoment.minute(DateTime.utc(2026, 8, 14)),
      '2026-08-14 00:00 UTC',
    );
  });
}
