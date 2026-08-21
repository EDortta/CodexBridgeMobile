/// Lifecycle state shared by [Epic] and [ProjectIssue] — issue #29's
/// "status". One enum for both: an epic and an issue move through the same
/// four stages, the same way `MissionStage` is one enum shared by every
/// mission regardless of its project (`features/missions/`).
enum IssueStatus {
  todo,
  inProgress,
  blocked,
  done;

  String get label => switch (this) {
    IssueStatus.todo => 'To do',
    IssueStatus.inProgress => 'In progress',
    IssueStatus.blocked => 'Blocked',
    IssueStatus.done => 'Done',
  };
}
