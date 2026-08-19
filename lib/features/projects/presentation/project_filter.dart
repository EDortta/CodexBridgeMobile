import '../domain/project_health.dart';

/// The projects list's filter chip selection.
///
/// `all` and `favorites` are UI-only groupings with no [ProjectHealth]
/// counterpart, so this lives in `presentation/` rather than joining
/// [ProjectHealth] in `domain/`.
enum ProjectFilter {
  all,
  favorites,
  active,
  unhealthy,
  pendingDecision,
  offline;

  String get label => switch (this) {
    ProjectFilter.all => 'All',
    ProjectFilter.favorites => 'Favorites',
    ProjectFilter.active => 'Active',
    ProjectFilter.unhealthy => 'Unhealthy',
    ProjectFilter.pendingDecision => 'Pending decision',
    ProjectFilter.offline => 'Offline',
  };

  /// The health this filter narrows to, or null for [all]/[favorites], which
  /// narrow by something other than health.
  ProjectHealth? get health => switch (this) {
    ProjectFilter.active => ProjectHealth.active,
    ProjectFilter.unhealthy => ProjectHealth.unhealthy,
    ProjectFilter.pendingDecision => ProjectHealth.pendingDecision,
    ProjectFilter.offline => ProjectHealth.offline,
    ProjectFilter.all || ProjectFilter.favorites => null,
  };
}
