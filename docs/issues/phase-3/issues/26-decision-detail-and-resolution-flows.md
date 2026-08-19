# #26 — Implement decision detail and resolution flows

- status: [finished]
- work_id: WK-20260819-gh-26-decision-detail-and-resolution-flows
- public issue: https://github.com/EDortta/CodexBridgeMobile/issues/26
- parent epic: https://github.com/EDortta/CodexBridgeMobile/issues/4
- branch: `feature/gh-26/decision-detail-and-resolution-flows`

## Context

#25 built the inbox and deliberately left cards unclickable — full context,
discussion and the resolution actions themselves were scoped to this issue.
`Decision` had no context/risks/evidence/affected-entities fields, no
discussion, no audit trail, and `DecisionRepository` was read-only.

## Objective (from the public issue)

Show context, impact, risks, evidence, affected entities and discussion;
implement approve, reject, request revision and discuss actions. Acceptance
criteria: rejection requires justification; critical actions require
explicit confirmation; all outcomes create an audit event.

## Scope

- `Decision` gains `context`, `riskDetails`, `evidence`, `affectedEntities`,
  `discussion`, `auditTrail`, and a `copyWith`.
- `DecisionComment`, `DecisionAuditEvent`/`DecisionAuditAction` domain types.
- `DecisionRepository` gains `loadDecision`, `approve`, `reject`,
  `requestRevision`, `discuss`. `MockDecisionRepository` becomes stateful
  (in-memory, mutated in place) with an injectable clock.
- `DecisionDetailScreen` (`lib/features/decisions/presentation/`): summary,
  context/impact/risks/evidence/affected-entities, actions (hidden once
  resolved except Discuss), discussion thread, resolution history.
- `_ResolutionDialog`: comment field (required for reject/request-revision/
  discuss, optional for approve) + a critical-decision-specific
  acknowledgement checkbox gating submit — not a generic Yes/No dialog.
- Router: `/decisions/detail?decision=<id>` nested under `/decisions`;
  `_DecisionCard.onTap` wired.
- `DecisionBadge` and `describeDeadline` extracted (shared by the inbox card
  and the detail screen, now two genuine consumers each).

Out of scope: the cross-cutting, immutable audit trail store (#46, Epic
#14) — this issue's audit event is local to the decisions feature.

## ARO (Allowed / Prohibited / Out of scope) — carried from `docs/limits.md`

Implemented within "explicitly requested mobile-client issue, including
focused tests" (Allowed). No backend, auth, persistence-contract or
device-permission change. `Decision`'s new fields default to empty so
existing (#25) fixtures needed no changes to keep compiling; `DecisionRepository`'s
new methods are additive to the interface, implemented only by
`MockDecisionRepository` (grepped before changing).

## Test plan

25 new tests: `DecisionAuditAction`/`DecisionComment` domain tests,
`Decision.copyWith` (3 cases), `MockDecisionRepository`'s write behaviors
(approve/reject/requestRevision/discuss, validation, statefulness,
`DecisionNotFoundException`), `decisionDetailProvider`,
`decision_detail_screen_test.dart` (8 cases: full context rendering, empty
discussion/audit copy, resolved-decision action-hiding, non-critical
approve, reject requiring justification before submit enables, critical
acknowledgement gating, discuss appending without changing state, discuss
requiring non-empty text), and one `app_router_test.dart` case pinning
inbox-card-tap → detail navigation with the right id.

Run: `flutter analyze` (clean) and `flutter test` (260/260, 0 regressions
— #24's dashboard tests, reading `Decision` only through the unchanged
`pendingDecisionsProvider` shape, needed no edits).

## Definition of done

- [x] Acceptance criteria met: context/impact/risks/evidence/affected
      entities/discussion all shown; approve/reject/request-revision/discuss
      implemented; rejection requires a non-empty justification (enforced
      both in the UI — submit disabled — and in the repository); critical
      actions require the decision-specific acknowledgement checkbox, not a
      generic confirmation; every resolution action appends a
      `DecisionAuditEvent`.
- [x] `flutter analyze` clean.
- [x] Focused tests added and passing; full suite still green (260/260).
- [x] Operator review (operator directed merge/push/close directly).
- [ ] Council pass (optional — not run for this delivery, same as #23-#25).
- [x] Commit, merge to `development` (`dac015d`), push, close #26 on GitHub.
