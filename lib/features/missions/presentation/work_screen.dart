import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_tokens.dart';
import '../../../core/design/operational_text_theme.dart';
import '../../../core/navigation/app_destinations.dart';
import '../../../core/presentation/async_state_view.dart';
import '../domain/mission.dart';
import 'mission_providers.dart';

/// The Work destination: the operator's current missions.
class WorkScreen extends ConsumerWidget {
  const WorkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(AppDestination.work.label)),
      body: AsyncStateView<List<Mission>>(
        value: ref.watch(missionsProvider),
        data: (BuildContext context, List<Mission> missions) {
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: missions.length,
            itemBuilder: (BuildContext context, int index) {
              return _MissionCard(mission: missions[index]);
            },
          );
        },
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final OperationalTextTheme operationalText = theme
        .extension<OperationalTextTheme>()!;

    return Card(
      elevation: AppElevation.card,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      child: InkWell(
        borderRadius: AppRadius.card,
        onTap: () => context.go(AppDestination.work.detailPath),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(AppIcons.terminal, color: theme.colorScheme.primary),
              const SizedBox(height: AppSpacing.md),
              Text(mission.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text('Terminal móvel', style: operationalText.metadata),
              const SizedBox(height: AppSpacing.lg),
              Text(mission.id, style: operationalText.code),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Icon(
                    AppIcons.status,
                    color: theme.colorScheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text('[ready] ${mission.status}', style: operationalText.log),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
