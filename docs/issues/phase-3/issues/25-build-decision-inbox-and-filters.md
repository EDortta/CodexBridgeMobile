# #25 — Build decision inbox and filters

- status: [finished]
- work_id: WK-20260819-gh-25-decision-inbox-and-filters
- public issue: https://github.com/EDortta/CodexBridgeMobile/issues/25
- parent epic: https://github.com/EDortta/CodexBridgeMobile/issues/4
- branch: `feature/gh-25/build-decision-inbox-and-filters`

## Context

`decisions_screen.dart` (Phase 0 shell scaffolding) was a 39-line
placeholder: `ListTile`s with no filters and no tap. `Decision` itself only
had `{id, projectId, title, requestedBy, requestedAt}` — none of urgency,
risk, state or deadline existed.

## Objective (from the public issue)

Create the decision list with urgency, risk, status, project and deadline
filters. Acceptance criteria: pending and critical decisions are visually
distinct; filters can be combined; each item shows request, impact and
agent recommendation summary.

## Scope

- `DecisionUrgency`, `DecisionRisk`, `DecisionState` domain enums.
- `Decision` gains `urgency`, `risk`, `state`, `deadline`, `impactSummary`,
  `recommendationSummary` (additive), shaped off CodexBridge #6's proposed
  scope.
- `DecisionRepository.loadPendingDecisions()` → `loadDecisions()` (all
  states now); `pendingDecisionsProvider` becomes a derived view narrowed to
  `pending`, so #24's dashboard needed no changes.
- `lib/features/decisions/presentation/decision_filter.dart`:
  `DecisionDeadlineFilter` + pure `classifyDeadline`.
- `filterDecisions`: pure, combines all 5 axes with AND.
- `DecisionsScreen` rewritten: 5 independent filter menus (urgency, risk,
  state, project, deadline), defaults to `state == pending`, critical
  decisions bordered + explicitly labeled "Critical", resolved decisions
  recede (opacity, text-labeled — never opacity alone), two distinct empty
  states (no decisions at all vs. no match, with a "Clear filters" action).

Out of scope: per-item navigation/detail (#26 owns the decision detail
route and screen); approve/reject/request-revision actions (#26).

## ARO (Allowed / Prohibited / Out of scope) — carried from `docs/limits.md`

Implemented within "explicitly requested mobile-client issue, including
focused tests" (Allowed). No backend, auth, persistence-contract or
device-permission change. `Decision`'s constructor changed, but only its own
mock repository and its own domain test construct it (grepped before
changing).

## Test plan

24 new tests: `DecisionUrgency`/`DecisionRisk`/`DecisionState` label tests
(model on `test/features/projects/domain/project_health_test.dart`),
`mock_decision_repository_test.dart` (fixture shape: no dup ids, both
pending and resolved states present, `codex-bridge-desktop` keeps exactly
the 2 pending decisions #24 pins), `decision_filter_test.dart`
(`classifyDeadline` boundary cases), `decision_providers_test.dart`
(`filterDecisions` combinations + `pendingDecisionsProvider`'s derivation
via `ProviderContainer`), `decisions_screen_test.dart` (7 cases: default
pending-only view, critical-label distinctness, request/impact/
recommendation all shown, urgency filter, state filter reaching a resolved
decision, no-match empty state + clear, zero-decisions empty state).

Run: `flutter analyze` (clean) and `flutter test` (235/235, 0 regressions —
#24's `project_dashboard_screen_test.dart` re-verified passing unchanged
against the expanded `Decision` model and renamed repository method).

## Definition of done

- [x] Acceptance criteria met: urgency/risk/status/project/deadline filters,
      independently selectable and AND-combined; critical decisions visually
      distinct (red border + explicit "Critical" label, never color alone);
      each card shows request (title), impact and recommendation summary.
- [x] `flutter analyze` clean.
- [x] Focused tests added and passing; full suite still green (235/235).
- [ ] Operator review.
- [ ] Council pass (optional — not run for this delivery, same as #23/#24).
- [ ] Commit, merge to `development`, push, close #25 on GitHub.
