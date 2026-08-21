import 'epic.dart';
import 'project_issue.dart';

/// Thrown when an issue id has no matching record.
class IssueNotFoundException implements Exception {
  const IssueNotFoundException(this.issueId);

  final String issueId;

  @override
  String toString() => 'No issue found with id "$issueId".';
}

/// Thrown when an epic id has no matching record.
class EpicNotFoundException implements Exception {
  const EpicNotFoundException(this.epicId);

  final String epicId;

  @override
  String toString() => 'No epic found with id "$epicId".';
}

/// Source of [Epic]s and [ProjectIssue]s — issue #29's browser has no
/// control actions (unlike `MissionRepository`'s pause/resume/cancel), so
/// this interface is load-only.
abstract interface class IssueRepository {
  Future<List<ProjectIssue>> loadIssues();

  Future<List<Epic>> loadEpics();

  /// A single issue with its full context — throws [IssueNotFoundException]
  /// if [issueId] does not exist.
  Future<ProjectIssue> loadIssue(String issueId);

  /// A single epic with its full context — throws [EpicNotFoundException] if
  /// [epicId] does not exist.
  Future<Epic> loadEpic(String epicId);
}
