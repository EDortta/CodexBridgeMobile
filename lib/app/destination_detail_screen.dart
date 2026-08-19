import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/design/app_tokens.dart';
import '../core/navigation/app_destinations.dart';
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
    final String? projectId = queryParameters['project'];
    final ThemeData theme = Theme.of(context);

    if (destination == AppDestination.work && sessionId != null && sessionId.isNotEmpty) {
      return WorkSessionDetailScreen(sessionId: sessionId);
    }
    if (destination == AppDestination.projects && projectId != null && projectId.isNotEmpty) {
      return ProjectDashboardScreen(projectId: projectId);
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
