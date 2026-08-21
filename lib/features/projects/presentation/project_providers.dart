import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/gateway/gateway_context.dart';
import '../../../core/gateway/gateway_context_provider.dart';
import '../../../core/storage/secure_storage_providers.dart';
import '../data/mock_project_repository.dart';
import '../data/secure_project_favorites_store.dart';
import '../domain/project_favorites_store.dart';
import '../domain/project_repository.dart';
import '../domain/project_summary.dart';
import 'project_filter.dart';

final Provider<ProjectRepository> projectRepositoryProvider =
    Provider<ProjectRepository>((Ref ref) => MockProjectRepository());

final FutureProvider<List<ProjectSummary>> projectsProvider =
    FutureProvider<List<ProjectSummary>>((Ref ref) async {
      final GatewayContext? context = await ref.watch(
        gatewayContextProvider.future,
      );
      if (context == null) {
        throw const ProjectRepositoryException(
          'Select a server and sign in to view projects.',
        );
      }
      return ref
          .watch(projectRepositoryProvider)
          .loadProjects(server: context.server, accessToken: context.accessToken);
    });

final Provider<ProjectFavoritesStore> projectFavoritesStoreProvider =
    Provider<ProjectFavoritesStore>(
      (Ref ref) =>
          SecureProjectFavoritesStore(ref.watch(secureKeyValueStoreProvider)),
    );

final AsyncNotifierProvider<ProjectFavoritesController, Set<String>>
projectFavoritesProvider =
    AsyncNotifierProvider<ProjectFavoritesController, Set<String>>(
      ProjectFavoritesController.new,
    );

/// Owns the favorited project ids: loads them once, and toggles one at a
/// time with an optimistic update that rolls back if the write fails.
class ProjectFavoritesController extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() {
    return ref.watch(projectFavoritesStoreProvider).readFavoriteIds();
  }

  Future<void> toggle(String projectId) async {
    final Set<String> previous = state.valueOrNull ?? const <String>{};
    final Set<String> next = Set<String>.of(previous);
    if (!next.remove(projectId)) {
      next.add(projectId);
    }
    state = AsyncValue<Set<String>>.data(next);

    try {
      await ref.read(projectFavoritesStoreProvider).writeFavoriteIds(next);
    } on Exception {
      // The keystore refused the write: the operator's tap did not stick, so
      // the card must not keep showing it as favorited.
      state = AsyncValue<Set<String>>.data(previous);
    }
  }
}

/// A project as the list screen shows it: the repository summary joined with
/// whether the operator has favorited it.
class ProjectListItem {
  const ProjectListItem({required this.summary, required this.isFavorite});

  final ProjectSummary summary;
  final bool isFavorite;
}

/// Joins [projectsProvider] and [projectFavoritesProvider]. Loading/error on
/// either side propagates as loading/error for the combined list — the
/// screen has nothing meaningful to show with only one half of the data.
final Provider<AsyncValue<List<ProjectListItem>>> projectListProvider =
    Provider<AsyncValue<List<ProjectListItem>>>((Ref ref) {
      final AsyncValue<List<ProjectSummary>> projects = ref.watch(
        projectsProvider,
      );
      final AsyncValue<Set<String>> favorites = ref.watch(
        projectFavoritesProvider,
      );

      if (projects case AsyncError(:final Object error, :final StackTrace stackTrace)) {
        return AsyncValue<List<ProjectListItem>>.error(error, stackTrace);
      }
      if (favorites case AsyncError(:final Object error, :final StackTrace stackTrace)) {
        return AsyncValue<List<ProjectListItem>>.error(error, stackTrace);
      }

      final List<ProjectSummary>? projectList = projects.valueOrNull;
      // Favorites default to empty while still loading rather than blocking
      // the whole list on a local-storage read the operator cannot see.
      final Set<String> favoriteIds = favorites.valueOrNull ?? const <String>{};
      if (projectList == null) {
        return const AsyncValue<List<ProjectListItem>>.loading();
      }

      return AsyncValue<List<ProjectListItem>>.data(<ProjectListItem>[
        for (final ProjectSummary summary in projectList)
          ProjectListItem(
            summary: summary,
            isFavorite: favoriteIds.contains(summary.id),
          ),
      ]);
    });

/// A single project by id, from `GET /api/v1/projects/{id}` — a dedicated
/// call rather than a lookup in [projectsProvider]'s already-loaded list, so
/// a project outside the caller's visible scope reports "not found" (`null`,
/// from the backend's own 404-not-403 answer, `ProjectRepository.loadProject`'s
/// doc comment) even when it was never in that list to begin with, and so a
/// deep link straight to a project detail does not first need the whole list
/// loaded.
final AutoDisposeFutureProviderFamily<ProjectSummary?, String>
_projectDetailProvider = FutureProvider.autoDispose.family<ProjectSummary?, String>((
  Ref ref,
  String id,
) async {
  final GatewayContext? context = await ref.watch(gatewayContextProvider.future);
  if (context == null) {
    throw const ProjectRepositoryException(
      'Select a server and sign in to view this project.',
    );
  }
  return ref
      .watch(projectRepositoryProvider)
      .loadProject(server: context.server, accessToken: context.accessToken, id: id);
});

/// Public shape kept stable ([AsyncValue<ProjectSummary?>], `null` meaning
/// "not found") across the [_projectDetailProvider] change above, so no call
/// site (`lib/app/project_dashboard_screen.dart`) needed to change.
final ProviderFamily<AsyncValue<ProjectSummary?>, String> projectByIdProvider =
    Provider.family<AsyncValue<ProjectSummary?>, String>((
      Ref ref,
      String id,
    ) {
      return ref.watch(_projectDetailProvider(id));
    });

final StateProvider<String> projectSearchQueryProvider =
    StateProvider<String>((Ref ref) => '');

final StateProvider<ProjectFilter> projectFilterProvider =
    StateProvider<ProjectFilter>((Ref ref) => ProjectFilter.all);

/// Pure so it is testable without pumping a widget: a search/filter bug
/// should fail a plain unit test, not only a widget test.
List<ProjectListItem> filterProjectListItems(
  List<ProjectListItem> items, {
  required String query,
  required ProjectFilter filter,
}) {
  final String normalizedQuery = query.trim().toLowerCase();

  return items.where((ProjectListItem item) {
    if (normalizedQuery.isNotEmpty &&
        !item.summary.name.toLowerCase().contains(normalizedQuery)) {
      return false;
    }
    return switch (filter) {
      ProjectFilter.all => true,
      ProjectFilter.favorites => item.isFavorite,
      ProjectFilter.active ||
      ProjectFilter.unhealthy ||
      ProjectFilter.pendingDecision ||
      ProjectFilter.offline => item.summary.health == filter.health,
    };
  }).toList(growable: false);
}
