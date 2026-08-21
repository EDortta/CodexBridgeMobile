import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_issue_repository.dart';
import '../domain/epic.dart';
import '../domain/issue_repository.dart';
import '../domain/issue_status.dart';
import '../domain/project_issue.dart';

final Provider<IssueRepository> issueRepositoryProvider =
    Provider<IssueRepository>((Ref ref) => MockIssueRepository());

final FutureProvider<List<ProjectIssue>> issuesProvider =
    FutureProvider<List<ProjectIssue>>((Ref ref) async {
      return ref.watch(issueRepositoryProvider).loadIssues();
    });

/// Every epic, every project — #29's Epic view filters from this.
final FutureProvider<List<Epic>> epicsProvider = FutureProvider<List<Epic>>((
  Ref ref,
) async {
  return ref.watch(issueRepositoryProvider).loadEpics();
});

/// A single issue with its full context — `autoDispose` because the detail
/// screen is the only consumer, the same reasoning `decisionDetailProvider`
/// (`features/decisions/`) and `missionDetailProvider` (`features/missions/`)
/// document.
final AutoDisposeFutureProviderFamily<ProjectIssue, String> issueDetailProvider =
    FutureProvider.autoDispose.family<ProjectIssue, String>((
      Ref ref,
      String issueId,
    ) async {
      return ref.watch(issueRepositoryProvider).loadIssue(issueId);
    });

/// A single epic with its full context — same `autoDispose` reasoning as
/// [issueDetailProvider].
final AutoDisposeFutureProviderFamily<Epic, String> epicDetailProvider =
    FutureProvider.autoDispose.family<Epic, String>((Ref ref, String epicId) async {
      return ref.watch(issueRepositoryProvider).loadEpic(epicId);
    });

// Filter state — one pair per view (`EpicsScreen`, `IssuesScreen`), the same
// "UI-only bucketing, not a domain concept" reasoning
// `decisionUrgencyFilterProvider` (`features/decisions/`) documents. Kept
// separate per view rather than shared, since #29 calls the two views
// "distinct" and a status/priority pick on one should not silently narrow
// the other when the operator switches.
final StateProvider<IssueStatus?> epicStatusFilterProvider =
    StateProvider<IssueStatus?>((Ref ref) => null);

final StateProvider<IssuePriority?> epicPriorityFilterProvider =
    StateProvider<IssuePriority?>((Ref ref) => null);

final StateProvider<IssueStatus?> issueStatusFilterProvider =
    StateProvider<IssueStatus?>((Ref ref) => null);

final StateProvider<IssuePriority?> issuePriorityFilterProvider =
    StateProvider<IssuePriority?>((Ref ref) => null);
