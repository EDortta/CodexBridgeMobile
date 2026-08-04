import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_project_repository.dart';
import '../domain/project_repository.dart';
import '../domain/project_summary.dart';

final Provider<ProjectRepository> projectRepositoryProvider =
    Provider<ProjectRepository>((Ref ref) => MockProjectRepository());

final FutureProvider<List<ProjectSummary>> projectsProvider =
    FutureProvider<List<ProjectSummary>>((Ref ref) async {
      return ref.watch(projectRepositoryProvider).loadProjects();
    });
