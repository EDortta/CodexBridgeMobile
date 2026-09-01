import 'issue_history_event.dart';
import 'issue_status.dart';

/// How urgently a [ProjectIssue] needs attention.
///
/// Named `ProjectIssue` rather than `Issue` throughout this feature to avoid
/// colliding with "GitHub issue" in code, comments and docs elsewhere in this
/// repository.
enum IssuePriority {
  critical,
  high,
  normal,
  low;

  String get label => switch (this) {
    IssuePriority.critical => 'Critical',
    IssuePriority.high => 'High',
    IssuePriority.normal => 'Normal',
    IssuePriority.low => 'Low',
  };
}

/// A single unit of planned work under a project — issue #29's "Issue view".
///
/// Carries every field #29's acceptance criteria name for a project-scoped
/// list: "status, priority, labels, dependencies, assignee and blocked
/// indicators". Only [id], [projectId], [title] and [priority] were required
/// before #29; every other field is additive, so
/// `project_dashboard_screen.dart`'s existing "Priority issues" section
/// (#24), which reads only those four, needed no changes.
class ProjectIssue {
  const ProjectIssue({
    required this.id,
    required this.projectId,
    required this.title,
    required this.priority,
    required this.status,
    required this.createdAt,
    this.assignee = 'Unassigned',
    this.epicId,
    this.summary = '',
    this.blockedReason,
    this.labels = const <String>[],
    this.dependencies = const <String>[],
    this.revision = 1,
    this.history = const <IssueHistoryEvent>[],
  });

  final String id;
  final String projectId;
  final String title;
  final IssuePriority priority;
  final IssueStatus status;
  final DateTime createdAt;

  /// The agent or operator responsible for this issue. Never empty — an
  /// unowned issue is represented by the explicit value `'Unassigned'`, the
  /// same "say it in text" rule `Mission.owner` follows, rather than a
  /// nullable field every card would have to special-case.
  final String assignee;

  /// The [Epic] this issue belongs to — null for an issue with no epic yet.
  final String? epicId;

  /// What this issue is about — the detail screen's "full context" (#29's
  /// acceptance criterion). Empty for an issue only ever seen through the
  /// list card.
  final String summary;

  /// Why [status] is [IssueStatus.blocked] — meaningful only then, the same
  /// convention `Mission.blockedReason` documents.
  final String? blockedReason;

  final List<String> labels;

  /// Other issues (or external prerequisites, named in plain text) this one
  /// depends on — plain strings, not [ProjectIssue] references, the same
  /// shape `Mission.dependencies` uses and for the same reason: an issue a
  /// project no longer tracks must not leave a dangling reference.
  final List<String> dependencies;

  /// The optimistic-concurrency counter the real gateway assigns
  /// (`CodexBridge` `issues.revision`) — the same role `LiveSession.revision`
  /// plays for a session. Defaults to `1` because `MockIssueRepository`'s
  /// fixtures are never written back and have no server-assigned counter to
  /// carry; a real load always overwrites this with the value the gateway
  /// sent. Callers of a future update path send it back as `If-Match`.
  final int revision;

  /// Every recorded change, oldest first — #30's "changes preserve history"
  /// acceptance criterion, the same append-only shape
  /// `Mission.timeline`/`Decision.auditTrail` use for their own entities.
  /// Built by [describeIssueChanges] (`issue_change_summary.dart`) and
  /// appended by the repository that applies the write —
  /// `MockIssueRepository` keeps it in memory across a session;
  /// `HttpIssueRepository` carries forward only what the gateway itself
  /// sends back (`history` is not yet part of CodexBridge issue #8's wire
  /// contract, so a real issue's history starts empty here until the
  /// gateway grows one — `not validated: server-persisted issue history`).
  final List<IssueHistoryEvent> history;

  /// An issue the operator needs to act on — #29's "blocked indicators".
  /// Card and detail rendering pair this with an icon and the
  /// [IssueStatus.blocked] label in text, never conveyed by color alone.
  bool get isBlocked => status == IssueStatus.blocked;
}
