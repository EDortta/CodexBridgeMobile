import 'project_summary.dart';

abstract interface class ProjectRepository {
  Future<List<ProjectSummary>> loadProjects();
}
