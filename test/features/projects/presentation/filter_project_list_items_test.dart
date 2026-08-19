import 'package:codex_bridge_mobile/features/projects/domain/project_health.dart';
import 'package:codex_bridge_mobile/features/projects/domain/project_summary.dart';
import 'package:codex_bridge_mobile/features/projects/presentation/project_filter.dart';
import 'package:codex_bridge_mobile/features/projects/presentation/project_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ProjectListItem active = ProjectListItem(
    summary: ProjectSummary(
      id: 'a',
      name: 'Codex Bridge Mobile',
      health: ProjectHealth.active,
    ),
    isFavorite: false,
  );
  const ProjectListItem unhealthy = ProjectListItem(
    summary: ProjectSummary(
      id: 'b',
      name: 'Codex Bridge',
      health: ProjectHealth.unhealthy,
      attentionSummary: 'Build failing',
    ),
    isFavorite: true,
  );
  const ProjectListItem offline = ProjectListItem(
    summary: ProjectSummary(
      id: 'c',
      name: 'Codex Bridge CLI',
      health: ProjectHealth.offline,
    ),
    isFavorite: false,
  );
  final List<ProjectListItem> all = <ProjectListItem>[
    active,
    unhealthy,
    offline,
  ];

  test('an empty query and the all filter return everything', () {
    expect(
      filterProjectListItems(all, query: '', filter: ProjectFilter.all),
      all,
    );
  });

  test('a query matches the name case-insensitively', () {
    expect(
      filterProjectListItems(all, query: 'mobile', filter: ProjectFilter.all),
      <ProjectListItem>[active],
    );
  });

  test('surrounding whitespace in the query does not prevent a match', () {
    expect(
      filterProjectListItems(
        all,
        query: '  mobile  ',
        filter: ProjectFilter.all,
      ),
      <ProjectListItem>[active],
    );
  });

  test('the favorites filter keeps only favorited items', () {
    expect(
      filterProjectListItems(all, query: '', filter: ProjectFilter.favorites),
      <ProjectListItem>[unhealthy],
    );
  });

  test('a health filter keeps only that health', () {
    expect(
      filterProjectListItems(all, query: '', filter: ProjectFilter.offline),
      <ProjectListItem>[offline],
    );
  });

  test('a query and a filter narrow together, not either alone', () {
    expect(
      filterProjectListItems(
        all,
        query: 'bridge',
        filter: ProjectFilter.offline,
      ),
      <ProjectListItem>[offline],
    );
    expect(
      filterProjectListItems(
        all,
        query: 'mobile',
        filter: ProjectFilter.offline,
      ),
      isEmpty,
    );
  });
}
