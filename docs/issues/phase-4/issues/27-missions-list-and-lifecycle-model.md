# #27 — Build missions list and lifecycle model

- status: [review]
- work_id: WK-20260819-gh-27-missions-list-and-lifecycle-model
- public issue: https://github.com/EDortta/CodexBridgeMobile/issues/27
- parent epic: https://github.com/EDortta/CodexBridgeMobile/issues/5
- branch: `feature/gh-27/missions-list-and-lifecycle-model`

## Context

`WorkScreen`'s `_MissionCard` was Phase-0 shell scaffolding: title, a
static "Terminal móvel" badge, id, and a one-line free-text status. No
stage/risk/state model existed, no filters, no owner/progress/elapsed/
latest-event display, and no way to tell a mission needing intervention
from a routine one beyond reading its status string.

## Objective (from the public issue)

Model mission stages and create list/filter UI by project, stage, risk and
state. Acceptance criteria: mission cards show owner, progress, elapsed
time, latest event and intervention requirement; stage transitions are
represented consistently.

## Scope

- `MissionStage`, `MissionRisk`, `MissionState` domain enums.
- `Mission` gains `stage`, `risk`, `state`, `owner`, `progress`,
  `startedAt`, `latestEvent`, `blockedReason`, `needsIntervention`
  (computed) — additive, shaped off CodexBridge #7.
- `filterMissions`: pure, combines project/stage/risk/state with AND.
- `WorkScreen` rewritten: filter row (4 `FilterMenuButton`s), richer
  `_MissionCard` (owner/stage/risk/state badges via `InlineBadge`, progress
  bar, elapsed time, latest event, intervention banner), two distinct
  empty states.
- `FilterMenuButton` and `InlineBadge` extracted from `decisions/` to
  `core/presentation/` — now shared by two features.

Out of scope: mission detail/timeline screen and pause/resume/cancel/
explain controls — #28 owns those.

## ARO (Allowed / Prohibited / Out of scope) — carried from `docs/limits.md`

Implemented within "explicitly requested mobile-client issue, including
focused tests" (Allowed). No backend, auth, persistence-contract or
device-permission change. `Mission`'s new fields are additive; only
`title`/`status` are read outside `features/missions/` (grepped before
changing), both untouched.

## Test plan

21 new tests: `MissionStage`/`MissionRisk`/`MissionState` label tests,
`Mission.needsIntervention`, `mock_mission_repository_test.dart` (fixture
shape: no dup ids, `codex-bridge-cli` still mission-free for #24's empty
state, a blocked mission present with a reason, pinned
`mobile-foundation`/`desktop-shell-review` fixture text), `filterMissions`
pure combinations, and `work_screen_test.dart` (8 cases: full card content,
intervention banner shown/hidden, stage filter, state filter, no-match
empty state + clear, zero-missions empty state).

Run: `flutter analyze` (clean) and `flutter test` (281/281, 0 regressions
— confirmed via the pinned `mobile-foundation`/`Desktop shell review` text
in `test/widget_test.dart` and `test/app/project_dashboard_screen_test.dart`).

## Definition of done

- [x] Acceptance criteria met: cards show owner, progress, elapsed time,
      latest event, and intervention requirement (icon + explicit label +
      reason, never color/border alone); stage represented via one
      consistent `MissionStage` enum across card, filter and (future)
      detail screen.
- [x] `flutter analyze` clean (including the repo's design-token lint test,
      which caught a hardcoded corner radius on first run — fixed by
      removing the clip rather than adding a one-off token).
- [x] Focused tests added and passing; full suite still green (281/281).
- [ ] Operator review.
- [ ] Council pass (optional — not run for this delivery, same as #23-#26).
- [ ] Commit, merge to `development`, push, close #27 on GitHub.
