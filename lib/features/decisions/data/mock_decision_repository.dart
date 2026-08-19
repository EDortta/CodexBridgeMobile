import '../domain/decision.dart';
import '../domain/decision_repository.dart';

/// Stands in for a real decisions endpoint until one exists — same "fake
/// until the contract exists" shape `MockProjectRepository` uses. Tagged
/// with the same project ids so #24's dashboard has real cross-project data:
/// `codex-bridge-desktop` carries exactly the 2 decisions its
/// `ProjectSummary.attentionSummary` already promises ("2 decisions waiting
/// your review"), one fresh and one old enough to demonstrate the
/// dashboard's staleness marking.
class MockDecisionRepository implements DecisionRepository {
  @override
  Future<List<Decision>> loadPendingDecisions() {
    return Future<List<Decision>>.value(<Decision>[
      Decision(
        id: 'shell-review',
        projectId: 'codex-bridge-mobile',
        title: 'Approve the navigation shell',
        requestedBy: 'Foundation phase',
        requestedAt: _shellReviewRequestedAt,
      ),
      Decision(
        id: 'desktop-color-palette',
        projectId: 'codex-bridge-desktop',
        title: 'Approve the desktop color palette',
        requestedBy: 'Design review',
        requestedAt: _desktopFreshRequestedAt,
      ),
      Decision(
        id: 'desktop-release-cut',
        projectId: 'codex-bridge-desktop',
        title: 'Cut the next desktop release',
        requestedBy: 'Release planning',
        requestedAt: _desktopStaleRequestedAt,
      ),
    ]);
  }

  // DateTime has no const constructor, so these are `static final`, not
  // `static const` — the values are still fixed, just not compile-time.
  static final DateTime _shellReviewRequestedAt = DateTime.utc(2026, 8, 15, 9);
  static final DateTime _desktopFreshRequestedAt = DateTime.utc(
    2026,
    8,
    19,
    10,
  );
  static final DateTime _desktopStaleRequestedAt = DateTime.utc(
    2026,
    8,
    16,
    9,
  );
}
