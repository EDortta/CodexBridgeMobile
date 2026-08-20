# #28 — Implement mission detail, timeline and controls

- status: [finished, pending operator review/merge]
- work_id: WK-20260820-gh-28-mission-detail-timeline-and-controls
- public issue: https://github.com/EDortta/CodexBridgeMobile/issues/28
- parent epic: https://github.com/EDortta/CodexBridgeMobile/issues/5
- branch: `feature/gh-28/mission-detail-timeline-and-controls`

## Context

A supervised overnight cloud routine (`RemoteTrigger` id
`trig_01Mepr68impzTrGjDvzmnJRk`, armed at the close of the #27 session, meant
to fire `2026-08-20T02:00:00Z`) was checked at session start: `gh pr list`
showed no open PRs, `gh issue view 28`/`29` showed both still open with no
comments, and no `feature/gh-28/...` branch existed locally or on
`origin` — `git log --oneline origin/development` topped out at the
doc-only commit that armed the routine. Current time was well past the
scheduled fire time. The `RemoteTrigger` tool itself was not available in
this session (`ToolSearch` found no match for it), so the routine's own run
log could not be inspected directly — but the complete absence of any
branch, PR, or issue comment is conclusive on its own: the routine produced
no artifacts. Picked up #28 manually per the operator's fallback
instruction.

`_MissionCard` (`work_screen.dart`, #27) tapped through to
`AppDestination.work.detailPath` with no id at all — #28 is the first
issue to actually need a mission's own detail route.

## Objective (from the public issue)

Show objective, stages, dependencies, timeline, tests, files, artifacts and
related decisions; add pause, resume, cancel and explain controls.
Acceptance criteria: blocked state includes cause; commands require
confirmation appropriate to impact; timeline records every relevant
transition.

## Scope

- `MissionTimelineEvent` (id, description, actor, occurredAt) and
  `MissionControlAction` (pause/resume/cancel, `requiresConfirmation`) —
  new domain types.
- `Mission` gains `objective`, `dependencies`, `timeline`, `tests`, `files`,
  `artifacts`, `relatedDecisionIds` (all additive, defaulted), plus
  `canPause`/`canResume`/`canCancel` guards, `explanation` (computed,
  local — no repository round trip), and a `copyWith` that auto-clears
  `blockedReason` on any transition out of `blocked`.
- `MissionRepository` gains `loadMission`, `pause`, `resume`,
  `cancel(reason:)`, plus `MissionNotFoundException` and
  `MissionControlNotAllowedException`.
- `MockMissionRepository` becomes stateful (mirrors
  `MockDecisionRepository`): control actions mutate an in-memory map and
  append a timeline entry; existing fixture `id`/`projectId`/`title`/
  `status` values are untouched, only new fields added.
- `MissionDetailScreen` (new): summary (badges, progress, blocked-cause
  banner in text, never color/badge alone), dependencies, tests/files/
  artifacts, related-decisions links (plain ids — `features/missions/`
  never imports `features/decisions/`; navigates via `AppRoutes` from
  `core/navigation/`), actions (pause/resume — no confirmation, mirrors
  `LiveSessionControlAction`'s own reversible pair; cancel — always a
  required reason, plus an explicit acknowledgement checkbox naming the
  mission when `MissionRisk.high`, the same escalation
  `DecisionDetailScreen` built for a critical decision rather than
  `runSessionControlAction`'s generic Yes/No), explain (local dialog over
  `Mission.explanation`), and timeline.
- `_MissionCard.onTap` now carries `?mission=<id>`;
  `DestinationDetailScreen` gets a `work` + `mission` branch alongside its
  existing `work` + `session` one.

Out of scope: a real backend for missions (CodexBridge #7 is still open;
`MockMissionRepository` continues to stand in) and Epic #6 (#29 — not
started; the operator caps this session at #28 alone per the original
overnight-run consent, and the routine that would have covered #29 never
ran).

## ARO (Allowed / Prohibited / Out of scope) — carried from `docs/limits.md`

Implemented within "explicitly requested mobile-client issue, including
focused tests" (Allowed). No backend, auth, persistence-contract or
device-permission change. `Mission`'s new fields are additive; grepped for
external readers of the unchanged fields before touching anything.

## Test plan

New/updated: `mission_timeline_event_test.dart`,
`mission_control_action_test.dart`, `mission_test.dart` (control guards,
`explanation`, `copyWith`'s auto-clear-on-unblock), `mock_mission_repository_test.dart`
(`loadMission` incl. not-found, `pause`/`resume`/`cancel` incl. each
not-allowed exception, empty-reason rejection, state sticks across a second
load), `mission_providers_test.dart` (`missionDetailProvider`),
`mission_detail_screen_test.dart` (objective/dependencies/tests/files/
artifacts render, blocked-cause text, related-decision links, guard-driven
button visibility per state, pause flips state, cancel — plain reason vs.
high-risk acknowledgement gate, explain dialog, timeline list), plus a
`work_screen_test.dart` fake-repository update (new interface methods) and
an `app_router_test.dart` case asserting a tapped mission card carries its
id to `MissionDetailScreen`.

Run: `flutter analyze` (clean, including the repo's design-token lint —
caught one hardcoded `EdgeInsets.only(bottom: 0)` on first run, fixed by
dropping the `last`-item special case rather than adding a token for a
non-visual difference) and `flutter test` (full suite green, 0 regressions
— see commit for the exact count).

## Definition of done

- [x] Acceptance criteria met: blocked state's cause is always shown in
      text on the detail screen (never only the state badge); cancel
      always requires a reason and, for a high-risk mission, an explicit
      acknowledgement — pause/resume stay confirmation-free as the
      reversible pair they are; every control action appends a timeline
      entry.
- [x] `flutter analyze` clean.
- [x] Focused tests added and passing; full suite green.
- [x] Reviewer pass (`.docs/agents/reviewer.md`, retroactive, 2026-08-20):
      NEEDS IMPROVEMENT -> APPROVED after 2 fixes (`Mission.copyWith`'s
      missing blocked-without-reason guard; `MissionDetailScreen`'s
      untested error branch). See `docs/issues/phase-4/RESUME.md`'s
      "#28 retroactive reviewer + council pass" section for detail.
- [x] Council pass (`.docs/agents/council.md`, retroactive, 2026-08-20,
      round 1 only — every finding closed before a round 2 was needed): 2
      findings under "the second caller" lens, both fixed with a failing-
      before/passing-after test each (dashboard mission card missing its
      `?mission=<id>` deep link; `MockMissionRepository`'s pause/resume/
      cancel race). Sweep-skeptic and claim-auditor lenses returned no
      finding. Full detail and the round tally in
      `docs/issues/phase-4/RESUME.md`.
- [x] `flutter analyze` clean, `flutter test` 324/324 (6 new since the
      pre-review baseline of 318), 0 regressions — re-run after every fix.
- [ ] Operator review (pending — this delivery was picked up because the
      armed overnight routine produced nothing to review instead; the
      reviewer + council passes above are this session's own gates, not a
      substitute for the operator's own review before merge).
- [ ] Commit, merge to `development`, push, close #28 on GitHub — all
      operator-gated, not done by this session per the standing "stop
      before merge" instruction.
