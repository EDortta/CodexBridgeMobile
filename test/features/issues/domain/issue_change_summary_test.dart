import 'package:codex_bridge_mobile/features/issues/domain/issue_change_summary.dart';
import 'package:codex_bridge_mobile/features/issues/domain/issue_status.dart';
import 'package:codex_bridge_mobile/features/issues/domain/project_issue.dart';
import 'package:flutter_test/flutter_test.dart';

/// #30's "changes preserve history" and "planning review" acceptance
/// criteria both read off [describeIssueChanges] — the review step and the
/// history entries the mock repository writes use the exact same wording,
/// so this is the one place that wording is pinned.
void main() {
  ProjectIssue issue({
    String title = 'Title',
    IssueStatus status = IssueStatus.todo,
    IssuePriority priority = IssuePriority.normal,
    String assignee = 'Unassigned',
    String? epicId,
    String summary = '',
    String? blockedReason,
    List<String> labels = const <String>[],
    List<String> dependencies = const <String>[],
  }) => ProjectIssue(
    id: 'issue-1',
    projectId: 'proj-1',
    title: title,
    status: status,
    priority: priority,
    createdAt: DateTime.utc(2026, 1, 1),
    assignee: assignee,
    epicId: epicId,
    summary: summary,
    blockedReason: blockedReason,
    labels: labels,
    dependencies: dependencies,
  );

  test('an identical before/after produces no changes', () {
    final ProjectIssue a = issue();
    final ProjectIssue b = issue();

    expect(describeIssueChanges(before: a, after: b), isEmpty);
  });

  test('a title change is described with both values', () {
    final List<String> changes = describeIssueChanges(
      before: issue(title: 'Old'),
      after: issue(title: 'New'),
    );

    expect(changes, contains('Title changed from "Old" to "New".'));
  });

  test('a status change is described with both labels', () {
    final List<String> changes = describeIssueChanges(
      before: issue(status: IssueStatus.todo),
      after: issue(status: IssueStatus.inProgress),
    );

    expect(changes, contains('Status changed from To do to In progress.'));
  });

  test('a priority change is described with both labels', () {
    final List<String> changes = describeIssueChanges(
      before: issue(priority: IssuePriority.high),
      after: issue(priority: IssuePriority.critical),
    );

    expect(changes, contains('Priority changed from High to Critical.'));
  });

  test('changing only priority produces exactly one line', () {
    final List<String> changes = describeIssueChanges(
      before: issue(priority: IssuePriority.high),
      after: issue(priority: IssuePriority.critical),
    );

    expect(changes, hasLength(1));
  });

  test('gaining an epic is described distinctly from moving between epics', () {
    final List<String> gained = describeIssueChanges(
      before: issue(),
      after: issue(epicId: 'epic-a'),
    );
    final List<String> moved = describeIssueChanges(
      before: issue(epicId: 'epic-a'),
      after: issue(epicId: 'epic-b'),
    );
    final List<String> removed = describeIssueChanges(
      before: issue(epicId: 'epic-a'),
      after: issue(),
    );

    expect(gained, contains('Linked to an epic.'));
    expect(moved, contains('Moved to a different epic.'));
    expect(removed, contains('Removed from its epic.'));
  });

  test('setting a blocked reason vs. clearing it are described distinctly', () {
    final List<String> set = describeIssueChanges(
      before: issue(),
      after: issue(blockedReason: 'Waiting on X'),
    );
    final List<String> cleared = describeIssueChanges(
      before: issue(blockedReason: 'Waiting on X'),
      after: issue(),
    );

    expect(set, contains('Blocked reason set to "Waiting on X".'));
    expect(cleared, contains('Blocked reason cleared.'));
  });

  test('label list changes are reported once, not per element', () {
    final List<String> changes = describeIssueChanges(
      before: issue(labels: const <String>['a']),
      after: issue(labels: const <String>['a', 'b']),
    );

    expect(changes, <String>['Labels updated.']);
  });

  test('reordering the same labels still reports a change (order-sensitive)', () {
    final List<String> changes = describeIssueChanges(
      before: issue(labels: const <String>['a', 'b']),
      after: issue(labels: const <String>['b', 'a']),
    );

    // Order matters for this comparison: `ProjectIssue.labels` is an
    // ordered list, so a reorder is a real, if minor, change — this test
    // pins that this function does not silently ignore it.
    expect(changes, <String>['Labels updated.']);
  });

  test('multiple simultaneous field changes each produce their own line', () {
    final List<String> changes = describeIssueChanges(
      before: issue(title: 'Old', priority: IssuePriority.low),
      after: issue(title: 'New', priority: IssuePriority.high),
    );

    expect(changes, hasLength(2));
  });
}
