import 'issue_status.dart';
import 'project_issue.dart';

/// A planning-level grouping of [ProjectIssue]s — issue #29's "Epic view",
/// Epic #6's own unit ("Epics, Issues e planejamento").
///
/// [blockedReason] is meaningful only when [status] is
/// [IssueStatus.blocked] — the same convention `Mission.blockedReason`
/// documents, kept here as a doc comment rather than a `copyWith`-enforced
/// invariant because nothing in #29's scope transitions an [Epic]'s status;
/// this browser reads, it does not act.
class Epic {
  const Epic({
    required this.id,
    required this.projectId,
    required this.title,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.summary = '',
    this.blockedReason,
    this.issueIds = const <String>[],
  });

  final String id;
  final String projectId;
  final String title;
  final IssueStatus status;
  final IssuePriority priority;
  final DateTime createdAt;

  /// What this epic is trying to achieve — shown on the detail screen's
  /// "full context" (#29's acceptance criterion), empty for an epic only
  /// ever seen through the list card.
  final String summary;

  /// Why [status] is [IssueStatus.blocked] — null otherwise.
  final String? blockedReason;

  /// Ids of the [ProjectIssue]s this epic groups — plain strings, not
  /// [ProjectIssue] references, the same "foreign id, not an object graph"
  /// shape `Mission.relatedDecisionIds` uses.
  final List<String> issueIds;

  /// An epic the operator needs to act on — #29's "blocked indicators".
  bool get isBlocked => status == IssueStatus.blocked;
}
