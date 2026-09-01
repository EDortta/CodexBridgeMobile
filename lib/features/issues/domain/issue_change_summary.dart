import 'project_issue.dart';

/// Plain-language descriptions of what changed between [before] and [after]
/// — issue #30's "changes preserve history" acceptance criterion, and the
/// "review" step of its progressive form (#30's own title names "planning
/// review").
///
/// Pure and independently testable without a repository or a widget
/// (`design-standards.md` §1's "test the decision, not the plumbing"): the
/// call sites that build history events or a review-step summary both go
/// through this one function, so the wording is never duplicated or drifts
/// between the two.
///
/// Only fields that actually differ produce a line — editing one field must
/// not manufacture noise about every other field the operator left alone.
List<String> describeIssueChanges({
  required ProjectIssue before,
  required ProjectIssue after,
}) {
  final List<String> changes = <String>[];

  if (before.title != after.title) {
    changes.add('Title changed from "${before.title}" to "${after.title}".');
  }
  if (before.status != after.status) {
    changes.add('Status changed from ${before.status.label} to ${after.status.label}.');
  }
  if (before.priority != after.priority) {
    changes.add('Priority changed from ${before.priority.label} to ${after.priority.label}.');
  }
  if (before.assignee != after.assignee) {
    changes.add('Assignee changed from ${before.assignee} to ${after.assignee}.');
  }
  if (before.epicId != after.epicId) {
    changes.add(
      after.epicId == null
          ? 'Removed from its epic.'
          : before.epicId == null
          ? 'Linked to an epic.'
          : 'Moved to a different epic.',
    );
  }
  if (before.summary != after.summary) {
    changes.add('Description updated.');
  }
  if (before.blockedReason != after.blockedReason) {
    changes.add(
      after.blockedReason == null
          ? 'Blocked reason cleared.'
          : 'Blocked reason set to "${after.blockedReason}".',
    );
  }
  if (!_sameStringList(before.labels, after.labels)) {
    changes.add('Labels updated.');
  }
  if (!_sameStringList(before.dependencies, after.dependencies)) {
    changes.add('Dependencies updated.');
  }

  return changes;
}

bool _sameStringList(List<String> a, List<String> b) {
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
