import 'package:codex_bridge_mobile/core/format/relative_moment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 19, 12);

  group('describe', () {
    test('under a minute reads as "just now"', () {
      expect(
        RelativeMoment.describe(now.subtract(const Duration(seconds: 30)), now: now),
        'just now',
      );
    });

    test('under an hour reads in minutes', () {
      expect(
        RelativeMoment.describe(now.subtract(const Duration(minutes: 5)), now: now),
        '5m ago',
      );
    });

    test('under a day reads in hours', () {
      expect(
        RelativeMoment.describe(now.subtract(const Duration(hours: 3)), now: now),
        '3h ago',
      );
    });

    test('a day or more reads in days', () {
      expect(
        RelativeMoment.describe(now.subtract(const Duration(days: 2)), now: now),
        '2d ago',
      );
    });

    test('a moment not before now reads as "just now", not a negative duration', () {
      expect(
        RelativeMoment.describe(now.add(const Duration(minutes: 5)), now: now),
        'just now',
      );
    });
  });

  group('isStale', () {
    test('younger than the threshold is not stale', () {
      expect(
        RelativeMoment.isStale(
          now.subtract(const Duration(hours: 23)),
          now: now,
          threshold: const Duration(hours: 24),
        ),
        isFalse,
      );
    });

    test('exactly at the threshold is stale (boundary is inclusive)', () {
      expect(
        RelativeMoment.isStale(
          now.subtract(const Duration(hours: 24)),
          now: now,
          threshold: const Duration(hours: 24),
        ),
        isTrue,
      );
    });

    test('older than the threshold is stale', () {
      expect(
        RelativeMoment.isStale(
          now.subtract(const Duration(days: 8)),
          now: now,
          threshold: const Duration(days: 7),
        ),
        isTrue,
      );
    });
  });
}
