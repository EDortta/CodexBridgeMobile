class Artifact {
  const Artifact({
    required this.id,
    required this.projectId,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String projectId;
  final String name;

  /// The dashboard's recent-artifacts section marks an artifact stale
  /// (`RelativeMoment.isStale`) against this.
  final DateTime createdAt;
}
