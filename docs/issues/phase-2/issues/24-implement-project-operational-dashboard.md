# #24 — Implement project operational dashboard

- status: [review]
- work_id: WK-20260819-gh-24-project-operational-dashboard
- public issue: https://github.com/EDortta/CodexBridgeMobile/issues/24
- parent epic: https://github.com/EDortta/CodexBridgeMobile/issues/3
- branch: `feature/gh-24/project-dashboard`

## Context

`_ProjectCard.onTap` (#23) landed on a generic, unparameterized placeholder
in `lib/app/destination_detail_screen.dart` — the same file that already
proved the one real precedent for cross-feature detail navigation (Work →
Session, via a `?session=<id>` query parameter). No project detail screen
existed. Of the five sections #24 asks for, only sessions
(`LiveSession.projectId`) and, partially, decisions/missions (unscoped) had
any domain model at all; priority issues, artifacts and activity had none.

## Objective (from the public issue)

Create project overview with health, current mission, sessions, priority
issues, pending decisions, recent artifacts and activity. Acceptance
criteria: each section links to its entity; stale data is marked; content is
grouped rather than shown as one long list.

## Scope

- `ProjectDashboardScreen` (`lib/app/project_dashboard_screen.dart`),
  reached via `?project=<id>` on `/projects/detail`, composing 7 grouped
  `Card` sections.
- `lib/core/format/relative_moment.dart`: injectable-clock relative-time +
  staleness helper, shared by decisions/artifacts/activity.
- `Mission.projectId`, `Decision.projectId`/`.requestedAt` (additive).
- New features `lib/features/issues/`, `lib/features/artifacts/`,
  `lib/features/activity/` (domain/data/presentation, mock-backed).
- Extracted `SessionCard` and `project_health_presentation.dart` (now
  reused by two call sites each).
- `_ProjectCard.onTap` now carries `?project=<id>`.

Out of scope: real detail screens/routes for missions (#28), issues
(#29/#30), decisions (#26), artifacts (#35/#36) — the dashboard links to
what exists today (Work root, `/decisions` root) or opens an in-place dialog
for what doesn't.

## ARO (Allowed / Prohibited / Out of scope) — carried from `docs/limits.md`

Implemented within "explicitly requested mobile-client issue, including
focused tests" (Allowed). No backend, auth, persistence-contract or
device-permission change. `Mission`/`Decision` field additions are additive
and internal-only (only their own mock repositories constructed them).

## Test plan

29 new tests across: `test/core/format/relative_moment_test.dart` (pure
describe/isStale, including threshold boundary), domain label/round-trip
tests for `IssuePriority`, `Mission`, `Decision`, fixture-shape tests for
the two new mock repositories with real cross-project data,
`session_card_test.dart` (re-pins the extraction),
`project_health_presentation_test.dart` (extraction), and
`test/app/project_dashboard_screen_test.dart` (8 cases: every populated
section renders, both empty-state and not-found paths, staleness marking
against real fixture data with a pinned clock, all three link-out
mechanisms — dialog, `/decisions`, full `SessionCard`).

3 pre-existing tests updated as a direct, expected consequence of this
issue's own requirement (not incidental): `test/widget_test.dart` and
`test/features/sessions/presentation/work_screen_test.dart` (mock mission
data grew 1→3 items, pushing content past the default test-surface build
extent — fixed with `findsWidgets`/`scrollUntilVisible` rather than
shrinking the mock data back down) and `test/app/app_router_test.dart` (3
`'Projects detail placeholder'` assertions now check for the real
`ProjectDashboardScreen`, plus one new case pinning that the tapped card's
id reaches it).

Run: `flutter analyze` (clean) and `flutter test` (211/211, no regressions).

## Definition of done

- [x] Acceptance criteria met: 7 sections grouped as separate `Card`s (not
      one long list); each links to its entity (dialog for issues/artifacts/
      activity, `/decisions` for decisions, Work root for the current
      mission, `?session=<id>` for sessions — see `RESUME.md` for why each
      target was chosen); stale decisions/artifacts/activity marked with an
      icon + muted relative-time text, never color alone.
- [x] `flutter analyze` clean.
- [x] Focused tests added and passing; full suite still green (211/211).
- [ ] Operator review.
- [ ] Council pass (optional — not run for this delivery, same as #23).
- [ ] Commit, merge to `development`, push, close #24 on GitHub.

Not validated: real Android Keystore path; on-device/emulator visual check
(`flutter build apk --debug` blocked by a pre-existing environment NDK
issue, unrelated to this change).
