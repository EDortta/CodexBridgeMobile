import 'epic.dart';
import 'issue_status.dart';
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

/// Source of [Epic]s and [ProjectIssue]s, and — since #30 — where they are
/// created and edited. #29's browser only ever read through this interface
/// (unlike `MissionRepository`'s pause/resume/cancel, present from the
/// start); #30 is what turns it into a write path.
abstract interface class IssueRepository {
  Future<List<ProjectIssue>> loadIssues();

  Future<List<Epic>> loadEpics();

  /// A single issue with its full context — throws [IssueNotFoundException]
  /// if [issueId] does not exist.
  Future<ProjectIssue> loadIssue(String issueId);

  /// A single epic with its full context — throws [EpicNotFoundException] if
  /// [epicId] does not exist.
  Future<Epic> loadEpic(String epicId);

  /// Creates a new epic — #30's planning form, "associating [issues] with
  /// Epics" starts with an epic existing to associate to.
  Future<Epic> createEpic({
    required String projectId,
    required String title,
    String? description,
    IssueStatus? status,
  });

  /// Creates a new issue — #30's "creating... Issues". [IssueFormValidation]
  /// (`issue_form_validation.dart`) is the caller's explicit pre-check; an
  /// implementation re-validates the same invariants at the write itself
  /// (`design-standards.md` §3), never trusting every future caller to have
  /// run the form's own validation first.
  Future<ProjectIssue> createIssue({
    required String projectId,
    required String title,
    String? epicId,
    String? description,
    IssueStatus? status,
    IssuePriority? priority,
    List<String>? labels,
    String? assigneeUserId,
    String? assigneeEmail,
    List<String>? dependencies,
    String? blockedReason,
  });

  /// Changes fields on an existing issue, guarded by [revision] — the value
  /// last read from [ProjectIssue.revision]. Throws
  /// [StaleIssueRevisionException] when [issueId] changed since that read —
  /// #30's "priority, state and relationships can be updated without losing
  /// context" depends on the caller reloading and re-showing the current
  /// state rather than silently overwriting a concurrent edit.
  /// `epicId` is deliberately not a parameter here — see [linkIssueToEpic].
  Future<ProjectIssue> updateIssue({
    required String issueId,
    required int revision,
    String? title,
    String? description,
    IssueStatus? status,
    IssuePriority? priority,
    List<String>? labels,
    String? assigneeUserId,
    String? assigneeEmail,
    List<String>? dependencies,
    String? blockedReason,
  });

  /// Moves [issueId] into [epicId], guarded by [issueRevision]. Throws
  /// [StaleIssueRevisionException] on a stale read, the same as
  /// [updateIssue].
  Future<ProjectIssue> linkIssueToEpic({
    required String epicId,
    required String issueId,
    required int issueRevision,
  });
}

/// A transport, auth, or shape failure talking to the real gateway — the
/// same role `LiveSessionRepositoryException` plays for missions. Not
/// raised by [MockIssueRepository], which never leaves the process.
class IssueRepositoryException implements Exception {
  const IssueRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A write was rejected because the entity changed since the caller last
/// read it — the gateway's `412 stale_write` (`concurrency.require_if_match`,
/// `CodexBridge` `gateway/app/api/concurrency.py`). Distinct from
/// [IssueRepositoryException] so a future caller can offer "reload and
/// retry" instead of a plain failure message.
class StaleIssueRevisionException implements Exception {
  const StaleIssueRevisionException(this.message);

  final String message;

  @override
  String toString() => message;
}
