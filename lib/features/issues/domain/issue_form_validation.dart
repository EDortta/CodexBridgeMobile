import 'epic.dart';
import 'issue_status.dart';

/// Field-level validation for the create/edit form (#30) — "validation is
/// explicit" is #30's own acceptance criterion, so every rule the form
/// enforces lives here as a named, independently testable check rather than
/// scattered `if` statements inside widget callbacks.
///
/// Pure: takes plain values, returns a field-name -> message map, and is
/// testable without pumping a widget (`design-standards.md` §1's "test the
/// decision, not the plumbing"). `IssueFormScreen` calls this on every
/// change to decide which step can advance and whether the review step's
/// submit button is enabled; `MockIssueRepository`/`HttpIssueRepository`
/// enforce the same invariants again at the write itself
/// (`design-standards.md` §3 — "a guard belongs inside the dangerous
/// operation, not at the caller") so a future caller that skips this form
/// still cannot create an inconsistent issue.
abstract final class IssueFormValidation {
  static const int maxTitleLength = 200;

  /// Returns one entry per invalid field; an empty map means the draft is
  /// valid. Keys match the form-field identity a widget test can assert
  /// against: `title`, `blockedReason`, `epicId`.
  static Map<String, String> validate({
    required String title,
    required IssueStatus status,
    required String? blockedReason,
    required String projectId,
    required String? epicId,
    required List<Epic> epicsInProject,
  }) {
    final Map<String, String> errors = <String, String>{};

    final String trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      errors['title'] = 'Title is required.';
    } else if (trimmedTitle.length > maxTitleLength) {
      errors['title'] = 'Title must be $maxTitleLength characters or fewer.';
    }

    // Mirrors `Mission.copyWith`'s own invariant (`features/missions/`): a
    // blocked state with no stated cause defeats the "operator understands
    // why it's blocked" promise every blocked-state screen in this app
    // makes.
    if (status == IssueStatus.blocked &&
        (blockedReason == null || blockedReason.trim().isEmpty)) {
      errors['blockedReason'] = 'A blocked issue requires a reason.';
    }

    // "priority, state and relationships can be updated without losing
    // context" (#30's own wording) — an epic association must resolve to a
    // real epic in the *same* project, not a dangling id or a cross-project
    // mix-up the dropdown itself should never have offered.
    if (epicId != null && epicId.isNotEmpty) {
      final bool resolves = epicsInProject.any(
        (Epic epic) => epic.id == epicId && epic.projectId == projectId,
      );
      if (!resolves) {
        errors['epicId'] = 'Select an epic that belongs to this project.';
      }
    }

    return errors;
  }
}
