import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A source of "now" that can be swapped out in a test.
///
/// Every call site that needs the current instant reads it through this
/// provider instead of calling `DateTime.timestamp` directly, the same
/// discipline `sessionClockProvider` (`features/auth/`) already uses — a
/// staleness decision made against the real clock is untestable without it.
typedef Clock = DateTime Function();

final Provider<Clock> appClockProvider = Provider<Clock>(
  (Ref ref) => DateTime.timestamp,
);

/// Instants rendered as "how long ago", and whether that is stale.
///
/// Lives in `core/` rather than in a feature because #24 needs it from four
/// features at once (decisions, artifacts, activity, and — indirectly —
/// sessions/missions) and a feature must never import another feature
/// (`docs/architecture/state-architecture.md`). Same argument that moved
/// `UtcMoment` here.
///
/// Deliberately separate from `UtcMoment`: that one renders an absolute
/// instant everyone must read identically; this one renders a relative
/// judgment ("is this old?") that depends on when it is read, so every
/// method here takes `now` explicitly rather than calling the clock itself.
abstract final class RelativeMoment {
  /// A short relative label: `just now`, `5m ago`, `3h ago`, `2d ago`.
  ///
  /// [moment] not before [now] (clock skew, or an instant that has not
  /// happened yet) reads as `just now` rather than a negative duration —
  /// there is no meaningful "how long ago" for that case.
  static String describe(DateTime moment, {required DateTime now}) {
    final Duration age = now.difference(moment);
    if (age.inMinutes < 1) {
      return 'just now';
    }
    if (age.inHours < 1) {
      return '${age.inMinutes}m ago';
    }
    if (age.inDays < 1) {
      return '${age.inHours}h ago';
    }
    return '${age.inDays}d ago';
  }

  /// Whether [moment] is old enough, as of [now], to warrant marking as
  /// stale — the caller states its own [threshold] rather than this class
  /// assuming one age fits every kind of data (a pending decision and a
  /// build artifact go stale on different clocks).
  static bool isStale(
    DateTime moment, {
    required DateTime now,
    required Duration threshold,
  }) {
    return now.difference(moment) >= threshold;
  }
}
