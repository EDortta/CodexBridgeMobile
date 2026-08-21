import '../domain/project_health.dart';
import '../domain/project_repository.dart';
import '../domain/project_summary.dart';

/// The default `projectRepositoryProvider` in every debug build and every
/// widget test that does not override it — the same role `MockAuthGateway`
/// plays for `authGatewayProvider`. A release build gets [HttpProjectRepository]
/// instead, wired by `lib/app/project_repository_binding.dart`
/// (`kReleaseMode`-gated, exactly like `auth_gateway_binding.dart`).
///
/// `server`/`accessToken` are accepted (the interface is shared with
/// [HttpProjectRepository]) and ignored — fixture data does not depend on
/// which server or session is active.
///
/// Covers all four [ProjectHealth] values so the list, search, filter and
/// attention-visibility behavior added by #23 has something real to exercise
/// without a device.
class MockProjectRepository implements ProjectRepository {
  static const List<ProjectSummary> _fixtures = <ProjectSummary>[
    ProjectSummary(
      id: 'codex-bridge-mobile',
      name: 'Codex Bridge Mobile',
      health: ProjectHealth.active,
    ),
    ProjectSummary(
      id: 'codex-bridge',
      name: 'Codex Bridge',
      health: ProjectHealth.unhealthy,
      attentionSummary: 'Build failing on development',
    ),
    ProjectSummary(
      id: 'codex-bridge-desktop',
      name: 'Codex Bridge Desktop',
      health: ProjectHealth.pendingDecision,
      attentionSummary: '2 decisions waiting your review',
    ),
    ProjectSummary(
      id: 'codex-bridge-cli',
      name: 'Codex Bridge CLI',
      health: ProjectHealth.offline,
      attentionSummary: 'Last seen 3 days ago',
    ),
  ];

  @override
  Future<List<ProjectSummary>> loadProjects({
    required Uri server,
    required String accessToken,
  }) {
    return Future<List<ProjectSummary>>.value(_fixtures);
  }

  @override
  Future<ProjectSummary?> loadProject({
    required Uri server,
    required String accessToken,
    required String id,
  }) {
    for (final ProjectSummary summary in _fixtures) {
      if (summary.id == id) {
        return Future<ProjectSummary?>.value(summary);
      }
    }
    return Future<ProjectSummary?>.value();
  }
}
