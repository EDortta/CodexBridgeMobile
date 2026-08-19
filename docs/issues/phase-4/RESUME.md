# Phase 4 Resume

- work_id: WK-20260819-gh-27-missions-list-and-lifecycle-model
- date: 2026-08-19
- status: #27 finished, merged (`f30cec5`), pushed, and closed on GitHub; #28 not started

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

## Next Step (DO THIS FIRST)

#27 is done: merged to `development` (`f30cec5`), pushed, closed on GitHub.

**#28 — Implement mission detail, timeline and controls** (size L) is next:
show objective, stages, dependencies, timeline, tests, files, artifacts and
related decisions; add pause, resume, cancel and explain controls. Expect
the same shape #26 used for decisions — a detail screen reached via
`?mission=<id>` on a new `/work/detail` variant (today `/work/detail`'s
`DestinationDetailScreen` branch for `AppDestination.work` only recognizes
`?session=<id>`; a mission id will need its own branch there, decided
during #28, not here) — plus pause/resume/cancel needing the same
non-generic confirmation treatment #26 built for critical decisions, since
Epic #5's own acceptance criteria echo the same "commands require
confirmation appropriate to impact" language.
