import 'live_session_log_entry.dart';

/// The evidence the gateway assembles for why a session failed.
///
/// Mirrors `POST /api/v1/sessions/{id}/explain-error`: recorded state, stored
/// error and the tail of `stderr`, already redacted server-side. Nothing here
/// is inferred on-device — the gateway is the one place that has read the
/// executor's actual output.
class LiveSessionErrorExplanation {
  const LiveSessionErrorExplanation({
    required this.sessionId,
    required this.state,
    required this.reasons,
    required this.recentStderr,
    this.lastError,
  });

  final String sessionId;
  final String state;
  final List<String> reasons;
  final String? lastError;
  final List<LiveSessionLogEntry> recentStderr;

  static LiveSessionErrorExplanation fromJson(Map<String, Object?> json) {
    final String? sessionId = _nonEmpty(json['sessionId']);
    final String? state = _nonEmpty(json['state']);
    final Object? rawReasons = json['reasons'];
    if (sessionId == null || state == null || rawReasons is! List<Object?>) {
      throw const FormatException('invalid_session_explanation_payload');
    }
    final Object? rawStderr = json['recentStderr'];
    return LiveSessionErrorExplanation(
      sessionId: sessionId,
      state: state,
      reasons: rawReasons.whereType<String>().toList(growable: false),
      lastError: _nonEmpty(json['lastError']),
      recentStderr: rawStderr is List<Object?>
          ? rawStderr
                .whereType<Map<String, Object?>>()
                .map(
                  (Map<String, Object?> row) => LiveSessionLogEntry.fromJson(
                    <String, Object?>{...row, 'stream': 'stderr'},
                  ),
                )
                .toList(growable: false)
          : const <LiveSessionLogEntry>[],
    );
  }

  static String? _nonEmpty(Object? value) =>
      value is String && value.isNotEmpty ? value : null;
}
