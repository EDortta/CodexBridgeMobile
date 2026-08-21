import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_tokens.dart';
import '../../../core/navigation/app_destinations.dart';
import '../../../core/presentation/async_state_view.dart';
import '../../../core/presentation/filter_menu_button.dart';
import '../../../core/presentation/inline_badge.dart';
import '../domain/epic.dart';
import '../domain/issue_status.dart';
import '../domain/project_issue.dart';
import 'issue_filter.dart';
import 'issue_providers.dart';

/// #29's Epic view: every epic scoped to [projectId], with status and
/// priority filters that combine (`filterEpics`, pure and independently
/// tested) and a blocked epic visually distinct — never by color alone, an
/// explicit "Blocked" label always accompanies the red border, the same
/// convention `_MissionCard` (`features/missions/presentation/work_screen.dart`)
/// and `_DecisionCard` (`features/decisions/`) already follow. Selecting an
/// epic opens `EpicDetailScreen`'s full context (#29's acceptance
/// criterion). The app bar's "View issues" action reaches `IssuesScreen` for
/// the same project — #29 calls the two views "distinct", so each is its
/// own screen and its own filter state rather than two tabs sharing one.
class EpicsScreen extends ConsumerWidget {
  const EpicsScreen({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Epics'),
        actions: <Widget>[
          IconButton(
            key: const Key('viewIssuesButton'),
            icon: const Icon(AppIcons.issues),
            tooltip: 'View issues',
            onPressed: () => context.go(
              Uri(
                path: AppDestination.projects.detailPath,
                queryParameters: <String, String>{'issues': projectId},
              ).toString(),
            ),
          ),
        ],
      ),
      body: AsyncStateView<List<Epic>>(
        value: ref.watch(epicsProvider),
        data: (BuildContext context, List<Epic> epics) {
          return _EpicListBody(projectId: projectId, epics: epics);
        },
      ),
    );
  }
}

class _EpicListBody extends ConsumerWidget {
  const _EpicListBody({required this.projectId, required this.epics});

  final String projectId;
  final List<Epic> epics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final IssueStatus? status = ref.watch(epicStatusFilterProvider);
    final IssuePriority? priority = ref.watch(epicPriorityFilterProvider);

    final List<Epic> filtered = filterEpics(
      epics,
      projectId: projectId,
      status: status,
      priority: priority,
    );
    final List<Epic> scoped = epics
        .where((Epic epic) => epic.projectId == projectId)
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
                key: const Key('epicStatusFilter'),
                icon: AppIcons.status,
                selected: status,
                options: const <IssueStatus?>[null, ...IssueStatus.values],
                labelOf: (IssueStatus? s) => s?.label ?? 'Any status',
                onSelected: (IssueStatus? value) =>
                    ref.read(epicStatusFilterProvider.notifier).state = value,
              ),
              FilterMenuButton<IssuePriority?>(
                key: const Key('epicPriorityFilter'),
                icon: Icons.priority_high_rounded,
                selected: priority,
                options: const <IssuePriority?>[null, ...IssuePriority.values],
                labelOf: (IssuePriority? p) => p?.label ?? 'Any priority',
                onSelected: (IssuePriority? value) =>
                    ref.read(epicPriorityFilterProvider.notifier).state = value,
              ),
            ],
          ),
        ),
        Expanded(
          child: scoped.isEmpty
              ? const _EmptyEpicsView(
                  message: 'No epics for this project.',
                  showClearAction: false,
                )
              : filtered.isEmpty
              ? const _EmptyEpicsView(
                  message: 'No epics match your filters.',
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
                      child: _EpicCard(epic: filtered[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _EmptyEpicsView extends ConsumerWidget {
  const _EmptyEpicsView({required this.message, required this.showClearAction});

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
              AppIcons.epics,
              size: 40,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            if (showClearAction) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () {
                  ref.read(epicStatusFilterProvider.notifier).state = null;
                  ref.read(epicPriorityFilterProvider.notifier).state = null;
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

class _EpicCard extends StatelessWidget {
  const _EpicCard({required this.epic});

  final Epic epic;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isCritical = epic.priority == IssuePriority.critical;
    final Color accent = epic.isBlocked || isCritical
        ? theme.colorScheme.error
        : theme.colorScheme.outlineVariant;

    return Container(
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(color: accent, width: epic.isBlocked ? 2 : 1),
          borderRadius: AppRadius.card,
        ),
      ),
      child: InkWell(
        borderRadius: AppRadius.card,
        onTap: () => context.go(
          Uri(
            path: AppDestination.projects.detailPath,
            queryParameters: <String, String>{'epic': epic.id},
          ).toString(),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (epic.isBlocked)
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
              Text(epic.title, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xxs,
                children: <Widget>[
                  InlineBadge(icon: AppIcons.status, text: epic.status.label),
                  InlineBadge(
                    icon: Icons.priority_high_rounded,
                    text: epic.priority.label,
                  ),
                  InlineBadge(
                    icon: Icons.checklist_rounded,
                    text: '${epic.issueIds.length} issue(s)',
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
