import 'package:codex_bridge_mobile/features/issues/domain/epic.dart';
import 'package:codex_bridge_mobile/features/issues/domain/issue_status.dart';
import 'package:codex_bridge_mobile/features/issues/domain/project_issue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Epic buildEpic({IssueStatus status = IssueStatus.todo, String? blockedReason}) {
    return Epic(
      id: 'epic-1',
      projectId: 'codex-bridge-mobile',
      title: 'Example epic',
      status: status,
      priority: IssuePriority.high,
      createdAt: DateTime.utc(2026, 8, 3),
      blockedReason: blockedReason,
    );
  }

  test('unset fields default to empty', () {
    final Epic epic = buildEpic();

    expect(epic.summary, isEmpty);
    expect(epic.blockedReason, isNull);
    expect(epic.issueIds, isEmpty);
  });

  test('every field round-trips through the constructor', () {
    final DateTime createdAt = DateTime.utc(2026, 8, 3);
    final Epic epic = Epic(
      id: 'epic-mobile-planning',
      projectId: 'codex-bridge-mobile',
      title: 'Epic 06 — Epics, Issues e planejamento',
      status: IssueStatus.inProgress,
      priority: IssuePriority.high,
      createdAt: createdAt,
      summary: 'Bring epics and issues into the mobile terminal.',
      blockedReason: null,
      issueIds: const <String>['issue-epics-browser', 'issue-issue-detail'],
    );

    expect(epic.id, 'epic-mobile-planning');
    expect(epic.projectId, 'codex-bridge-mobile');
    expect(epic.title, 'Epic 06 — Epics, Issues e planejamento');
    expect(epic.status, IssueStatus.inProgress);
    expect(epic.priority, IssuePriority.high);
    expect(epic.createdAt, createdAt);
    expect(epic.summary, 'Bring epics and issues into the mobile terminal.');
    expect(epic.issueIds, <String>['issue-epics-browser', 'issue-issue-detail']);
  });

  test('isBlocked is true only when status is blocked', () {
    expect(buildEpic(status: IssueStatus.blocked).isBlocked, isTrue);
    expect(buildEpic().isBlocked, isFalse);
    expect(buildEpic(status: IssueStatus.done).isBlocked, isFalse);
  });
}
