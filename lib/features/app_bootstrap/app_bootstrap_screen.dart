import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/presentation/async_state_view.dart';
import '../../core/design/app_tokens.dart';
import '../../core/design/operational_text_theme.dart';
import '../missions/domain/mission.dart';
import '../missions/presentation/mission_providers.dart';

class AppBootstrapScreen extends ConsumerWidget {
  const AppBootstrapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncStateView<List<Mission>>(
      value: ref.watch(missionsProvider),
      data: (BuildContext context, List<Mission> missions) {
        return _MissionBootstrapCard(mission: missions.first);
      },
    );
  }
}

class _MissionBootstrapCard extends StatelessWidget {
  const _MissionBootstrapCard({required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final OperationalTextTheme operationalText = theme
        .extension<OperationalTextTheme>()!;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Card(
              elevation: AppElevation.card,
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
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
                        Text(
                          '[ready] ${mission.status}',
                          style: operationalText.log,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
