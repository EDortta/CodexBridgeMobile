import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_tokens.dart';
import '../../../core/design/operational_text_theme.dart';
import '../../../core/format/utc_moment.dart';
import '../../../core/navigation/app_destinations.dart';
import '../../../core/presentation/inline_badge.dart';
import '../domain/epic.dart';
import '../domain/issue_repository.dart';
import '../domain/project_issue.dart';
import 'issue_providers.dart';

/// #29: full context for one epic — summary, status, priority and, when
/// blocked, its cause always stated in text (never only implied by the
/// card's red border), plus the issues it groups, each a link into its own
/// `IssueDetailScreen` — the same "plain foreign id, resolved and linked out
/// on the detail screen" shape `MissionDetailScreen`'s related-decisions
/// card (`features/missions/`) already uses.
class EpicDetailScreen extends ConsumerWidget {
  const EpicDetailScreen({required this.epicId, super.key});

  final String epicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Epic> detail = ref.watch(epicDetailProvider(epicId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Epic'),
        actions: <Widget>[
          IconButton(
            onPressed: () {
              ref.invalidate(epicDetailProvider(epicId));
              ref.invalidate(epicsProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh epic',
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(_errorMessage(error), textAlign: TextAlign.center),
          ),
        ),
        data: (Epic epic) => _EpicDetailBody(epic: epic),
      ),
    );
  }
}

String _errorMessage(Object error) {
  return switch (error) {
    EpicNotFoundException() => 'This epic could not be found.',
    _ => 'Unable to load this epic.',
  };
}

class _EpicDetailBody extends StatelessWidget {
  const _EpicDetailBody({required this.epic});

  final Epic epic;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        _SummaryCard(epic: epic),
        const SizedBox(height: AppSpacing.md),
        _IssuesCard(epic: epic),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.epic});

  final Epic epic;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final OperationalTextTheme operationalText = theme
        .extension<OperationalTextTheme>()!;

    return Card(
      elevation: AppElevation.card,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(epic.title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xxs,
              children: <Widget>[
                InlineBadge(icon: AppIcons.status, text: epic.status.label),
                InlineBadge(
                  icon: Icons.priority_high_rounded,
                  text: epic.priority.label,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Project: ${epic.projectId}', style: operationalText.metadata),
            Text(
              'Created ${UtcMoment.day(epic.createdAt)}',
              style: operationalText.metadata,
            ),
            if (epic.summary.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(epic.summary, style: theme.textTheme.bodyLarge),
            ],
            // A blocked epic always states its cause here, in text — never
            // conveyed by the list card's red border alone (#29's own
            // "blocked indicators" criterion, same rule
            // `MissionDetailScreen`'s summary card follows).
            if (epic.blockedReason case final String reason?) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: AppRadius.card,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      AppIcons.blocked,
                      size: 18,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Blocked: $reason',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IssuesCard extends ConsumerWidget {
  const _IssuesCard({required this.epic});

  final Epic epic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<ProjectIssue>> allIssues = ref.watch(issuesProvider);

    return Card(
      elevation: AppElevation.card,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Issues', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            if (epic.issueIds.isEmpty)
              Text('No issues grouped under this epic yet.', style: theme.textTheme.bodyMedium)
            else
              allIssues.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (Object _, StackTrace _) =>
                    Text('Unable to load issues.', style: theme.textTheme.bodyMedium),
                data: (List<ProjectIssue> issues) {
                  final Map<String, ProjectIssue> byId = <String, ProjectIssue>{
                    for (final ProjectIssue issue in issues) issue.id: issue,
                  };
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (final String issueId in epic.issueIds)
                        _IssueLink(
                          issueId: issueId,
                          title: byId[issueId]?.title,
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

class _IssueLink extends StatelessWidget {
  const _IssueLink({required this.issueId, required this.title});

  final String issueId;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: () => context.go(
        Uri(
          path: AppDestination.projects.detailPath,
          queryParameters: <String, String>{'issue': issueId},
        ).toString(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: <Widget>[
            Icon(AppIcons.issues, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(title ?? issueId, style: theme.textTheme.bodyMedium),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
