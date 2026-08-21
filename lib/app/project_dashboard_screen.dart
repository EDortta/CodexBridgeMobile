import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/design/app_tokens.dart';
import '../core/format/relative_moment.dart';
import '../core/format/utc_moment.dart';
import '../core/navigation/app_destinations.dart';
import '../core/navigation/app_routes.dart';
import '../features/activity/domain/activity_entry.dart';
import '../features/activity/presentation/activity_providers.dart';
import '../features/artifacts/domain/artifact.dart';
import '../features/artifacts/presentation/artifact_providers.dart';
import '../features/decisions/domain/decision.dart';
import '../features/decisions/presentation/decision_providers.dart';
import '../features/issues/domain/project_issue.dart';
import '../features/issues/presentation/issue_providers.dart';
import '../features/missions/domain/live_session.dart';
import '../features/missions/domain/mission.dart';
import '../features/missions/presentation/live_session_providers.dart';
import '../features/missions/presentation/mission_providers.dart';
import '../features/missions/presentation/session_card.dart';
import '../features/projects/domain/project_health.dart';
import '../features/projects/domain/project_summary.dart';
import '../features/projects/presentation/project_health_presentation.dart';
import '../features/projects/presentation/project_providers.dart';

/// The project operational dashboard (#24): health, current mission,
/// sessions, priority issues, pending decisions, recent artifacts and
/// activity — one grouped `Card` per section, each with its own
/// loading/error handling, so one section failing does not blank the rest
/// (the same reasoning `work_session_detail_screen.dart` already applies
/// per-`Card`).
///
/// Lives in `lib/app/`, not a feature, because it imports across `projects`,
/// `missions`, `decisions`, `issues`, `artifacts` and `activity` —
/// `docs/architecture/state-architecture.md` reserves that to `app/`, the
/// same reason `destination_detail_screen.dart` already imports
/// `WorkSessionDetailScreen` from `features/missions/presentation/`.
class ProjectDashboardScreen extends ConsumerWidget {
  const ProjectDashboardScreen({required this.projectId, super.key});

  final String projectId;

  /// A pending decision older than this is marked stale.
  static const Duration _decisionStaleThreshold = Duration(hours: 24);

  /// An artifact or activity entry older than this is marked stale.
  static const Duration _dataStaleThreshold = Duration(days: 7);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ProjectSummary?> project = ref.watch(
      projectByIdProvider(projectId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(project.valueOrNull?.name ?? projectId),
        actions: <Widget>[
          IconButton(
            onPressed: () {
              ref.invalidate(projectsProvider);
              ref.invalidate(missionsProvider);
              ref.invalidate(remoteSessionsProvider);
              ref.invalidate(issuesProvider);
              ref.invalidate(pendingDecisionsProvider);
              ref.invalidate(artifactsProvider);
              ref.invalidate(activityProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh project',
          ),
        ],
      ),
      body: project.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object _, StackTrace _) =>
            const Center(child: Text('Unable to load this project.')),
        data: (ProjectSummary? summary) {
          if (summary == null) {
            return _ProjectNotFoundView(projectId: projectId);
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: <Widget>[
              _HealthHeaderCard(summary: summary),
              const SizedBox(height: AppSpacing.md),
              _CurrentMissionCard(projectId: projectId),
              const SizedBox(height: AppSpacing.md),
              _SessionsCard(projectId: projectId),
              const SizedBox(height: AppSpacing.md),
              _PriorityIssuesCard(projectId: projectId),
              const SizedBox(height: AppSpacing.md),
              _PendingDecisionsCard(projectId: projectId),
              const SizedBox(height: AppSpacing.md),
              _RecentArtifactsCard(projectId: projectId),
              const SizedBox(height: AppSpacing.md),
              _RecentActivityCard(projectId: projectId),
            ],
          );
        },
      ),
    );
  }
}

class _ProjectNotFoundView extends StatelessWidget {
  const _ProjectNotFoundView({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              AppIcons.projects,
              size: 40,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Project "$projectId" was not found.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// A section's `Card` shell: icon, title, an optional tappable header
/// (renders a chevron when it links somewhere), and a body the section
/// supplies. Shared by every section below so "grouped, not one long list"
/// (#24's acceptance criterion) has one implementation, not seven.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.onHeaderTap,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final VoidCallback? onHeaderTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      elevation: AppElevation.card,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            InkWell(
              onTap: onHeaderTap,
              child: Row(
                children: <Widget>[
                  Icon(icon, color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleLarge),
                  ),
                  if (onHeaderTap != null)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.outline,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      message,
      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
    );
  }
}

/// A section list item marked stale (icon + muted text, never color alone)
/// once [moment] is older than [threshold] as of [now]. Shared by the
/// pending-decisions, recent-artifacts and recent-activity sections.
class _StaleMarkedListTile extends StatelessWidget {
  const _StaleMarkedListTile({
    required this.title,
    required this.moment,
    required this.now,
    required this.threshold,
    required this.onTap,
  });

  final String title;
  final DateTime moment;
  final DateTime now;
  final Duration threshold;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool stale = RelativeMoment.isStale(
      moment,
      now: now,
      threshold: threshold,
    );
    final Color mutedColor = theme.colorScheme.outline;

    return InkWell(
      borderRadius: AppRadius.card,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.xxs),
            Row(
              children: <Widget>[
                if (stale) ...<Widget>[
                  Icon(AppIcons.stale, size: 14, color: mutedColor),
                  const SizedBox(width: AppSpacing.xxs),
                ],
                Text(
                  RelativeMoment.describe(moment, now: now),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: stale ? mutedColor : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthHeaderCard extends StatelessWidget {
  const _HealthHeaderCard({required this.summary});

  final ProjectSummary summary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ProjectHealth health = summary.health;
    final Color accent = projectHealthAccent(theme, health);
    final IconData icon = projectHealthIcon(health);

    return Card(
      elevation: AppElevation.card,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(summary.name, style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: <Widget>[
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  health.label,
                  style: theme.textTheme.titleMedium?.copyWith(color: accent),
                ),
              ],
            ),
            if (summary.attentionSummary case final String reason?) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(reason, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _CurrentMissionCard extends ConsumerWidget {
  const _CurrentMissionCard({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Mission>> missions = ref.watch(missionsProvider);
    final ThemeData theme = Theme.of(context);

    return _SectionCard(
      icon: AppIcons.work,
      title: 'Current mission',
      onHeaderTap: () => context.go(AppDestination.work.path),
      child: missions.when(
        loading: () => const _SectionLoading(),
        error: (Object _, StackTrace _) =>
            const _SectionError(message: 'Unable to load missions.'),
        data: (List<Mission> all) {
          final Mission? mission = all
              .cast<Mission?>()
              .firstWhere((Mission? m) => m!.projectId == projectId, orElse: () => null);
          if (mission == null) {
            return Text('No active mission.', style: theme.textTheme.bodyMedium);
          }
          return InkWell(
            borderRadius: AppRadius.card,
            // Carries `?mission=<id>` the same way `_MissionCard`
            // (`work_screen.dart`, #28) does, so tapping the operator's
            // current mission from the dashboard lands on that mission's
            // own detail screen — not just the general Work destination,
            // which would silently drop the mission this card was about.
            onTap: () => context.go(
              Uri(
                path: AppDestination.work.detailPath,
                queryParameters: <String, String>{'mission': mission.id},
              ).toString(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(mission.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xxs),
                Text(mission.status, style: theme.textTheme.bodyMedium),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SessionsCard extends ConsumerWidget {
  const _SessionsCard({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<RemoteSessionsState> value = ref.watch(remoteSessionsProvider);
    final ThemeData theme = Theme.of(context);

    return _SectionCard(
      icon: AppIcons.terminal,
      title: 'Sessions',
      child: value.when(
        loading: () => const _SectionLoading(),
        error: (Object _, StackTrace _) =>
            const _SectionError(message: 'Unable to load sessions.'),
        data: (RemoteSessionsState state) {
          final List<LiveSession> sessions = state.sessions
              .where((LiveSession s) => s.projectId == projectId)
              .toList(growable: false);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (state.error case final String error?)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    error,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              if (sessions.isEmpty)
                Text(
                  state.information ?? 'No sessions for this project.',
                  style: theme.textTheme.bodyMedium,
                )
              else
                for (final LiveSession session in sessions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: SessionCard(
                      session: session,
                      busy: state.pending.contains(session.id),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _PriorityIssuesCard extends ConsumerWidget {
  const _PriorityIssuesCard({required this.projectId});

  final String projectId;

  static const int _maxShown = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ProjectIssue>> value = ref.watch(issuesProvider);
    final ThemeData theme = Theme.of(context);

    return _SectionCard(
      icon: AppIcons.issues,
      title: 'Priority issues',
      // Carries `?issues=<id>` into #29's full Issues browser for this
      // project — the same "carry the id, not just the destination"
      // reasoning `_CurrentMissionCard.onTap` (#28) already applies to its
      // own header tap target.
      onHeaderTap: () => context.go(
        Uri(
          path: AppDestination.projects.detailPath,
          queryParameters: <String, String>{'issues': projectId},
        ).toString(),
      ),
      child: value.when(
        loading: () => const _SectionLoading(),
        error: (Object _, StackTrace _) =>
            const _SectionError(message: 'Unable to load issues.'),
        data: (List<ProjectIssue> all) {
          final List<ProjectIssue> issues =
              all.where((ProjectIssue i) => i.projectId == projectId).toList()
                ..sort(
                  (ProjectIssue a, ProjectIssue b) =>
                      a.priority.index.compareTo(b.priority.index),
                );
          if (issues.isEmpty) {
            return Text(
              'No open issues for this project.',
              style: theme.textTheme.bodyMedium,
            );
          }
          final List<ProjectIssue> shown = issues.take(_maxShown).toList(growable: false);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final ProjectIssue issue in shown) _IssueListTile(issue: issue),
              if (issues.length > shown.length)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    '+${issues.length - shown.length} more',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _IssueListTile extends StatelessWidget {
  const _IssueListTile({required this.issue});

  final ProjectIssue issue;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool urgent =
        issue.priority == IssuePriority.critical || issue.priority == IssuePriority.high;
    final Color accent = urgent ? theme.colorScheme.error : theme.colorScheme.outline;

    return InkWell(
      borderRadius: AppRadius.card,
      onTap: () => showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) => _IssueDialog(issue: issue),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: <Widget>[
            Icon(AppIcons.issues, size: 16, color: accent),
            const SizedBox(width: AppSpacing.xxs),
            Expanded(child: Text(issue.title, style: theme.textTheme.bodyMedium)),
            Text(
              issue.priority.label,
              style: theme.textTheme.labelMedium?.copyWith(color: accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueDialog extends StatelessWidget {
  const _IssueDialog({required this.issue});

  final ProjectIssue issue;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(issue.title),
      content: Text(
        'Priority: ${issue.priority.label}\nProject: ${issue.projectId}',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _PendingDecisionsCard extends ConsumerWidget {
  const _PendingDecisionsCard({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Decision>> value = ref.watch(pendingDecisionsProvider);
    final DateTime now = ref.watch(appClockProvider)();
    final ThemeData theme = Theme.of(context);

    return _SectionCard(
      icon: AppIcons.decisions,
      title: 'Pending decisions',
      onHeaderTap: () => context.go(AppRoutes.decisions),
      child: value.when(
        loading: () => const _SectionLoading(),
        error: (Object _, StackTrace _) =>
            const _SectionError(message: 'Unable to load decisions.'),
        data: (List<Decision> all) {
          final List<Decision> decisions =
              all.where((Decision d) => d.projectId == projectId).toList(growable: false);
          if (decisions.isEmpty) {
            return Text(
              'No pending decisions for this project.',
              style: theme.textTheme.bodyMedium,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final Decision decision in decisions)
                _StaleMarkedListTile(
                  title: decision.title,
                  moment: decision.requestedAt,
                  now: now,
                  threshold: ProjectDashboardScreen._decisionStaleThreshold,
                  onTap: () => context.go(AppRoutes.decisions),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RecentArtifactsCard extends ConsumerWidget {
  const _RecentArtifactsCard({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Artifact>> value = ref.watch(artifactsProvider);
    final DateTime now = ref.watch(appClockProvider)();
    final ThemeData theme = Theme.of(context);

    return _SectionCard(
      icon: AppIcons.artifacts,
      title: 'Recent artifacts',
      child: value.when(
        loading: () => const _SectionLoading(),
        error: (Object _, StackTrace _) =>
            const _SectionError(message: 'Unable to load artifacts.'),
        data: (List<Artifact> all) {
          final List<Artifact> artifacts =
              all.where((Artifact a) => a.projectId == projectId).toList()
                ..sort((Artifact a, Artifact b) => b.createdAt.compareTo(a.createdAt));
          if (artifacts.isEmpty) {
            return Text(
              'No recent artifacts for this project.',
              style: theme.textTheme.bodyMedium,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final Artifact artifact in artifacts)
                _StaleMarkedListTile(
                  title: artifact.name,
                  moment: artifact.createdAt,
                  now: now,
                  threshold: ProjectDashboardScreen._dataStaleThreshold,
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (BuildContext dialogContext) =>
                        _ArtifactDialog(artifact: artifact),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ArtifactDialog extends StatelessWidget {
  const _ArtifactDialog({required this.artifact});

  final Artifact artifact;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(artifact.name),
      content: Text(
        'Project: ${artifact.projectId}\n'
        'Created: ${UtcMoment.minute(artifact.createdAt)}',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _RecentActivityCard extends ConsumerWidget {
  const _RecentActivityCard({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ActivityEntry>> value = ref.watch(activityProvider);
    final DateTime now = ref.watch(appClockProvider)();
    final ThemeData theme = Theme.of(context);

    return _SectionCard(
      icon: AppIcons.activity,
      title: 'Recent activity',
      child: value.when(
        loading: () => const _SectionLoading(),
        error: (Object _, StackTrace _) =>
            const _SectionError(message: 'Unable to load activity.'),
        data: (List<ActivityEntry> all) {
          final List<ActivityEntry> entries =
              all.where((ActivityEntry e) => e.projectId == projectId).toList()
                ..sort(
                  (ActivityEntry a, ActivityEntry b) =>
                      b.occurredAt.compareTo(a.occurredAt),
                );
          if (entries.isEmpty) {
            return Text(
              'No recent activity for this project.',
              style: theme.textTheme.bodyMedium,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final ActivityEntry entry in entries)
                _StaleMarkedListTile(
                  title: entry.description,
                  moment: entry.occurredAt,
                  now: now,
                  threshold: ProjectDashboardScreen._dataStaleThreshold,
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (BuildContext dialogContext) =>
                        _ActivityDialog(entry: entry),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ActivityDialog extends StatelessWidget {
  const _ActivityDialog({required this.entry});

  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(entry.description),
      content: Text(
        'Project: ${entry.projectId}\n'
        'Occurred: ${UtcMoment.minute(entry.occurredAt)}',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
