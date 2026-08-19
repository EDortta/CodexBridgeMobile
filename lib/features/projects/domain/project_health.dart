/// A project's operational state, as summarized for the projects list.
///
/// Every value carries a [label] so a state is never expressed by color
/// alone on the card (`docs/issues/phase-1/README.md`-adjacent accessibility
/// bar set by #31/#32 for session states applies here too).
enum ProjectHealth {
  active,
  unhealthy,
  pendingDecision,
  offline;

  String get label => switch (this) {
    ProjectHealth.active => 'Active',
    ProjectHealth.unhealthy => 'Unhealthy',
    ProjectHealth.pendingDecision => 'Pending decision',
    ProjectHealth.offline => 'Offline',
  };
}
