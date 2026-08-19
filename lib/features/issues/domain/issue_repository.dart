import 'project_issue.dart';

abstract interface class IssueRepository {
  Future<List<ProjectIssue>> loadIssues();
}
