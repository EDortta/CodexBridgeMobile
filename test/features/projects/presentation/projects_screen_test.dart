import 'package:codex_bridge_mobile/core/design/app_theme.dart';
import 'package:codex_bridge_mobile/core/storage/secure_storage_providers.dart';
import 'package:codex_bridge_mobile/features/projects/domain/project_health.dart';
import 'package:codex_bridge_mobile/features/projects/domain/project_repository.dart';
import 'package:codex_bridge_mobile/features/projects/domain/project_summary.dart';
import 'package:codex_bridge_mobile/features/projects/presentation/project_providers.dart';
import 'package:codex_bridge_mobile/features/projects/presentation/projects_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_secure_key_value_store.dart';

void main() {
  const ProjectSummary active = ProjectSummary(
    id: 'codex-bridge-mobile',
    name: 'Codex Bridge Mobile',
    health: ProjectHealth.active,
  );
  const ProjectSummary unhealthy = ProjectSummary(
    id: 'codex-bridge',
    name: 'Codex Bridge',
    health: ProjectHealth.unhealthy,
    attentionSummary: 'Build failing on development',
  );
  const ProjectSummary pendingDecision = ProjectSummary(
    id: 'codex-bridge-desktop',
    name: 'Codex Bridge Desktop',
    health: ProjectHealth.pendingDecision,
    attentionSummary: '2 decisions waiting your review',
  );
  const ProjectSummary offline = ProjectSummary(
    id: 'codex-bridge-cli',
    name: 'Codex Bridge CLI',
    health: ProjectHealth.offline,
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<ProjectSummary> projects = const <ProjectSummary>[
      active,
      unhealthy,
      pendingDecision,
      offline,
    ],
    InMemorySecureKeyValueStore? storage,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          projectRepositoryProvider.overrideWithValue(
            _FakeProjectRepository(projects),
          ),
          secureKeyValueStoreProvider.overrideWithValue(
            storage ?? InMemorySecureKeyValueStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ProjectsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists every project with its health label', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Codex Bridge Mobile'), findsOneWidget);
    expect(find.text('Codex Bridge'), findsOneWidget);
    expect(find.text('Codex Bridge Desktop'), findsOneWidget);
    expect(find.text('Codex Bridge CLI'), findsOneWidget);
    // Each label below also names its filter chip, so with one project per
    // health in this fixture, the chip and the card account for exactly two
    // — except "Offline", whose chip is the last in the horizontal filter
    // row and starts outside the default test surface's viewport, so only
    // the card's copy is built.
    expect(find.text('Active'), findsNWidgets(2));
    expect(find.text('Unhealthy'), findsNWidgets(2));
    expect(find.text('Pending decision'), findsNWidgets(2));
    expect(find.text('Offline'), findsOneWidget);
  });

  testWidgets(
    'attention states are visible on the card, without opening the project',
    (WidgetTester tester) async {
      await pumpScreen(tester);

      expect(find.text('Build failing on development'), findsOneWidget);
      expect(find.text('2 decisions waiting your review'), findsOneWidget);
    },
  );

  testWidgets('searching narrows the list to matching names', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(find.byKey(const Key('projectsSearchField')), 'cli');
    await tester.pumpAndSettle();

    expect(find.text('Codex Bridge CLI'), findsOneWidget);
    expect(find.text('Codex Bridge Mobile'), findsNothing);
    expect(find.text('Codex Bridge'), findsNothing);
    expect(find.text('Codex Bridge Desktop'), findsNothing);
  });

  testWidgets('a health filter chip narrows to that health only', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);

    // "Offline" is the last chip and starts outside the horizontal list's
    // viewport in the default test surface size.
    await tester.drag(
      find.byKey(const Key('projectsFilterChipsList')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Offline'));
    await tester.pumpAndSettle();

    expect(find.text('Codex Bridge CLI'), findsOneWidget);
    expect(find.text('Codex Bridge Mobile'), findsNothing);
  });

  testWidgets('a search with no match shows the empty state and can be cleared', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(const Key('projectsSearchField')),
      'nothing matches this',
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No projects match your search and filter.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Clear search and filter'));
    await tester.pumpAndSettle();

    expect(find.text('Codex Bridge Mobile'), findsOneWidget);
  });

  testWidgets('no projects at all shows the plain empty state, not the filtered one', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, projects: const <ProjectSummary>[]);

    expect(find.text('No projects yet.'), findsOneWidget);
  });

  testWidgets('tapping the star toggles the favorite and persists it', (
    WidgetTester tester,
  ) async {
    final InMemorySecureKeyValueStore storage = InMemorySecureKeyValueStore();
    await pumpScreen(tester, storage: storage);

    final Finder star = find.byKey(
      const Key('projectFavoriteToggle_codex-bridge-mobile'),
    );
    expect(
      tester.widget<IconButton>(star).icon,
      isA<Icon>().having((Icon i) => i.icon, 'icon', Icons.star_border_rounded),
    );

    await tester.tap(star);
    await tester.pumpAndSettle();

    expect(
      tester.widget<IconButton>(star).icon,
      isA<Icon>().having((Icon i) => i.icon, 'icon', Icons.star_rounded),
    );
    expect(
      storage.entries.values,
      contains(contains('codex-bridge-mobile')),
    );
  });

  testWidgets('the favorites filter shows only what was favorited', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(
      find.byKey(const Key('projectFavoriteToggle_codex-bridge')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Favorites'));
    await tester.pumpAndSettle();

    expect(find.text('Codex Bridge'), findsOneWidget);
    expect(find.text('Codex Bridge Mobile'), findsNothing);
  });
}

class _FakeProjectRepository implements ProjectRepository {
  const _FakeProjectRepository(this.projects);

  final List<ProjectSummary> projects;

  @override
  Future<List<ProjectSummary>> loadProjects() =>
      Future<List<ProjectSummary>>.value(projects);
}
