import 'package:codex_bridge_mobile/features/issues/domain/issue_status.dart';
import 'package:codex_bridge_mobile/features/issues/domain/project_issue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProjectIssue buildIssue({
    IssueStatus status = IssueStatus.todo,
    String? blockedReason,
  }) {
    return ProjectIssue(
      id: 'issue-1',
      projectId: 'codex-bridge-mobile',
      title: 'Example issue',
      priority: IssuePriority.high,
      status: status,
      createdAt: DateTime.utc(2026, 8, 20),
      blockedReason: blockedReason,
    );
  }

  test('unset fields default to the documented "say it in text" values', () {
    final ProjectIssue issue = buildIssue();

    expect(issue.assignee, 'Unassigned');
    expect(issue.epicId, isNull);
    expect(issue.summary, isEmpty);
    expect(issue.blockedReason, isNull);
    expect(issue.labels, isEmpty);
    expect(issue.dependencies, isEmpty);
  });

  test('every field round-trips through the constructor', () {
    final DateTime createdAt = DateTime.utc(2026, 8, 20);
    final ProjectIssue issue = ProjectIssue(
      id: 'issue-1',
      projectId: 'codex-bridge-mobile',
      title: 'Build Epics and Issues browser',
      priority: IssuePriority.high,
      status: IssueStatus.inProgress,
      createdAt: createdAt,
      assignee: 'Claude',
      epicId: 'epic-mobile-planning',
      summary: 'Project-scoped lists.',
      blockedReason: null,
      labels: const <String>['mobile', 'planning'],
      dependencies: const <String>['Mission detail (#28)'],
    );

    expect(issue.id, 'issue-1');
    expect(issue.projectId, 'codex-bridge-mobile');
    expect(issue.title, 'Build Epics and Issues browser');
    expect(issue.priority, IssuePriority.high);
    expect(issue.status, IssueStatus.inProgress);
    expect(issue.createdAt, createdAt);
    expect(issue.assignee, 'Claude');
    expect(issue.epicId, 'epic-mobile-planning');
    expect(issue.summary, 'Project-scoped lists.');
    expect(issue.labels, <String>['mobile', 'planning']);
    expect(issue.dependencies, <String>['Mission detail (#28)']);
  });

  test('isBlocked is true only when status is blocked', () {
    expect(buildIssue(status: IssueStatus.blocked).isBlocked, isTrue);
    expect(buildIssue().isBlocked, isFalse);
    expect(buildIssue(status: IssueStatus.done).isBlocked, isFalse);
  });
}
