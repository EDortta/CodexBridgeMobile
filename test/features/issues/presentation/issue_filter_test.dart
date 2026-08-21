import 'package:codex_bridge_mobile/features/issues/domain/epic.dart';
import 'package:codex_bridge_mobile/features/issues/domain/issue_status.dart';
import 'package:codex_bridge_mobile/features/issues/domain/project_issue.dart';
import 'package:codex_bridge_mobile/features/issues/presentation/issue_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime createdAt = DateTime.utc(2026, 8, 20);

  final Epic mobileTodo = Epic(
    id: 'mobile-todo',
    projectId: 'codex-bridge-mobile',
    title: 'Mobile todo epic',
    status: IssueStatus.todo,
    priority: IssuePriority.low,
    createdAt: createdAt,
  );
  final Epic mobileBlocked = Epic(
    id: 'mobile-blocked',
    projectId: 'codex-bridge-mobile',
    title: 'Mobile blocked epic',
    status: IssueStatus.blocked,
    priority: IssuePriority.critical,
    createdAt: createdAt,
    blockedReason: 'Waiting on review.',
  );
  final Epic otherProject = Epic(
    id: 'other-project',
    projectId: 'codex-bridge',
    title: 'Other project epic',
    status: IssueStatus.blocked,
    priority: IssuePriority.critical,
    createdAt: createdAt,
  );

  final ProjectIssue mobileTodoIssue = ProjectIssue(
    id: 'mobile-todo-issue',
    projectId: 'codex-bridge-mobile',
    title: 'Mobile todo issue',
    priority: IssuePriority.low,
    status: IssueStatus.todo,
    createdAt: createdAt,
  );
  final ProjectIssue mobileBlockedIssue = ProjectIssue(
    id: 'mobile-blocked-issue',
    projectId: 'codex-bridge-mobile',
    title: 'Mobile blocked issue',
    priority: IssuePriority.critical,
    status: IssueStatus.blocked,
    createdAt: createdAt,
    blockedReason: 'Waiting on review.',
  );
  final ProjectIssue otherProjectIssue = ProjectIssue(
    id: 'other-project-issue',
    projectId: 'codex-bridge',
    title: 'Other project issue',
    priority: IssuePriority.critical,
    status: IssueStatus.blocked,
    createdAt: createdAt,
  );

  group('filterEpics', () {
    final List<Epic> all = <Epic>[mobileTodo, mobileBlocked, otherProject];

    test('scopes to the given project', () {
      final List<Epic> result = filterEpics(
        all,
        projectId: 'codex-bridge-mobile',
        status: null,
        priority: null,
      );

      expect(result, <Epic>[mobileTodo, mobileBlocked]);
    });

    test('narrows by status', () {
      final List<Epic> result = filterEpics(
        all,
        projectId: 'codex-bridge-mobile',
        status: IssueStatus.blocked,
        priority: null,
      );

      expect(result, <Epic>[mobileBlocked]);
    });

    test('narrows by priority', () {
      final List<Epic> result = filterEpics(
        all,
        projectId: 'codex-bridge-mobile',
        status: null,
        priority: IssuePriority.critical,
      );

      expect(result, <Epic>[mobileBlocked]);
    });

    test('status and priority combine', () {
      final List<Epic> result = filterEpics(
        all,
        projectId: 'codex-bridge-mobile',
        status: IssueStatus.todo,
        priority: IssuePriority.critical,
      );

      expect(result, isEmpty);
    });
  });

  group('filterIssues', () {
    final List<ProjectIssue> all = <ProjectIssue>[
      mobileTodoIssue,
      mobileBlockedIssue,
      otherProjectIssue,
    ];

    test('scopes to the given project', () {
      final List<ProjectIssue> result = filterIssues(
        all,
        projectId: 'codex-bridge-mobile',
        status: null,
        priority: null,
      );

      expect(result, <ProjectIssue>[mobileTodoIssue, mobileBlockedIssue]);
    });

    test('narrows by status', () {
      final List<ProjectIssue> result = filterIssues(
        all,
        projectId: 'codex-bridge-mobile',
        status: IssueStatus.blocked,
        priority: null,
      );

      expect(result, <ProjectIssue>[mobileBlockedIssue]);
    });

    test('narrows by priority', () {
      final List<ProjectIssue> result = filterIssues(
        all,
        projectId: 'codex-bridge-mobile',
        status: null,
        priority: IssuePriority.critical,
      );

      expect(result, <ProjectIssue>[mobileBlockedIssue]);
    });

    test('status and priority combine', () {
      final List<ProjectIssue> result = filterIssues(
        all,
        projectId: 'codex-bridge-mobile',
        status: IssueStatus.todo,
        priority: IssuePriority.critical,
      );

      expect(result, isEmpty);
    });
  });
}
