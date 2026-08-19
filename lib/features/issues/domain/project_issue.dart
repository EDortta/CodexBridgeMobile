/// How urgently a [ProjectIssue] needs attention.
///
/// Named `ProjectIssue` rather than `Issue` throughout this feature to avoid
/// colliding with "GitHub issue" in code, comments and docs elsewhere in this
/// repository.
enum IssuePriority {
  critical,
  high,
  normal,
  low;

  String get label => switch (this) {
    IssuePriority.critical => 'Critical',
    IssuePriority.high => 'High',
    IssuePriority.normal => 'Normal',
    IssuePriority.low => 'Low',
  };
}

class ProjectIssue {
  const ProjectIssue({
    required this.id,
    required this.projectId,
    required this.title,
    required this.priority,
  });

  final String id;
  final String projectId;
  final String title;
  final IssuePriority priority;
}
