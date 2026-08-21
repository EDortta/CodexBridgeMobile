import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/design/app_tokens.dart';
import '../core/navigation/app_destinations.dart';
import '../features/issues/presentation/epic_detail_screen.dart';
import '../features/issues/presentation/epics_screen.dart';
import '../features/issues/presentation/issue_detail_screen.dart';
import '../features/issues/presentation/issues_screen.dart';
import '../features/missions/presentation/mission_detail_screen.dart';
import '../features/missions/presentation/work_session_detail_screen.dart';
import 'project_dashboard_screen.dart';

/// Placeholder detail route nested inside a destination's own navigator.
///
/// It exists so each destination has real navigation state to preserve across
/// destination switches; the real detail content lands with each feature.
class DestinationDetailScreen extends StatelessWidget {
  const DestinationDetailScreen({required this.destination, super.key});

  final AppDestination destination;

  @override
  Widget build(BuildContext context) {
    final Map<String, String> queryParameters =
        GoRouterState.of(context).uri.queryParameters;
    final String? sessionId = queryParameters['session'];
    final String? missionId = queryParameters['mission'];
    final String? projectId = queryParameters['project'];
    final String? epicsProjectId = queryParameters['epics'];
    final String? issuesProjectId = queryParameters['issues'];
    final String? epicId = queryParameters['epic'];
    final String? issueId = queryParameters['issue'];
    final ThemeData theme = Theme.of(context);

    if (destination == AppDestination.work && sessionId != null && sessionId.isNotEmpty) {
      return WorkSessionDetailScreen(sessionId: sessionId);
    }
    if (destination == AppDestination.work && missionId != null && missionId.isNotEmpty) {
      return MissionDetailScreen(missionId: missionId);
    }
    if (destination == AppDestination.projects && projectId != null && projectId.isNotEmpty) {
      return ProjectDashboardScreen(projectId: projectId);
    }
    // #29's Epic and Issue views: distinct screens, both project-scoped and
    // both reached from the Projects branch — the same query-param dispatch
    // `mission`/`session` already use under `work`.
    if (destination == AppDestination.projects &&
        epicsProjectId != null &&
        epicsProjectId.isNotEmpty) {
      return EpicsScreen(projectId: epicsProjectId);
    }
    if (destination == AppDestination.projects &&
        issuesProjectId != null &&
        issuesProjectId.isNotEmpty) {
      return IssuesScreen(projectId: issuesProjectId);
    }
    if (destination == AppDestination.projects && epicId != null && epicId.isNotEmpty) {
      return EpicDetailScreen(epicId: epicId);
    }
    if (destination == AppDestination.projects && issueId != null && issueId.isNotEmpty) {
      return IssueDetailScreen(issueId: issueId);
    }

    return Scaffold(
      appBar: AppBar(title: Text('${destination.label} detail')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            '${destination.label} detail placeholder',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
