import 'live_session_log_entry.dart';

/// The evidence the gateway assembles for why a mission is in its current
/// state — `POST /api/v1/missions/{missionId}/explain`
/// (`docs/api/codex-bridge.openapi.yaml`).
///
/// Mirrors [LiveSessionErrorExplanation] in shape (recorded state, stored
/// error, recent `stderr`, already redacted server-side) for the same
/// underlying reason: a mission is the same row a live session is, reframed.
/// Distinct from [Mission.explanation] (`mission.dart`), which is a plain
/// local getter computed from fields already on the client — this class is
/// the *remote*, richer account the gateway assembles server-side (it can
/// see `recentStderr`; the client cannot). Both exist: [Mission.explanation]
/// needs no round trip and is what today's "Explain" button on
/// `MissionDetailScreen` shows; this class is what [MissionRepository.explain]
/// returns for a caller that wants the server's own account instead.
class MissionExplanation {
  const MissionExplanation({
    required this.missionId,
    required this.state,
    required this.reasons,
    required this.generatedAt,
    this.lastError,
    this.recentStderr = const <LiveSessionLogEntry>[],
  });

  final String missionId;
  final String state;
  final List<String> reasons;
  final String? lastError;
  final List<LiveSessionLogEntry> recentStderr;
  final DateTime generatedAt;

  static MissionExplanation fromJson(Map<String, Object?> json) {
    final String? missionId = _nonEmpty(json['missionId']);
    final String? state = _nonEmpty(json['state']);
    final Object? rawReasons = json['reasons'];
    final DateTime? generatedAt = _instant(json['generatedAt']);
    if (missionId == null ||
        state == null ||
        rawReasons is! List<Object?> ||
        generatedAt == null) {
      throw const FormatException('invalid_mission_explanation_payload');
    }
    final Object? rawStderr = json['recentStderr'];
    return MissionExplanation(
      missionId: missionId,
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
      generatedAt: generatedAt,
    );
  }

  static String? _nonEmpty(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static DateTime? _instant(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
