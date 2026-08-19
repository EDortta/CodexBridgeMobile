import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_tokens.dart';
import '../../../core/design/operational_text_theme.dart';
import '../../../core/format/relative_moment.dart';
import '../../../core/navigation/app_destinations.dart';
import '../../../core/presentation/async_state_view.dart';
import '../../../core/presentation/filter_menu_button.dart';
import '../../../core/presentation/inline_badge.dart';
import '../domain/live_session.dart';
import '../domain/mission.dart';
import '../domain/mission_risk.dart';
import '../domain/mission_stage.dart';
import '../domain/mission_state.dart';
import 'live_session_providers.dart';
import 'mission_providers.dart';
import 'session_card.dart';

/// The Work destination: the operator's current missions.
///
/// #27's list/filter UI: project, stage, risk and state filters that
/// combine (`filterMissions`), and each card showing owner, stage/risk
/// badges, progress, elapsed time, latest event and — when
/// `Mission.needsIntervention` — an explicit "Needs your attention" banner,
/// never conveyed by the card's red border alone.
class WorkScreen extends ConsumerWidget {
  const WorkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(AppDestination.work.label)),
      body: AsyncStateView<List<Mission>>(
        value: ref.watch(missionsProvider),
        data: (BuildContext context, List<Mission> missions) {
          return _WorkBody(missions: missions);
        },
      ),
    );
  }
}

class _WorkBody extends ConsumerWidget {
  const _WorkBody({required this.missions});

  final List<Mission> missions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? projectId = ref.watch(missionProjectFilterProvider);
    final MissionStage? stage = ref.watch(missionStageFilterProvider);
    final MissionRisk? risk = ref.watch(missionRiskFilterProvider);
    final MissionState? state = ref.watch(missionStateFilterProvider);
    final DateTime now = ref.watch(appClockProvider)();

    final List<Mission> filtered = filterMissions(
      missions,
      projectId: projectId,
      stage: stage,
      risk: risk,
      state: state,
    );
    final List<String> projectIds =
        missions.map((Mission m) => m.projectId).toSet().toList()..sort();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            FilterMenuButton<String?>(
              key: const Key('missionProjectFilter'),
              icon: AppIcons.projects,
              selected: projectId,
              options: <String?>[null, ...projectIds],
              labelOf: (String? p) => p ?? 'Any project',
              onSelected: (String? value) =>
                  ref.read(missionProjectFilterProvider.notifier).state = value,
            ),
            FilterMenuButton<MissionStage?>(
              key: const Key('missionStageFilter'),
              icon: Icons.timeline_rounded,
              selected: stage,
              options: const <MissionStage?>[null, ...MissionStage.values],
              labelOf: (MissionStage? s) => s?.label ?? 'Any stage',
              onSelected: (MissionStage? value) =>
                  ref.read(missionStageFilterProvider.notifier).state = value,
            ),
            FilterMenuButton<MissionRisk?>(
              key: const Key('missionRiskFilter'),
              icon: Icons.shield_outlined,
              selected: risk,
              options: const <MissionRisk?>[null, ...MissionRisk.values],
              labelOf: (MissionRisk? r) => r?.label ?? 'Any risk',
              onSelected: (MissionRisk? value) =>
                  ref.read(missionRiskFilterProvider.notifier).state = value,
            ),
            FilterMenuButton<MissionState?>(
              key: const Key('missionStateFilter'),
              icon: AppIcons.status,
              selected: state,
              options: const <MissionState?>[null, ...MissionState.values],
              labelOf: (MissionState? s) => s?.label ?? 'Any state',
              onSelected: (MissionState? value) =>
                  ref.read(missionStateFilterProvider.notifier).state = value,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (missions.isEmpty)
          const _EmptyMissionsView(
            message: 'No missions yet.',
            showClearAction: false,
          )
        else if (filtered.isEmpty)
          const _EmptyMissionsView(
            message: 'No missions match your filters.',
            showClearAction: true,
          )
        else
          for (final Mission mission in filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _MissionCard(mission: mission, now: now),
            ),
        const SizedBox(height: AppSpacing.lg),
        const _LiveSessionsSection(),
      ],
    );
  }
}

class _EmptyMissionsView extends ConsumerWidget {
  const _EmptyMissionsView({
    required this.message,
    required this.showClearAction,
  });

  final String message;
  final bool showClearAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              AppIcons.work,
              size: 40,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            if (showClearAction) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () {
                  ref.read(missionProjectFilterProvider.notifier).state = null;
                  ref.read(missionStageFilterProvider.notifier).state = null;
                  ref.read(missionRiskFilterProvider.notifier).state = null;
                  ref.read(missionStateFilterProvider.notifier).state = null;
                },
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
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
  const _MissionCard({required this.mission, required this.now});

  final Mission mission;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final OperationalTextTheme operationalText = theme
        .extension<OperationalTextTheme>()!;
    final bool needsIntervention = mission.needsIntervention;
    final Color accent = needsIntervention
        ? theme.colorScheme.error
        : theme.colorScheme.outlineVariant;

    return Container(
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(color: accent, width: needsIntervention ? 2 : 1),
          borderRadius: AppRadius.card,
        ),
      ),
      child: InkWell(
        borderRadius: AppRadius.card,
        onTap: () => context.go(AppDestination.work.detailPath),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (needsIntervention)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.error_rounded,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      Text(
                        'Needs your attention',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              Icon(AppIcons.terminal, color: theme.colorScheme.primary),
              const SizedBox(height: AppSpacing.md),
              Text(mission.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text('Terminal móvel', style: operationalText.metadata),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xxs,
                children: <Widget>[
                  InlineBadge(icon: Icons.person_outline_rounded, text: mission.owner),
                  InlineBadge(icon: Icons.timeline_rounded, text: mission.stage.label),
                  InlineBadge(icon: Icons.shield_outlined, text: mission.risk.label),
                  InlineBadge(icon: AppIcons.status, text: mission.state.label),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              LinearProgressIndicator(value: mission.progress),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${(mission.progress * 100).round()}% · Started ${RelativeMoment.describe(mission.startedAt, now: now)}',
                style: operationalText.metadata,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(mission.latestEvent, style: theme.textTheme.bodyMedium),
              if (mission.blockedReason case final String reason?) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  reason,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
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
