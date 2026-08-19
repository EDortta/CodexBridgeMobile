class Decision {
  const Decision({
    required this.id,
    required this.projectId,
    required this.title,
    required this.requestedBy,
    required this.requestedAt,
  });

  final String id;
  final String projectId;
  final String title;
  final String requestedBy;

  /// When the decision was requested — the dashboard's pending-decisions
  /// section marks a decision stale (`RelativeMoment.isStale`) against this.
  final DateTime requestedAt;
}
