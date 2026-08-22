import 'package:codex_bridge_mobile/features/issues/domain/epic.dart';
import 'package:codex_bridge_mobile/features/issues/domain/issue_form_validation.dart';
import 'package:codex_bridge_mobile/features/issues/domain/issue_status.dart';
import 'package:flutter_test/flutter_test.dart';

/// #30's "validation is explicit" acceptance criterion — every rule
/// [IssueFormValidation.validate] enforces, pinned directly with no widget
/// involved (`design-standards.md` §1's "test the decision, not the
/// plumbing").
void main() {
  final List<Epic> noEpics = const <Epic>[];
  final Epic sameProjectEpic = Epic(
    id: 'epic-a',
    projectId: 'proj-1',
    title: 'Epic A',
    status: IssueStatus.todo,
    createdAt: DateTime.utc(2026, 1, 1),
  );
  final Epic otherProjectEpic = Epic(
    id: 'epic-b',
    projectId: 'proj-2',
    title: 'Epic B',
    status: IssueStatus.todo,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  test('a valid draft has no errors', () {
    final Map<String, String> errors = IssueFormValidation.validate(
      title: 'A real title',
      status: IssueStatus.todo,
      blockedReason: null,
      projectId: 'proj-1',
      epicId: null,
      epicsInProject: noEpics,
    );

    expect(errors, isEmpty);
  });

  test('an empty title is rejected', () {
    final Map<String, String> errors = IssueFormValidation.validate(
      title: '   ',
      status: IssueStatus.todo,
      blockedReason: null,
      projectId: 'proj-1',
      epicId: null,
      epicsInProject: noEpics,
    );

    expect(errors['title'], isNotNull);
  });

  test('a title longer than the max length is rejected', () {
    final Map<String, String> errors = IssueFormValidation.validate(
      title: 'x' * (IssueFormValidation.maxTitleLength + 1),
      status: IssueStatus.todo,
      blockedReason: null,
      projectId: 'proj-1',
      epicId: null,
      epicsInProject: noEpics,
    );

    expect(errors['title'], isNotNull);
  });

  test('a title at exactly the max length is accepted', () {
    final Map<String, String> errors = IssueFormValidation.validate(
      title: 'x' * IssueFormValidation.maxTitleLength,
      status: IssueStatus.todo,
      blockedReason: null,
      projectId: 'proj-1',
      epicId: null,
      epicsInProject: noEpics,
    );

    expect(errors['title'], isNull);
  });

  test('blocked status with no reason is rejected', () {
    final Map<String, String> errors = IssueFormValidation.validate(
      title: 'A title',
      status: IssueStatus.blocked,
      blockedReason: '   ',
      projectId: 'proj-1',
      epicId: null,
      epicsInProject: noEpics,
    );

    expect(errors['blockedReason'], isNotNull);
  });

  test('blocked status with a reason is accepted', () {
    final Map<String, String> errors = IssueFormValidation.validate(
      title: 'A title',
      status: IssueStatus.blocked,
      blockedReason: 'Waiting on X',
      projectId: 'proj-1',
      epicId: null,
      epicsInProject: noEpics,
    );

    expect(errors['blockedReason'], isNull);
  });

  test('a non-blocked status never requires a reason even if one is empty', () {
    final Map<String, String> errors = IssueFormValidation.validate(
      title: 'A title',
      status: IssueStatus.todo,
      blockedReason: null,
      projectId: 'proj-1',
      epicId: null,
      epicsInProject: noEpics,
    );

    expect(errors['blockedReason'], isNull);
  });

  test('an epic id belonging to this project resolves cleanly', () {
    final Map<String, String> errors = IssueFormValidation.validate(
      title: 'A title',
      status: IssueStatus.todo,
      blockedReason: null,
      projectId: 'proj-1',
      epicId: 'epic-a',
      epicsInProject: <Epic>[sameProjectEpic],
    );

    expect(errors['epicId'], isNull);
  });

  test('an epic id from a different project is rejected', () {
    final Map<String, String> errors = IssueFormValidation.validate(
      title: 'A title',
      status: IssueStatus.todo,
      blockedReason: null,
      projectId: 'proj-1',
      epicId: 'epic-b',
      epicsInProject: <Epic>[otherProjectEpic],
    );

    expect(errors['epicId'], isNotNull);
  });

  test('an epic id that resolves to nothing at all is rejected', () {
    final Map<String, String> errors = IssueFormValidation.validate(
      title: 'A title',
      status: IssueStatus.todo,
      blockedReason: null,
      projectId: 'proj-1',
      epicId: 'does-not-exist',
      epicsInProject: noEpics,
    );

    expect(errors['epicId'], isNotNull);
  });

  test('an empty-string epic id is treated as "no epic", not an error', () {
    final Map<String, String> errors = IssueFormValidation.validate(
      title: 'A title',
      status: IssueStatus.todo,
      blockedReason: null,
      projectId: 'proj-1',
      epicId: '',
      epicsInProject: noEpics,
    );

    expect(errors['epicId'], isNull);
  });
}
