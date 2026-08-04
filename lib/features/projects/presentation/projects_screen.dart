import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_tokens.dart';
import '../../../core/navigation/app_destinations.dart';
import '../../../core/presentation/async_state_view.dart';
import '../domain/project_summary.dart';
import 'project_providers.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(AppDestination.projects.label)),
      body: AsyncStateView<List<ProjectSummary>>(
        value: ref.watch(projectsProvider),
        data: (BuildContext context, List<ProjectSummary> projects) {
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            itemCount: projects.length,
            itemBuilder: (BuildContext context, int index) {
              final ProjectSummary project = projects[index];
              return ListTile(
                leading: const Icon(AppIcons.projects),
                title: Text(project.name),
                subtitle: Text(project.status),
                onTap: () => context.go(AppDestination.projects.detailPath),
              );
            },
          );
        },
      ),
    );
  }
}
