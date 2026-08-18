enum LiveSessionState {
  queued,
  waitingExecutor,
  awaitingApproval,
  pausing,
  paused,
  resuming,
  restarting,
  running,
  completed,
  failed,
  cancelled,
  expired,
  lost;

  static LiveSessionState? parse(String raw) {
    return switch (raw) {
      'queued' => LiveSessionState.queued,
      'waiting_executor' => LiveSessionState.waitingExecutor,
      'awaiting_approval' => LiveSessionState.awaitingApproval,
      'pausing' => LiveSessionState.pausing,
      'paused' => LiveSessionState.paused,
      'resuming' => LiveSessionState.resuming,
      'restarting' => LiveSessionState.restarting,
      'running' => LiveSessionState.running,
      'completed' => LiveSessionState.completed,
      'failed' => LiveSessionState.failed,
      'cancelled' => LiveSessionState.cancelled,
      'expired' => LiveSessionState.expired,
      'lost' => LiveSessionState.lost,
      _ => null,
    };
  }

  String get label => switch (this) {
    LiveSessionState.queued => 'Queued',
    LiveSessionState.waitingExecutor => 'Waiting executor',
    LiveSessionState.awaitingApproval => 'Awaiting approval',
    LiveSessionState.pausing => 'Pausing',
    LiveSessionState.paused => 'Paused',
    LiveSessionState.resuming => 'Resuming',
    LiveSessionState.restarting => 'Restarting',
    LiveSessionState.running => 'Running',
    LiveSessionState.completed => 'Completed',
    LiveSessionState.failed => 'Failed',
    LiveSessionState.cancelled => 'Cancelled',
    LiveSessionState.expired => 'Expired',
    LiveSessionState.lost => 'Lost',
  };
}

class LiveSession {
  const LiveSession({
    required this.id,
    required this.projectId,
    required this.executorId,
    required this.instruction,
    required this.state,
    required this.priority,
    required this.revision,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.requestedBy,
    this.lastError,
  });

  final String id;
  final String projectId;
  final String executorId;
  final String instruction;
  final LiveSessionState state;
  final String priority;
  final int revision;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? requestedBy;
  final String? lastError;

  bool get canPause => state == LiveSessionState.running;

  bool get canResume => state == LiveSessionState.paused;

  /// Mirrors the gateway's `RESTARTABLE | FINISHED_RESTARTABLE`
  /// (`gateway/app/api/routes/sessions.py`): a live session can be
  /// restarted, and so can one that already finished — `allow_finished_restart`
  /// exists specifically so a failed or cancelled session has a way back
  /// without a brand new submission. Before this, only the live states were
  /// mirrored here, so the restart button never appeared next to "Explain
  /// error" on the one session it would matter most for — a failed one
  /// (council 2026-08-18, "the sweep skeptic"). A rejected-approval session
  /// is still `cancelled` here and shows the button; the gateway answers that
  /// specific case with 409, surfaced the same way any other control error is.
  bool get canRestart => switch (state) {
    LiveSessionState.running ||
    LiveSessionState.paused ||
    LiveSessionState.completed ||
    LiveSessionState.failed ||
    LiveSessionState.cancelled ||
    LiveSessionState.expired ||
    LiveSessionState.lost => true,
    _ => false,
  };

  bool get canStop => switch (state) {
    LiveSessionState.queued ||
    LiveSessionState.waitingExecutor ||
    LiveSessionState.awaitingApproval ||
    LiveSessionState.pausing ||
    LiveSessionState.paused ||
    LiveSessionState.resuming ||
    LiveSessionState.restarting ||
    LiveSessionState.running => true,
    _ => false,
  };

  static LiveSession fromJson(Map<String, Object?> json) {
    final String? id = _nonEmpty(json['id']);
    final String? projectId = _nonEmpty(json['projectId']);
    final String? executorId = _nonEmpty(json['executorId']);
    final String? instruction = _nonEmpty(json['instruction']);
    final LiveSessionState? state =
        json['state'] is String ? LiveSessionState.parse(json['state']! as String) : null;
    final String? priority = _nonEmpty(json['priority']);
    final int? revision = json['revision'] is int ? json['revision']! as int : null;
    final DateTime? createdAt = _instant(json['createdAt']);
    if (id == null ||
        projectId == null ||
        executorId == null ||
        instruction == null ||
        state == null ||
        priority == null ||
        revision == null ||
        createdAt == null) {
      throw const FormatException('invalid_session_payload');
    }
    return LiveSession(
      id: id,
      projectId: projectId,
      executorId: executorId,
      instruction: instruction,
      state: state,
      priority: priority,
      revision: revision,
      createdAt: createdAt,
      startedAt: _instant(json['startedAt']),
      completedAt: _instant(json['completedAt']),
      requestedBy: _nonEmpty(json['requestedBy']),
      lastError: _nonEmpty(json['lastError']),
    );
  }

  static String? _nonEmpty(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static DateTime? _instant(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
