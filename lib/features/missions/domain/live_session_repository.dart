import 'live_session.dart';
import 'live_session_explanation.dart';
import 'live_session_log_entry.dart';

enum LiveSessionControlAction {
  pause('pause'),
  resume('resume'),
  restart('restart'),
  stop('stop');

  const LiveSessionControlAction(this.pathSegment);

  final String pathSegment;

  /// Whether sending this action needs confirmation first.
  ///
  /// Pause and resume are reversible from the same screen; restart discards
  /// the current run and stop ends it, so both surfaces gate on the same
  /// dialog copy below rather than each writing its own.
  bool get isDestructive =>
      this == LiveSessionControlAction.restart ||
      this == LiveSessionControlAction.stop;

  String get confirmTitle => switch (this) {
    LiveSessionControlAction.stop => 'Stop this session?',
    LiveSessionControlAction.restart => 'Restart this session?',
    LiveSessionControlAction.pause || LiveSessionControlAction.resume => '',
  };

  String get confirmMessage => switch (this) {
    LiveSessionControlAction.stop =>
      'The session will be stopped and cannot be resumed.',
    LiveSessionControlAction.restart =>
      'The current run will be discarded and started again from the beginning.',
    LiveSessionControlAction.pause || LiveSessionControlAction.resume => '',
  };

  String get confirmLabel => switch (this) {
    LiveSessionControlAction.stop => 'Stop',
    LiveSessionControlAction.restart => 'Restart',
    LiveSessionControlAction.pause || LiveSessionControlAction.resume => '',
  };
}

abstract interface class LiveSessionRepository {
  Future<List<LiveSession>> loadSessions({
    required Uri server,
    required String accessToken,
  });

  Future<LiveSession> loadSessionDetail({
    required Uri server,
    required String accessToken,
    required String sessionId,
  });

  Future<List<LiveSessionLogEntry>> loadSessionLogs({
    required Uri server,
    required String accessToken,
    required String sessionId,
    int offset = 0,
    int limit = 200,
  });

  Future<LiveSession> controlSession({
    required Uri server,
    required String accessToken,
    required String sessionId,
    required int revision,
    required LiveSessionControlAction action,
  });

  Future<LiveSessionErrorExplanation> explainError({
    required Uri server,
    required String accessToken,
    required String sessionId,
  });
}

class LiveSessionRepositoryException implements Exception {
  const LiveSessionRepositoryException(this.message);

  final String message;
}
