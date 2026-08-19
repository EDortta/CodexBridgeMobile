# Phase 2 Resume

- work_id: WK-20260819-gh-24-project-operational-dashboard
- date: 2026-08-19
- status: #23 and #24 both finished, merged, pushed, and closed on GitHub

## Current state

`feature/gh-23/build-projects-list-search-and-filters` implements #23:
project cards with a health badge (active/unhealthy/pending decision/offline,
never color alone — icon and label always shown), a card-visible
`attentionSummary` so a project needing attention is legible without
opening it, a search field, a single-select health/favorites filter chip
row, and locally-persisted favorites (`SecureProjectFavoritesStore`, reusing
the Keystore seam `SecureKeyValueStore` already shares with #21/#22 — fails
open on read since favorites are a convenience, not a secret).

`flutter analyze`: clean. `flutter test`: 182/182 passing (25 new: domain,
data, controller, pure-filter and widget tests for #23).

Not validated:
- The real Android Keystore path (`FlutterSecureKeyValueStore`) — no host-VM
  test can reach it; same limit `secure_server_config_store_test.dart`
  documents for #21.
- A multi-round adversarial council pass, unlike #21/#22/#31/#32. This
  delivery had a single self-review pass instead; flagging in case the
  operator wants the fuller process run separately before merge.

## Decision made without an operator round-trip (documented here, not silently assumed)

"Offline" appears twice in #23's acceptance text: as one of the four filter
categories, and in "loading, empty, error and offline states exist." Device
network-connectivity detection was **not** built as a separate screen-level
state: `ProjectRepository` is still `MockProjectRepository`, so there is no
real network call yet for a connectivity banner to describe, and
`ProjectHealth.offline` already carries the "this project is unreachable"
meaning on both the card and the filter chip. Building real connectivity
detection (a new `connectivity_plus`-style dependency) against a fake
repository would be inventing infrastructure ahead of the real contract —
the exact mistake `docs/napkin-lessons.md`'s 2026-08-04 entry warns against.
Revisit when #24 or a real `HttpProjectRepository` (blocked on CodexBridge
#5) gives this a real network call to report on.

## #24 — Implement project operational dashboard

Branch `feature/gh-24/project-dashboard`. `ProjectDashboardScreen`
(`lib/app/`, composition root — imports across `projects`, `missions`,
`decisions`, `issues`, `artifacts`, `activity`, which only `app/` is allowed
to do) renders 7 grouped `Card` sections in the issue's own order: health,
current mission, sessions (full `SessionCard`, pause/resume/stop included),
priority issues, pending decisions, recent artifacts, recent activity.
Reached via `?project=<id>` on the existing `/projects/detail` route — the
same query-param convention `?session=<id>` already established for Work.

New: `lib/core/format/relative_moment.dart` (injectable-clock "how long ago"
+ staleness helper — decisions stale past 24h, artifacts/activity past 7
days); `lib/features/issues/`, `lib/features/artifacts/`,
`lib/features/activity/` (full features, mock-backed, per operator
decision); `Mission.projectId`, `Decision.projectId`/`.requestedAt`
(additive). Extracted `SessionCard`
(`lib/features/missions/presentation/session_card.dart`) and
`project_health_presentation.dart` — both now genuinely reused by two call
sites.

Issues/artifacts/activity items open an in-place `AlertDialog` (no new
routes — #29/#30/#35/#36 own those screens and are not started); current
mission links to the Work destination root (Mission has no detail screen,
#28 not started); pending decisions link to the existing `/decisions` root
route.

`flutter analyze`: clean. `flutter test`: 211/211 passing (29 new: this
delivery's own tests, plus 3 pre-existing tests updated —
`test/widget_test.dart` and `test/features/sessions/presentation/work_screen_test.dart`
for the mock mission data growing from 1 to 3 items pushing content past the
default test-surface build extent, and `test/app/app_router_test.dart`'s 3
`'Projects detail placeholder'` assertions replaced with real
`ProjectDashboardScreen` checks — both expected consequences of #24's own
requirement, not incidental changes).

Not validated:
- The real Android Keystore path and a real on-device/emulator visual check
  — `flutter build apk --debug` failed on a pre-existing environment NDK
  issue unrelated to this change (`docs/napkin-lessons.md`, 2026-08-03
  WK-20260803-gh-16 entry documents the same class of NDK setup problem).
- A multi-round adversarial council pass, unlike #21/#22/#31/#32 — single
  self-review pass instead, same as #23.

## Judgment calls made without a further operator round-trip (documented, not silently assumed)

- **Issues/artifacts/activity link-out = in-place dialog, not a new screen**
  — operator decision, see commit message and this file's #24 section above.
- **Mission/Decision get `projectId` (and Decision gets `requestedAt`)** —
  operator decision.
- **Sessions section reuses full `SessionCard`**, not a condensed summary —
  operator decision.
- **`projectByIdProvider` derives from the already-loaded `projectsProvider`
  list** rather than adding a `loadProject(id)` repository method —
  `MockProjectRepository` always returns every record anyway; a future real
  HTTP implementation can replace the provider's body without touching call
  sites.
- **CodexBridge #13 named as activity's closest backend issue, explicitly
  flagged as an imperfect match** (live push/subscription contract, not a
  historical log) rather than silently treated as a confirmed fit.

## Next Step (DO THIS FIRST)

#24 is done: merged to `development` (`c92a5ec`), pushed, closed on GitHub.
Epic #3's own remaining issues (#29/#30 epics/issues browser, #35/#36
artifacts) are natural next candidates — several are now less work thanks to
#24's new `issues`/`artifacts` features.

Correction (2026-08-19, during #25): the line this replaced mislabeled
#25/#26 as "Epic #3's remaining issues" — they belong to **Epic #4**
(Centro de Decisões), tracked from `docs/issues/phase-3/` onward. #25 is
already done; see `docs/issues/phase-3/RESUME.md`.
