import '../domain/epic.dart';
import '../domain/issue_status.dart';
import '../domain/project_issue.dart';

/// Every epic in [epics] scoped to [projectId], narrowed by [status] and
/// [priority] when given — #29's "project-scoped lists" and "filters
/// identify blocked and priority work".
///
/// Pure so it is testable without pumping a widget, the same reasoning
/// `filterDecisions` (`features/decisions/`) and `filterMissions`
/// (`features/missions/`) document.
List<Epic> filterEpics(
  List<Epic> epics, {
  required String projectId,
  required IssueStatus? status,
  required IssuePriority? priority,
}) {
  return epics.where((Epic epic) {
    if (epic.projectId != projectId) {
      return false;
    }
    if (status != null && epic.status != status) {
      return false;
    }
    if (priority != null && epic.priority != priority) {
      return false;
    }
    return true;
  }).toList(growable: false);
}

/// Every issue in [issues] scoped to [projectId], narrowed by [status] and
/// [priority] when given — same reasoning as [filterEpics].
List<ProjectIssue> filterIssues(
  List<ProjectIssue> issues, {
  required String projectId,
  required IssueStatus? status,
  required IssuePriority? priority,
}) {
  return issues.where((ProjectIssue issue) {
    if (issue.projectId != projectId) {
      return false;
    }
    if (status != null && issue.status != status) {
      return false;
    }
    if (priority != null && issue.priority != priority) {
      return false;
    }
    return true;
  }).toList(growable: false);
}
