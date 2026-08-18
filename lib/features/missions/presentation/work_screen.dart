import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_tokens.dart';
import '../../../core/design/operational_text_theme.dart';
import '../../../core/format/utc_moment.dart';
import '../../../core/navigation/app_destinations.dart';
import '../../../core/presentation/async_state_view.dart';
import '../domain/mission.dart';
import 'mission_providers.dart';
import '../domain/live_session.dart';
import '../domain/live_session_repository.dart';
import 'live_session_providers.dart';

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
                          child: _SessionCard(
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

class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.session, required this.busy});

  final LiveSession session;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final OperationalTextTheme operationalText = theme
        .extension<OperationalTextTheme>()!;
    final bool needsIntervention =
        session.state == LiveSessionState.awaitingApproval;

    return Container(
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: needsIntervention
                ? theme.colorScheme.error
                : theme.colorScheme.outlineVariant,
            width: needsIntervention ? 2 : 1,
          ),
          borderRadius: AppRadius.card,
        ),
      ),
      child: InkWell(
        borderRadius: AppRadius.card,
        onTap: () => context.go(
          Uri(
            path: AppDestination.work.detailPath,
            queryParameters: <String, String>{'session': session.id},
          ).toString(),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (needsIntervention)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.error_rounded,
                        color: theme.colorScheme.error,
                        size: 18,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Needs your approval',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(session.projectId, style: theme.textTheme.titleMedium),
                  ),
                  Text(session.state.label, style: operationalText.metadata),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(session.instruction, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.sm),
              Text('Executor ${session.executorId}', style: operationalText.code),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Created ${UtcMoment.minute(session.createdAt)}',
                style: operationalText.metadata,
              ),
              if (session.lastError case final String error?) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  error,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  if (session.canPause)
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => unawaited(
                              runSessionControlAction(
                                context,
                                ref,
                                session.id,
                                LiveSessionControlAction.pause,
                              ),
                            ),
                      child: const Text('Pause'),
                    ),
                  if (session.canResume)
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => unawaited(
                              runSessionControlAction(
                                context,
                                ref,
                                session.id,
                                LiveSessionControlAction.resume,
                              ),
                            ),
                      child: const Text('Resume'),
                    ),
                  if (session.canRestart)
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => unawaited(
                              runSessionControlAction(
                                context,
                                ref,
                                session.id,
                                LiveSessionControlAction.restart,
                              ),
                            ),
                      child: const Text('Restart'),
                    ),
                  if (session.canStop)
                    FilledButton.tonal(
                      onPressed: busy
                          ? null
                          : () => unawaited(
                              runSessionControlAction(
                                context,
                                ref,
                                session.id,
                                LiveSessionControlAction.stop,
                              ),
                            ),
                      child: Text(busy ? 'Sending…' : 'Stop'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
