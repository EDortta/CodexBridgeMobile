import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_tokens.dart';
import '../../../core/design/operational_text_theme.dart';
import '../../../core/format/utc_moment.dart';
import '../../../core/navigation/app_destinations.dart';
import '../../../core/presentation/inline_badge.dart';
import '../domain/epic.dart';
import '../domain/issue_history_event.dart';
import '../domain/issue_repository.dart';
import '../domain/project_issue.dart';
import 'issue_providers.dart';

/// #29: full context for one issue — status, priority, assignee, labels,
/// dependencies and, when blocked, its cause always stated in text (never
/// only implied by the card's red border), plus a link back to its epic
/// when it has one.
class IssueDetailScreen extends ConsumerWidget {
  const IssueDetailScreen({required this.issueId, super.key});

  final String issueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ProjectIssue> detail = ref.watch(issueDetailProvider(issueId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Issue'),
        actions: <Widget>[
          // #30: only offered once the issue actually loaded — editing
          // needs its current `revision` for the stale-write guard, so
          // there is nothing to edit yet while `detail` is loading or
          // failed.
          if (detail.hasValue)
            IconButton(
              key: const Key('editIssueButton'),
              onPressed: () => context.go(
                Uri(
                  path: AppDestination.projects.detailPath,
                  queryParameters: <String, String>{'editIssue': issueId},
                ).toString(),
              ),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit issue',
            ),
          IconButton(
            onPressed: () {
              ref.invalidate(issueDetailProvider(issueId));
              ref.invalidate(issuesProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh issue',
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
        data: (ProjectIssue issue) => _IssueDetailBody(issue: issue),
      ),
    );
  }
}

String _errorMessage(Object error) {
  return switch (error) {
    IssueNotFoundException() => 'This issue could not be found.',
    _ => 'Unable to load this issue.',
  };
}

class _IssueDetailBody extends StatelessWidget {
  const _IssueDetailBody({required this.issue});

  final ProjectIssue issue;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        _SummaryCard(issue: issue),
        const SizedBox(height: AppSpacing.md),
        if (issue.dependencies.isNotEmpty) ...<Widget>[
          _BulletCard(title: 'Dependencies', items: issue.dependencies),
          const SizedBox(height: AppSpacing.md),
        ],
        if (issue.epicId case final String epicId?) ...<Widget>[
          _EpicLinkCard(epicId: epicId),
          const SizedBox(height: AppSpacing.md),
        ],
        // #30's "changes preserve history" — every recorded change, newest
        // first so the operator sees what just happened without scrolling.
        _HistoryCard(history: issue.history),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.history});

  final List<IssueHistoryEvent> history;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final OperationalTextTheme operationalText = theme
        .extension<OperationalTextTheme>()!;
    final List<IssueHistoryEvent> newestFirst = history.reversed.toList(growable: false);

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
                Icon(AppIcons.activity, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.xs),
                Text('History', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (newestFirst.isEmpty)
              Text('No recorded changes yet.', style: theme.textTheme.bodyMedium)
            else
              for (final IssueHistoryEvent event in newestFirst)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(event.description, style: theme.textTheme.bodyMedium),
                      Text(
                        '${event.actor} · ${UtcMoment.day(event.occurredAt)}',
                        style: operationalText.metadata,
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.issue});

  final ProjectIssue issue;

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
            Text(issue.title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xxs,
              children: <Widget>[
                InlineBadge(icon: AppIcons.status, text: issue.status.label),
                InlineBadge(
                  icon: Icons.priority_high_rounded,
                  text: issue.priority.label,
                ),
                InlineBadge(icon: Icons.person_outline_rounded, text: issue.assignee),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Project: ${issue.projectId}', style: operationalText.metadata),
            Text(
              'Created ${UtcMoment.day(issue.createdAt)}',
              style: operationalText.metadata,
            ),
            if (issue.summary.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(issue.summary, style: theme.textTheme.bodyLarge),
            ],
            if (issue.labels.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xxs,
                runSpacing: AppSpacing.xxs,
                children: <Widget>[
                  for (final String label in issue.labels) Chip(label: Text(label)),
                ],
              ),
            ],
            // A blocked issue always states its cause here, in text — never
            // conveyed by the list card's red border alone (#29's own
            // "blocked indicators" criterion).
            if (issue.blockedReason case final String reason?) ...<Widget>[
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

class _BulletCard extends StatelessWidget {
  const _BulletCard({required this.title, required this.items});

  final String title;
  final List<String> items;

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
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            for (final String item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                child: Text('• $item', style: theme.textTheme.bodyMedium),
              ),
          ],
        ),
      ),
    );
  }
}

class _EpicLinkCard extends ConsumerWidget {
  const _EpicLinkCard({required this.epicId});

  final String epicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<Epic>> allEpics = ref.watch(epicsProvider);

    return Card(
      elevation: AppElevation.card,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Epic', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            allEpics.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object _, StackTrace _) =>
                  Text('Unable to load the epic.', style: theme.textTheme.bodyMedium),
              data: (List<Epic> epics) {
                final Epic? epic = epics
                    .cast<Epic?>()
                    .firstWhere((Epic? e) => e!.id == epicId, orElse: () => null);
                return InkWell(
                  onTap: () => context.go(
                    Uri(
                      path: AppDestination.projects.detailPath,
                      queryParameters: <String, String>{'epic': epicId},
                    ).toString(),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(AppIcons.epics, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          epic?.title ?? epicId,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
