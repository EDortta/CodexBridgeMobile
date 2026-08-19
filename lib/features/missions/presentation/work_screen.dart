import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_tokens.dart';
import '../../../core/design/operational_text_theme.dart';
import '../../../core/navigation/app_destinations.dart';
import '../../../core/presentation/async_state_view.dart';
import '../domain/mission.dart';
import 'mission_providers.dart';
import '../domain/live_session.dart';
import 'live_session_providers.dart';
import 'session_card.dart';

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
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: <Widget>[
              ...missions.map((Mission mission) => _MissionCard(mission: mission)),
              const SizedBox(height: AppSpacing.lg),
              const _LiveSessionsSection(),
            ],
          );
        },
      ),
    );
  }
}

class _LiveSessionsSection extends ConsumerWidget {
  const _LiveSessionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<RemoteSessionsState> value = ref.watch(remoteSessionsProvider);
    final ThemeData theme = Theme.of(context);

    return Card(
      elevation: AppElevation.card,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(AppIcons.terminal, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('Live sessions', style: theme.textTheme.titleLarge),
                ),
                IconButton(
                  onPressed: () => unawaited(
                    ref.read(remoteSessionsProvider.notifier).refresh(),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh sessions',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            value.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (Object _, StackTrace _) =>
                  const Text('Unable to load live sessions.'),
              data: (RemoteSessionsState sessions) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (sessions.error case final String error?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(
                          error,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    if (sessions.sessions.isEmpty)
                      Text(
                        sessions.information ??
                            'No sessions are visible from this device.',
                        style: theme.textTheme.bodyMedium,
                      )
                    else
                      ...sessions.sessions.map<Widget>(
                        (LiveSession session) => Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.md),
                          child: SessionCard(
                            session: session,
                            busy: sessions.pending.contains(session.id),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
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
