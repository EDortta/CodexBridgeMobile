class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.projectId,
    required this.description,
    required this.occurredAt,
  });

  final String id;
  final String projectId;
  final String description;

  /// The dashboard's recent-activity section marks an entry stale
  /// (`RelativeMoment.isStale`) against this.
  final DateTime occurredAt;
}
