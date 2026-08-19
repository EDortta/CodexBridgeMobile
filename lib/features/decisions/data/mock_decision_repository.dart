import '../../../core/format/relative_moment.dart';
import '../domain/decision.dart';
import '../domain/decision_audit_event.dart';
import '../domain/decision_comment.dart';
import '../domain/decision_repository.dart';
import '../domain/decision_risk.dart';
import '../domain/decision_state.dart';
import '../domain/decision_urgency.dart';

/// Stands in for a real decisions endpoint until one exists — CodexBridge #6
/// ("Expose operational decisions API") is still open. Same "fake until the
/// contract exists" shape `MockProjectRepository` uses, but the first mock
/// repository in this app that is genuinely **stateful**: `approve`/
/// `reject`/`requestRevision`/`discuss` mutate an in-memory map so a
/// resolution actually sticks when the operator navigates back to the inbox
/// — the earlier read-only mocks never needed this because nothing in this
/// app wrote through them.
///
/// Tagged with the same project ids so #24's dashboard has real
/// cross-project data: `codex-bridge-desktop` carries exactly the 2 pending
/// decisions its `ProjectSummary.attentionSummary` already promises ("2
/// decisions waiting your review") — those two and `shell-review` keep the
/// exact id/projectId/title/requestedBy/requestedAt values #24's and #25's
/// tests pin, only gaining the fields #25/#26 add.
class MockDecisionRepository implements DecisionRepository {
  MockDecisionRepository({this._clock = DateTime.timestamp})
    : _decisions = <String, Decision>{
        for (final Decision decision in _seed()) decision.id: decision,
      };

  final Clock _clock;
  final Map<String, Decision> _decisions;

  @override
  Future<List<Decision>> loadDecisions() async => _decisions.values.toList(growable: false);

  @override
  Future<Decision> loadDecision(String decisionId) async {
    final Decision? decision = _decisions[decisionId];
    if (decision == null) {
      throw DecisionNotFoundException(decisionId);
    }
    return decision;
  }

  @override
  Future<Decision> approve(String decisionId, {String? comment}) {
    return _resolve(decisionId, DecisionState.approved, DecisionAuditAction.approved, comment);
  }

  @override
  Future<Decision> reject(String decisionId, {required String justification}) async {
    // `async` so an empty justification rejects the returned Future rather
    // than throwing synchronously out of the call — a Future-returning API
    // that sometimes throws before returning anything is a footgun for every
    // caller that assumes `await`/`.catchError` sees every failure.
    if (justification.trim().isEmpty) {
      throw ArgumentError.value(justification, 'justification', 'A rejection requires a justification.');
    }
    return _resolve(decisionId, DecisionState.rejected, DecisionAuditAction.rejected, justification);
  }

  @override
  Future<Decision> requestRevision(String decisionId, {required String comment}) async {
    if (comment.trim().isEmpty) {
      throw ArgumentError.value(comment, 'comment', 'A revision request requires a comment.');
    }
    return _resolve(
      decisionId,
      DecisionState.needsRevision,
      DecisionAuditAction.revisionRequested,
      comment,
    );
  }

  @override
  Future<Decision> discuss(String decisionId, {required String comment}) async {
    if (comment.trim().isEmpty) {
      throw ArgumentError.value(comment, 'comment', 'A comment cannot be empty.');
    }
    final Decision current = await loadDecision(decisionId);
    final DecisionComment posted = DecisionComment(
      id: '$decisionId-comment-${current.discussion.length + 1}',
      author: 'You',
      body: comment.trim(),
      postedAt: _clock(),
    );
    final Decision updated = current.copyWith(
      discussion: <DecisionComment>[...current.discussion, posted],
    );
    _decisions[decisionId] = updated;
    return updated;
  }

  Future<Decision> _resolve(
    String decisionId,
    DecisionState newState,
    DecisionAuditAction action,
    String? comment,
  ) async {
    final Decision current = await loadDecision(decisionId);
    final DecisionAuditEvent event = DecisionAuditEvent(
      id: '$decisionId-audit-${current.auditTrail.length + 1}',
      action: action,
      actor: 'You',
      occurredAt: _clock(),
      comment: comment?.trim().isEmpty ?? true ? null : comment!.trim(),
    );
    final Decision updated = current.copyWith(
      state: newState,
      auditTrail: <DecisionAuditEvent>[...current.auditTrail, event],
    );
    _decisions[decisionId] = updated;
    return updated;
  }

  static List<Decision> _seed() => <Decision>[
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
      context:
          'Phase 0 delivered the navigation shell (StatefulShellRoute, 4 '
          'primary destinations). It needs an explicit sign-off before Phase '
          '1 work builds on top of it.',
      riskDetails: const <String>[
        'Low risk: the shell has 90+ passing widget tests and is already the '
        'foundation every later screen in this app builds on.',
      ],
      evidence: const <String>['test/app/app_router_test.dart — 9 passing cases'],
      affectedEntities: const <String>['Codex Bridge Mobile — navigation shell'],
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
      context: 'Design proposed a new accent palette for the desktop shell.',
      riskDetails: const <String>['Purely cosmetic — no functional surface changes.'],
      evidence: const <String>['Design review doc, 2026-08-19'],
      affectedEntities: const <String>['Codex Bridge Desktop — theme'],
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
      context:
          'A known, low-severity bug is still open. Cutting now ships it; '
          'waiting delays the whole release train for everyone.',
      riskDetails: const <String>[
        'Medium risk: ships a known bug, but it is cosmetic and has a documented workaround.',
      ],
      evidence: const <String>['Bug tracker: DESK-142 (cosmetic, workaround documented)'],
      affectedEntities: const <String>['Codex Bridge Desktop — release train'],
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
      context:
          'The development build has failed since 2026-08-18T22:00Z. A '
          'rollback to the last known-good commit is proposed to restore '
          'service while the root cause is investigated separately.',
      riskDetails: const <String>[
        'High risk if delayed further: every hour extends the outage.',
        'The rollback itself is low risk — it is a revert to a build that was healthy for 6 days.',
      ],
      evidence: const <String>[
        'CI run #4821 — first failure, 2026-08-18T22:00Z',
        'Last known-good build: #4809, 2026-08-18T09:00Z',
      ],
      affectedEntities: const <String>[
        'Codex Bridge — production build',
        'Codex Bridge — CI pipeline',
      ],
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
      context: 'Packaging change to the CLI distribution format.',
      auditTrail: <DecisionAuditEvent>[
        DecisionAuditEvent(
          id: 'cli-already-approved-audit-1',
          action: DecisionAuditAction.approved,
          actor: 'You',
          occurredAt: _cliApprovedDeadline,
        ),
      ],
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
      context: 'CI triage proposed skipping a flaky connection test rather than fixing it.',
      auditTrail: <DecisionAuditEvent>[
        DecisionAuditEvent(
          id: 'bridge-already-rejected-audit-1',
          action: DecisionAuditAction.rejected,
          actor: 'You',
          occurredAt: _bridgeRejectedDeadline,
          comment: 'Skipping hides a real bug. Fix the test instead.',
        ),
      ],
    ),
  ];

  // DateTime has no const constructor, so these are `static final`, not
  // `static const` — the values are still fixed, just not compile-time.
  static final DateTime _shellReviewRequestedAt = DateTime.utc(2026, 8, 15, 9);
  static final DateTime _shellReviewDeadline = DateTime.utc(2026, 8, 20);

  static final DateTime _desktopFreshRequestedAt = DateTime.utc(2026, 8, 19, 10);
  static final DateTime _desktopColorPaletteDeadline = DateTime.utc(2026, 8, 25);

  static final DateTime _desktopStaleRequestedAt = DateTime.utc(2026, 8, 16, 9);
  static final DateTime _desktopReleaseCutDeadline = DateTime.utc(2026, 8, 18);

  static final DateTime _bridgeRollbackRequestedAt = DateTime.utc(2026, 8, 19, 11);
  static final DateTime _bridgeRollbackDeadline = DateTime.utc(2026, 8, 19, 18);

  static final DateTime _cliApprovedRequestedAt = DateTime.utc(2026, 8, 10);
  static final DateTime _cliApprovedDeadline = DateTime.utc(2026, 8, 12);

  static final DateTime _bridgeRejectedRequestedAt = DateTime.utc(2026, 8, 9);
  static final DateTime _bridgeRejectedDeadline = DateTime.utc(2026, 8, 11);
}
