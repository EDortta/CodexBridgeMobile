import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_tokens.dart';
import '../../../core/navigation/app_destinations.dart';
import '../../../core/presentation/async_state_view.dart';
import '../../../core/presentation/filter_menu_button.dart';
import '../../../core/presentation/inline_badge.dart';
import '../domain/issue_status.dart';
import '../domain/project_issue.dart';
import 'issue_filter.dart';
import 'issue_providers.dart';

/// #29's Issue view: every issue scoped to [projectId], with status and
/// priority filters that combine (`filterIssues`, pure and independently
/// tested), each card showing priority, status, assignee, labels and a
/// dependency count, and a blocked issue visually distinct the same way
/// `EpicsScreen` marks a blocked epic — never by color alone. Selecting an
/// issue opens `IssueDetailScreen`'s full context. The app bar's "View
/// epics" action reaches `EpicsScreen` for the same project.
class IssuesScreen extends ConsumerWidget {
  const IssuesScreen({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Issues'),
        actions: <Widget>[
          IconButton(
            key: const Key('viewEpicsButton'),
            icon: const Icon(AppIcons.epics),
            tooltip: 'View epics',
            onPressed: () => context.go(
              Uri(
                path: AppDestination.projects.detailPath,
                queryParameters: <String, String>{'epics': projectId},
              ).toString(),
            ),
          ),
          // #30: creation starts from this project's own Issue view, so the
          // new issue is scoped correctly without an extra project picker.
          IconButton(
            key: const Key('newIssueButton'),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New issue',
            onPressed: () => context.go(
              Uri(
                path: AppDestination.projects.detailPath,
                queryParameters: <String, String>{'newIssue': projectId},
              ).toString(),
            ),
          ),
        ],
      ),
      body: AsyncStateView<List<ProjectIssue>>(
        value: ref.watch(issuesProvider),
        data: (BuildContext context, List<ProjectIssue> issues) {
          return _IssueListBody(projectId: projectId, issues: issues);
        },
      ),
    );
  }
}

class _IssueListBody extends ConsumerWidget {
  const _IssueListBody({required this.projectId, required this.issues});

  final String projectId;
  final List<ProjectIssue> issues;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final IssueStatus? status = ref.watch(issueStatusFilterProvider);
    final IssuePriority? priority = ref.watch(issuePriorityFilterProvider);

    final List<ProjectIssue> filtered = filterIssues(
      issues,
      projectId: projectId,
      status: status,
      priority: priority,
    );
    final List<ProjectIssue> scoped = issues
        .where((ProjectIssue issue) => issue.projectId == projectId)
        .toList(growable: false);

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              FilterMenuButton<IssueStatus?>(
                key: const Key('issueStatusFilter'),
                icon: AppIcons.status,
                selected: status,
                options: const <IssueStatus?>[null, ...IssueStatus.values],
                labelOf: (IssueStatus? s) => s?.label ?? 'Any status',
                onSelected: (IssueStatus? value) =>
                    ref.read(issueStatusFilterProvider.notifier).state = value,
              ),
              FilterMenuButton<IssuePriority?>(
                key: const Key('issuePriorityFilter'),
                icon: Icons.priority_high_rounded,
                selected: priority,
                options: const <IssuePriority?>[null, ...IssuePriority.values],
                labelOf: (IssuePriority? p) => p?.label ?? 'Any priority',
                onSelected: (IssuePriority? value) =>
                    ref.read(issuePriorityFilterProvider.notifier).state = value,
              ),
            ],
          ),
        ),
        Expanded(
          child: scoped.isEmpty
              ? const _EmptyIssuesView(
                  message: 'No issues for this project.',
                  showClearAction: false,
                )
              : filtered.isEmpty
              ? const _EmptyIssuesView(
                  message: 'No issues match your filters.',
                  showClearAction: true,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _IssueCard(issue: filtered[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _EmptyIssuesView extends ConsumerWidget {
  const _EmptyIssuesView({required this.message, required this.showClearAction});

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
              AppIcons.issues,
              size: 40,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            if (showClearAction) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () {
                  ref.read(issueStatusFilterProvider.notifier).state = null;
                  ref.read(issuePriorityFilterProvider.notifier).state = null;
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

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.issue});

  final ProjectIssue issue;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isUrgent =
        issue.priority == IssuePriority.critical || issue.priority == IssuePriority.high;
    final Color accent = issue.isBlocked || isUrgent
        ? theme.colorScheme.error
        : theme.colorScheme.outlineVariant;

    return Container(
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(color: accent, width: issue.isBlocked ? 2 : 1),
          borderRadius: AppRadius.card,
        ),
      ),
      child: InkWell(
        borderRadius: AppRadius.card,
        onTap: () => context.go(
          Uri(
            path: AppDestination.projects.detailPath,
            queryParameters: <String, String>{'issue': issue.id},
          ).toString(),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (issue.isBlocked)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    children: <Widget>[
                      Icon(AppIcons.blocked, size: 16, color: theme.colorScheme.error),
                      const SizedBox(width: AppSpacing.xxs),
                      Text(
                        'Blocked',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              Text(issue.title, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xxs,
                children: <Widget>[
                  InlineBadge(icon: AppIcons.status, text: issue.status.label),
                  InlineBadge(
                    icon: Icons.priority_high_rounded,
                    text: issue.priority.label,
                  ),
                  InlineBadge(
                    icon: Icons.person_outline_rounded,
                    text: issue.assignee,
                  ),
                  if (issue.dependencies.isNotEmpty)
                    InlineBadge(
                      icon: Icons.link_rounded,
                      text: '${issue.dependencies.length} dependency(ies)',
                    ),
                ],
              ),
              if (issue.labels.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xxs,
                  runSpacing: AppSpacing.xxs,
                  children: <Widget>[
                    for (final String label in issue.labels)
                      Chip(
                        label: Text(label, style: theme.textTheme.labelSmall),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
