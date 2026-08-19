import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_tokens.dart';
import '../../../core/navigation/app_destinations.dart';
import '../../../core/presentation/async_state_view.dart';
import '../domain/project_health.dart';
import 'project_filter.dart';
import 'project_providers.dart';

/// The Projects destination: search, favorites and health filters over the
/// operator's projects (#23). Loading and error states come from
/// [AsyncStateView]; empty states (no projects at all, or none matching the
/// current search/filter) are handled below it, because they depend on the
/// search box and filter chips this screen owns.
///
/// Device network connectivity is not modeled separately here:
/// [ProjectHealth.offline] already carries the "this project is unreachable"
/// meaning issue #23 asks a card and a filter to expose, and the repository
/// behind this screen is still `MockProjectRepository` — there is no real
/// network call yet for a connectivity banner to describe (CodexBridge #5,
/// "Expose projects and project operational summary API", is still open).
class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(AppDestination.projects.label)),
      body: AsyncStateView<List<ProjectListItem>>(
        value: ref.watch(projectListProvider),
        data: (BuildContext context, List<ProjectListItem> items) {
          return _ProjectsListBody(items: items);
        },
      ),
    );
  }
}

class _ProjectsListBody extends ConsumerWidget {
  const _ProjectsListBody({required this.items});

  final List<ProjectListItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String query = ref.watch(projectSearchQueryProvider);
    final ProjectFilter filter = ref.watch(projectFilterProvider);
    final List<ProjectListItem> filtered = filterProjectListItems(
      items,
      query: query,
      filter: filter,
    );

    return Column(
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: _ProjectsSearchField(),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            key: const Key('projectsFilterChipsList'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: ProjectFilter.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
            itemBuilder: (BuildContext context, int index) {
              final ProjectFilter value = ProjectFilter.values[index];
              return FilterChip(
                label: Text(value.label),
                selected: filter == value,
                onSelected: (_) =>
                    ref.read(projectFilterProvider.notifier).state = value,
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: items.isEmpty
              ? const _EmptyProjectsView(
                  message: 'No projects yet.',
                  showClearAction: false,
                )
              : filtered.isEmpty
              ? const _EmptyProjectsView(
                  message: 'No projects match your search and filter.',
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
                      child: _ProjectCard(item: filtered[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Owns its own [TextEditingController] instead of rebuilding one from
/// [projectSearchQueryProvider] on every frame — a fresh controller per build
/// would reset the cursor (and, on Android, drop in-progress IME composing
/// text) on every keystroke, since a keystroke is exactly what triggers the
/// rebuild. [ref.listen] resyncs the controller only when the query changes
/// from *outside* this field (the empty-state "Clear search and filter"
/// button), not from this field's own `onChanged`.
class _ProjectsSearchField extends ConsumerStatefulWidget {
  const _ProjectsSearchField();

  @override
  ConsumerState<_ProjectsSearchField> createState() =>
      _ProjectsSearchFieldState();
}

class _ProjectsSearchFieldState extends ConsumerState<_ProjectsSearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: ref.read(projectSearchQueryProvider),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(projectSearchQueryProvider, (
      String? previous,
      String next,
    ) {
      if (next != _controller.text) {
        _controller.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
    });
    final bool hasQuery = ref.watch(
      projectSearchQueryProvider.select((String q) => q.isNotEmpty),
    );

    return TextField(
      key: const Key('projectsSearchField'),
      controller: _controller,
      decoration: InputDecoration(
        hintText: 'Search projects',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: hasQuery
            ? IconButton(
                icon: const Icon(Icons.clear_rounded),
                tooltip: 'Clear search',
                onPressed: () =>
                    ref.read(projectSearchQueryProvider.notifier).state = '',
              )
            : null,
        border: const OutlineInputBorder(borderRadius: AppRadius.card),
      ),
      onChanged: (String value) =>
          ref.read(projectSearchQueryProvider.notifier).state = value,
    );
  }
}

class _EmptyProjectsView extends ConsumerWidget {
  const _EmptyProjectsView({
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
              AppIcons.projects,
              size: 40,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            if (showClearAction) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () {
                  ref.read(projectSearchQueryProvider.notifier).state = '';
                  ref.read(projectFilterProvider.notifier).state =
                      ProjectFilter.all;
                },
                child: const Text('Clear search and filter'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({required this.item});

  final ProjectListItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ProjectHealth health = item.summary.health;
    final bool needsAttention =
        health == ProjectHealth.unhealthy ||
        health == ProjectHealth.pendingDecision;

    final Color accent = switch (health) {
      ProjectHealth.active => theme.colorScheme.outlineVariant,
      ProjectHealth.unhealthy => theme.colorScheme.error,
      ProjectHealth.pendingDecision => theme.colorScheme.tertiary,
      ProjectHealth.offline => theme.colorScheme.outline,
    };
    final IconData healthIcon = switch (health) {
      ProjectHealth.active => AppIcons.status,
      ProjectHealth.unhealthy => Icons.error_rounded,
      ProjectHealth.pendingDecision => AppIcons.decisions,
      ProjectHealth.offline => AppIcons.unreachable,
    };

    return Container(
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(color: accent, width: needsAttention ? 2 : 1),
          borderRadius: AppRadius.card,
        ),
      ),
      child: InkWell(
        borderRadius: AppRadius.card,
        onTap: () => context.go(AppDestination.projects.detailPath),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(item.summary.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xxs),
                    Row(
                      children: <Widget>[
                        Icon(healthIcon, size: 16, color: accent),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          health.label,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                    if (item.summary.attentionSummary case final String reason?) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(reason, style: theme.textTheme.bodyMedium),
                    ],
                  ],
                ),
              ),
              IconButton(
                key: Key('projectFavoriteToggle_${item.summary.id}'),
                icon: Icon(
                  item.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: item.isFavorite
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                tooltip: item.isFavorite
                    ? 'Remove from favorites'
                    : 'Add to favorites',
                onPressed: () => ref
                    .read(projectFavoritesProvider.notifier)
                    .toggle(item.summary.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
