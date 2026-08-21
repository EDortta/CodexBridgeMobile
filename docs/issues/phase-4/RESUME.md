# Phase 4 Resume

- work_id: WK-20260820-gh-28-mission-detail-timeline-and-controls
- date: 2026-08-20
- status: #27 finished, merged (`f30cec5`), pushed, and closed on GitHub;
  #28 finished, reviewer pass + council round 1 both complete, all findings
  fixed and tested, **merged `b0ac4a1` (`--no-ff`, 2026-08-20), pushed to
  `origin/development`, closed on GitHub** (operator-approved, feature
  branch deleted); #29 started 2026-08-20 (operator-authorized, after #28's
  merge — see "Overnight run outcome" below for why it didn't start
  earlier)

## Current state

`feature/gh-27/missions-list-and-lifecycle-model` implements #27.
`WorkScreen`'s mission section was Phase-0 shell scaffolding (`_MissionCard`
showing only title/id/status) — extended with project/stage/risk/state
filters that combine (`filterMissions`, pure and independently tested) and
richer cards: owner, stage/risk/state badges, a progress bar, elapsed time
since start (`RelativeMoment.describe`), the latest event, and — for a
blocked mission — an explicit "Needs your attention" banner with the reason,
never conveyed by the card's red border alone.

`Mission` gained `stage` (`MissionStage`), `risk` (`MissionRisk`), `state`
(`MissionState`), `owner`, `progress`, `startedAt`, `latestEvent`,
`blockedReason`, and a `needsIntervention` getter — all additive; `title`
and `status` (the free-text summary #24's dashboard already reads) are
untouched, so `project_dashboard_screen.dart` needed **zero changes**.
Shaped directly off CodexBridge #7's proposed scope (see `README.md`)
rather than guessed independently.

Two widgets were extracted to `core/presentation/` because `missions/` now
needs the exact same patterns `decisions/` (#25/#26) already built:
`FilterMenuButton<T>` (was `decisions_screen.dart`'s private
`_FilterMenuButton`) and `InlineBadge` (was `decision_badge.dart`'s
`DecisionBadge`). Both now have three call sites across two features —
the same "shared pattern belongs in `core/`" reasoning `SessionCard` and
`project_health_presentation.dart` already established, just crossing a
second feature boundary this time instead of two call sites in one.

`flutter analyze`: clean. `flutter test`: 281/281 passing (21 new, 0
regressions — confirmed #24's dashboard tests, which read `Mission` only
through `title`/`status`, and `test/widget_test.dart`'s pinned
`mobile-foundation` fixture text, both pass unchanged).

Not validated: same as #23-#26 (real Android Keystore path, on-device
visual check blocked by the pre-existing NDK environment issue, no
multi-round council).

## A real bug the design-token lint test caught immediately

`test/core/design/app_tokens_test.dart` (a pre-existing repo-wide scanner,
not new to this delivery) failed on the first `flutter test` run: a
`ClipRRect(borderRadius: BorderRadius.circular(4), ...)` wrapping the new
progress bar hardcoded a corner radius instead of using `AppRadius`. Fixed
by dropping the clip entirely (`LinearProgressIndicator` alone) rather than
inventing a new one-off `AppRadius` token for a single use. Worth naming in
case a future mission-detail screen (#28) wants a rounded progress bar for
real — that is the point at which a token earns its place, not before.

## Judgment calls made without a further operator round-trip (documented, not silently assumed)

- **`status` (free text) kept alongside the new typed `stage`/`state`.**
  Removing or deriving it from the new enums would have required touching
  `project_dashboard_screen.dart`; keeping it untouched is the same
  additive-first bias #25 applied to `Decision.title`.
- **`needsIntervention` derived from `state == blocked` only**, not a
  separate stored flag. Mirrors `LiveSession`'s `awaitingApproval` — a
  computed property over the state enum, not a second source of truth that
  could drift from it.
- **Elapsed time reuses `RelativeMoment.describe` with a "Started" prefix**
  rather than a new mission-specific duration formatter — "Started 3h ago"
  reads naturally and avoids a near-duplicate of an existing `core/`
  function for one screen.
- **`FilterMenuButton`/`InlineBadge` extracted to `core/presentation/`**
  once a second feature needed the identical widget — not preemptively
  when `decisions/` built them for #25/#26, matching this repo's
  "extract on the second genuine consumer, not the first" convention
  (`SessionCard`, `project_health_presentation.dart`).
- **The design-token lint failure was fixed by removing the clip, not by
  adding a token** — `docs/napkin-lessons.md`'s existing entries warn
  against inventing infrastructure (tokens included) ahead of a real,
  repeated need.

## Overnight run outcome — 2026-08-20

The routine armed at the close of the #27 session (`RemoteTrigger`,
`trig_01Mepr68impzTrGjDvzmnJRk`, `run_once_at` `2026-08-20T02:00:00Z` =
23:00 America/Sao_Paulo) **produced nothing**. At session start (well past
the fire time): `gh pr list -R EDortta/CodexBridgeMobile --state open`
returned no results, `gh issue view 28`/`29` both showed open with zero
comments, and no `feature/gh-28/...` branch existed locally or on
`origin` — `git log --oneline origin/development` topped out at the
doc-only commit (`8376ea1`) that armed the routine last session. The
`RemoteTrigger` tool itself was not available in *this* session — `ToolSearch
select:RemoteTrigger` found no match, so `list_runs`/`get_run_log` could not
be called to read the routine's own failure report. The absence of any
branch, PR, or issue-comment artifact is conclusive on its own regardless:
the routine did not deliver, whatever the underlying cause. Picked up #28
manually per the operator's documented fallback instruction; #29 was never
started (the operator's own cap was #28 mandatory, #29 only if a routine
run finished #28 cleanly — no routine run happened, so #29's gate was never
reached, and this session was not authorized to improvise past #28 alone).

**Open question for the operator**: is `trig_01Mepr68impzTrGjDvzmnJRk` still
armed/enabled, and did it error out silently, get disabled, or never fire
for an unrelated infra reason? This session had no tool access to check —
worth confirming from `https://claude.ai/code/routines` directly before
relying on a similar unattended run again.

## #28 delivered manually — 2026-08-20

Implemented on `feature/gh-28/mission-detail-timeline-and-controls`:
`MissionDetailScreen` (objective, dependencies, tests/files/artifacts,
related-decision links, timeline, and pause/resume/cancel/explain
controls), plus the supporting domain additions
(`MissionTimelineEvent`, `MissionControlAction`, `Mission`'s new fields and
guards, `MissionRepository`'s `loadMission`/`pause`/`resume`/`cancel`).
Full rationale, scope and test plan in
`issues/28-implement-mission-detail-timeline-and-controls.md`.

Cancel is the only control that confirms — always a required reason, plus
an explicit acknowledgement checkbox naming the mission when
`MissionRisk.high` — mirroring the escalation `DecisionDetailScreen` (#26)
built for a critical decision rather than `runSessionControlAction`'s
generic Yes/No. Pause/resume stay confirmation-free, matching
`LiveSessionControlAction`'s own reversible pair. A blocked mission's cause
is always rendered in text on the detail screen, never only implied by the
state badge.

`flutter analyze`: clean (the repo's design-token lint caught one hardcoded
`EdgeInsets.only(bottom: 0)` on the first run — fixed by dropping the
`last`-item special case, not by adding a token for a non-visual
difference, same call #27 made for its own clip). `flutter test`: full
suite green, 0 regressions.

Not validated: same as #23-#27 (real Android Keystore path, on-device
visual check blocked by the pre-existing NDK environment issue).

## #28 retroactive reviewer + council pass — 2026-08-20 (later same day)

The operator asked for the same rigor #23-#27 never got (unlike
CodexBridge's #17, which went through a reviewer pass, a council round 1
close, and a council round 2 close). `.docs/agents/reviewer.md` and
`.docs/agents/council.md` were run for real against
`feature/gh-28/mission-detail-timeline-and-controls`, in the order
`council.md` requires: reviewer first, council only on the approved result.

**Reviewer pass** (`reviewer.md`, straight, against the full branch diff)
— NEEDS IMPROVEMENT, two findings, both fixed:
- `Mission.copyWith` could move a mission into `MissionState.blocked` with
  no `blockedReason` (silently, if `state` is passed with no reason and
  none was already carried) — defeating the acceptance criterion "blocked
  state includes cause" for whatever future call site did that. No call
  site in this delivery triggers it (`MockMissionRepository._transition`
  never targets `blocked`), but the class's own doc comment already claims
  the inverse invariant (auto-clear on exit) without enforcing entry. Fixed:
  `copyWith` now throws `ArgumentError` on that transition
  (`lib/features/missions/domain/mission.dart`); tests in
  `test/features/missions/domain/mission_test.dart` (`copyWith` group).
- `MissionDetailScreen`'s `_errorMessage` switch (not-found vs. generic
  fallback) had zero test coverage — both arms untested. Fixed: two widget
  tests added to `mission_detail_screen_test.dart` (unknown id, and a
  `_FailingMissionRepository` fake for the generic-fallback arm).

After both fixes: `flutter analyze` clean, `flutter test` 322/322 (4 new,
0 regressions).

**Council pass** (`council.md`, default 3 lenses — sweep skeptic, claim
auditor, second caller — against the reviewer-approved diff; `docs/software-
overview.md` has no literally-named "Target Project Checklist" section, so
lens selection used its actual Product/Users/Constraints content instead;
noted rather than guessed past silently):

- **Sweep skeptic** — no finding. This delivery is new feature work, not a
  mechanical sweep/rename; the lens's own precedent does not apply here.
- **Claim auditor** — no finding. Every coverage/behavior claim in the
  issue doc and this file's own #28 section was checked against a real test
  file or a real `flutter analyze`/`flutter test` run; nothing was claimed
  that the diff does not back.
- **Second caller** — **2 findings, both survived §2, both fixed**:
  1. *Trigger*: on the Project Dashboard (#24), a project with an active
     mission — tap the "Current mission" card. *Wrong outcome*: lands on
     the general Work destination with no mission selected, instead of that
     mission's own detail screen — the exact deep-link `_MissionCard`
     (`work_screen.dart`, #28) established for the same gesture. *Where*:
     `lib/app/project_dashboard_screen.dart`, `_CurrentMissionCard.onTap`.
     *Evidence*: reproduced with a widget test that failed before the fix
     (`test/app/project_dashboard_screen_test.dart`, "tapping the current
     mission card…") — confirmed fail-without/pass-with by temporarily
     reverting the fix and re-running. Fixed: `onTap` now carries
     `?mission=<id>` the same way `_MissionCard` does.
  2. *Trigger*: two `pause`/`resume`/`cancel` calls for the same mission
     issued back-to-back (a double-tap before the button hides, or two
     callers racing the same mission) — both read `MockMissionRepository`'s
     pre-mutation state via `await loadMission`, since that `await` still
     yields to the microtask queue even against an already-completed
     Future. *Wrong outcome*: both calls "succeed" (no
     `MissionControlNotAllowedException`), and the second silently
     overwrites the first's mutation in `_missions` — a lost update, plus a
     duplicate timeline-event id, with no error surfaced anywhere. *Where*:
     `lib/features/missions/data/mock_mission_repository.dart`, `pause`/
     `resume`/`cancel`. *Evidence*: reproduced with a repository test
     issuing two unawaited `pause()` calls (`mock_mission_repository_test.dart`,
     "two calls issued back-to-back do not race…") — confirmed
     fail-without/pass-with the same way. Fixed: the guard check and the
     mutation now happen in one synchronous pass (`_applyGuarded`), closing
     the window instead of trusting every caller to serialize its own
     calls (`design-standards.md` §3).

Only one round was needed — every finding was fixed and its fix verified
before a round 2 would have been reached, so no finding stayed open past
round 1 and `governance-precedence.md` was never entered (no
member-vs-member disagreement arose either). After all four fixes (2
reviewer + 2 council): `flutter analyze` clean, `flutter test` 324/324 (6
new since the pre-review baseline, 0 regressions).

Round record (council.md §4's mandatory tally): reviewer findings raised 2,
survived 2, fixed 2, tests added 2. Council findings raised 2 (both under
"the second caller"), survived 2, fixed 2, tests added 2. Questions left
open: 0. No `governancekit --root . council --record` run — this project's
GovernanceKit machine-readable gate was not available in this session; the
record above is the manual equivalent `council.md` asks for when the
runtime tool is not present.

Not validated: same as #23-#27 (real Android Keystore path, on-device
visual check blocked by the pre-existing NDK environment issue). The
double-tap/race fix is validated at the repository layer (a fast,
deterministic unit test); a real gesture-level double-tap through the
actual `_ActionsCard` buttons was not separately reproduced with Flutter's
tap-timing APIs — the repository-level reproduction is the same underlying
race, just triggered directly rather than through two real taps.

## Next Step (DO THIS FIRST)

**#28 closed out, 2026-08-20**: operator reviewed and approved the merge
directly (relayed through the orchestrating session in the same
conversation) — `--no-ff` merge to `development` (`b0ac4a1`), `flutter
analyze`/`flutter test` re-confirmed green (324/324) post-merge, pushed to
`origin/development`, `feature/gh-28/...` deleted (`git branch -d`, refused
if unmerged — was), issue #28 closed on GitHub with a comment referencing
the merge commit. Cross-checked against the CodexBridge backend session in
parallel: CodexBridge #7 (missions API) is now merged into the gateway's
own `development` too (`16ce28e`) — see `README.md`'s updated "External
dependency" section for the real contract shape and why `MockMissionRepository`
still stands in.

Operator then authorized starting **#29 — Build Epics and Issues browser
(Epic #6)** in the same pattern as #28: own branch off `development`,
reviewer.md + council.md self-review, commit locally, **no push** pending a
separate operator confirmation. See this file's #29 section below for
progress.

Still open, not this session's to resolve: whether the overnight routine
(`trig_01Mepr68impzTrGjDvzmnJRk`) is still armed — operator is checking
`https://claude.ai/code/routines` directly; out of scope for any agent
session per the operator's own instruction.

**Phase 4 is closed.** #28 merged into `development` at `b0ac4a1` (confirmed
2026-08-21 by `git log`). Phase 5 (`docs/issues/phase-5/`) now owns #29 —
see `docs/issues/phase-5/RESUME.md` for its own Next Step. This file is kept
only as history; do not resume work from here.
