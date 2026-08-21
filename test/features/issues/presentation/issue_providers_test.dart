import 'package:codex_bridge_mobile/features/issues/data/mock_issue_repository.dart';
import 'package:codex_bridge_mobile/features/issues/domain/epic.dart';
import 'package:codex_bridge_mobile/features/issues/domain/issue_repository.dart';
import 'package:codex_bridge_mobile/features/issues/domain/project_issue.dart';
import 'package:codex_bridge_mobile/features/issues/presentation/issue_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer buildContainer() {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        issueRepositoryProvider.overrideWithValue(MockIssueRepository()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('issuesProvider loads every issue from the repository', () async {
    final ProviderContainer container = buildContainer();

    final List<ProjectIssue> issues = await container.read(issuesProvider.future);

    expect(issues, isNotEmpty);
  });

  test('epicsProvider loads every epic from the repository', () async {
    final ProviderContainer container = buildContainer();

    final List<Epic> epics = await container.read(epicsProvider.future);

    expect(epics, isNotEmpty);
  });

  test('issueDetailProvider loads a single issue by id', () async {
    final ProviderContainer container = buildContainer();

    final ProjectIssue issue = await container.read(
      issueDetailProvider('fix-development-build').future,
    );

    expect(issue.id, 'fix-development-build');
  });

  test('issueDetailProvider surfaces IssueNotFoundException for an unknown id', () async {
    final ProviderContainer container = buildContainer();

    await expectLater(
      container.read(issueDetailProvider('does-not-exist').future),
      throwsA(isA<IssueNotFoundException>()),
    );
  });

  test('epicDetailProvider loads a single epic by id', () async {
    final ProviderContainer container = buildContainer();

    final Epic epic = await container.read(
      epicDetailProvider('epic-mobile-planning').future,
    );

    expect(epic.id, 'epic-mobile-planning');
  });

  test('epicDetailProvider surfaces EpicNotFoundException for an unknown id', () async {
    final ProviderContainer container = buildContainer();

    await expectLater(
      container.read(epicDetailProvider('does-not-exist').future),
      throwsA(isA<EpicNotFoundException>()),
    );
  });

  test('epic and issue filter providers default to unfiltered (null)', () {
    final ProviderContainer container = buildContainer();

    expect(container.read(epicStatusFilterProvider), isNull);
    expect(container.read(epicPriorityFilterProvider), isNull);
    expect(container.read(issueStatusFilterProvider), isNull);
    expect(container.read(issuePriorityFilterProvider), isNull);
  });
}
