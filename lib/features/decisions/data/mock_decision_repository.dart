import '../domain/decision.dart';
import '../domain/decision_repository.dart';
import '../domain/decision_risk.dart';
import '../domain/decision_state.dart';
import '../domain/decision_urgency.dart';

/// Stands in for a real decisions endpoint until one exists — CodexBridge #6
/// ("Expose operational decisions API") is still open. Same "fake until the
/// contract exists" shape `MockProjectRepository` uses. Tagged with the same
/// project ids so #24's dashboard has real cross-project data:
/// `codex-bridge-desktop` carries exactly the 2 pending decisions its
/// `ProjectSummary.attentionSummary` already promises ("2 decisions waiting
/// your review") — those two and `shell-review` keep the exact
/// id/projectId/title/requestedBy/requestedAt values #24's tests pin, only
/// gaining the fields #25 adds. The remaining fixtures exist to give #25's
/// urgency/risk/state/deadline filters something real to narrow: one
/// critical decision, and two already resolved (approved/rejected) so the
/// state filter — and the inbox's default "pending only" view — has
/// something to exclude.
class MockDecisionRepository implements DecisionRepository {
  @override
  Future<List<Decision>> loadDecisions() {
    return Future<List<Decision>>.value(<Decision>[
      Decision(
        id: 'shell-review',
        projectId: 'codex-bridge-mobile',
        title: 'Approve the navigation shell',
        requestedBy: 'Foundation phase',
        requestedAt: _shellReviewRequestedAt,
        urgency: DecisionUrgency.normal,
        risk: DecisionRisk.low,
        state: DecisionState.pending,
        deadline: _shellReviewDeadline,
        impactSummary: 'Blocks Phase 1 sign-off if left unresolved.',
        recommendationSummary: 'Approve — the shell matches the agreed design.',
      ),
      Decision(
        id: 'desktop-color-palette',
        projectId: 'codex-bridge-desktop',
        title: 'Approve the desktop color palette',
        requestedBy: 'Design review',
        requestedAt: _desktopFreshRequestedAt,
        urgency: DecisionUrgency.low,
        risk: DecisionRisk.low,
        state: DecisionState.pending,
        deadline: _desktopColorPaletteDeadline,
        impactSummary: 'Cosmetic only; no functional risk.',
        recommendationSummary: 'Approve as proposed.',
      ),
      Decision(
        id: 'desktop-release-cut',
        projectId: 'codex-bridge-desktop',
        title: 'Cut the next desktop release',
        requestedBy: 'Release planning',
        requestedAt: _desktopStaleRequestedAt,
        urgency: DecisionUrgency.high,
        risk: DecisionRisk.medium,
        state: DecisionState.pending,
        deadline: _desktopReleaseCutDeadline,
        impactSummary: 'Delays the next desktop release train.',
        recommendationSummary:
            'Approve to cut now; defer the pending fix to a patch release.',
      ),
      Decision(
        id: 'bridge-emergency-rollback',
        projectId: 'codex-bridge',
        title: 'Approve emergency rollback of the failing build',
        requestedBy: 'Incident response',
        requestedAt: _bridgeRollbackRequestedAt,
        urgency: DecisionUrgency.critical,
        risk: DecisionRisk.high,
        state: DecisionState.pending,
        deadline: _bridgeRollbackDeadline,
        impactSummary: 'Production build stays broken until this is resolved.',
        recommendationSummary: 'Approve — the rollback is safe and reversible.',
      ),
      Decision(
        id: 'cli-already-approved',
        projectId: 'codex-bridge-cli',
        title: 'Approve the CLI packaging change',
        requestedBy: 'Release planning',
        requestedAt: _cliApprovedRequestedAt,
        urgency: DecisionUrgency.normal,
        risk: DecisionRisk.low,
        state: DecisionState.approved,
        deadline: _cliApprovedDeadline,
        impactSummary: 'Already resolved; kept for state-filter history.',
        recommendationSummary: 'Approved as proposed.',
      ),
      Decision(
        id: 'bridge-already-rejected',
        projectId: 'codex-bridge',
        title: 'Skip the flaky connection test instead of fixing it',
        requestedBy: 'CI triage',
        requestedAt: _bridgeRejectedRequestedAt,
        urgency: DecisionUrgency.low,
        risk: DecisionRisk.medium,
        state: DecisionState.rejected,
        deadline: _bridgeRejectedDeadline,
        impactSummary: 'Already resolved; kept for state-filter history.',
        recommendationSummary: 'Rejected — fix the test instead of skipping it.',
      ),
    ]);
  }

  // DateTime has no const constructor, so these are `static final`, not
  // `static const` — the values are still fixed, just not compile-time.
  static final DateTime _shellReviewRequestedAt = DateTime.utc(2026, 8, 15, 9);
  static final DateTime _shellReviewDeadline = DateTime.utc(2026, 8, 20);

  static final DateTime _desktopFreshRequestedAt = DateTime.utc(
    2026,
    8,
    19,
    10,
  );
  static final DateTime _desktopColorPaletteDeadline = DateTime.utc(2026, 8, 25);

  static final DateTime _desktopStaleRequestedAt = DateTime.utc(
    2026,
    8,
    16,
    9,
  );
  static final DateTime _desktopReleaseCutDeadline = DateTime.utc(2026, 8, 18);

  static final DateTime _bridgeRollbackRequestedAt = DateTime.utc(
    2026,
    8,
    19,
    11,
  );
  static final DateTime _bridgeRollbackDeadline = DateTime.utc(2026, 8, 19, 18);

  static final DateTime _cliApprovedRequestedAt = DateTime.utc(2026, 8, 10);
  static final DateTime _cliApprovedDeadline = DateTime.utc(2026, 8, 12);

  static final DateTime _bridgeRejectedRequestedAt = DateTime.utc(2026, 8, 9);
  static final DateTime _bridgeRejectedDeadline = DateTime.utc(2026, 8, 11);
}
