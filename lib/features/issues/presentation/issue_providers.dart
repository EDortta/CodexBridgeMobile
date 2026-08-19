import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_issue_repository.dart';
import '../domain/issue_repository.dart';
import '../domain/project_issue.dart';

final Provider<IssueRepository> issueRepositoryProvider =
    Provider<IssueRepository>((Ref ref) => MockIssueRepository());

final FutureProvider<List<ProjectIssue>> issuesProvider =
    FutureProvider<List<ProjectIssue>>((Ref ref) async {
      return ref.watch(issueRepositoryProvider).loadIssues();
    });
