# #23 — Build projects list, search and filters

- status: [finished]
- work_id: WK-20260819-gh-23-projects-list-search-and-filters
- public issue: https://github.com/EDortta/CodexBridgeMobile/issues/23
- parent epic: https://github.com/EDortta/CodexBridgeMobile/issues/3
- branch: `feature/gh-23/build-projects-list-search-and-filters`

## Context

Phase 0's navigation shell (`d0cdda2`) left `ProjectsScreen` as a 38-line
placeholder `ListView` with no search, favorites, or health filtering —
enough to prove the shell's routing, not to satisfy this issue.

## Objective (from the public issue)

Create project cards, search, favorites and filters for active, unhealthy,
pending-decision and offline projects.

## Scope

- `ProjectHealth` domain enum (active/unhealthy/pendingDecision/offline)
  with a `label`, replacing the free-text `status` field.
- `ProjectSummary.attentionSummary`: short, card-visible reason a project
  needs attention.
- `MockProjectRepository` fixtures covering all four health values (real
  backend contract, CodexBridge #5, is still open — see `README.md`).
- `ProjectFavoritesStore` / `SecureProjectFavoritesStore`: local,
  Keystore-backed, fail-open-on-read favorites persistence.
- `ProjectFavoritesController` (`AsyncNotifier`): optimistic toggle with
  rollback on a refused write.
- `ProjectFilter` (presentation-only: all/favorites + the four health
  values) and a pure `filterProjectListItems` combining search text and the
  selected filter.
- `ProjectsScreen`: search field (state-preserving `TextEditingController`,
  not rebuilt per keystroke), single-select filter chip row, project cards
  with a health icon+label (never color alone), attention text, and a
  favorite-toggle star. Two distinct empty states (no projects at all vs.
  no match for the current search/filter, with a "Clear" action for the
  latter).

Out of scope: #24 (project detail/dashboard) — cards still navigate to the
existing placeholder detail route, untouched by this issue.

## ARO (Allowed / Prohibited / Out of scope) — carried from `docs/limits.md`

Implemented within "explicitly requested mobile-client issue, including
focused tests" (Allowed). No backend, auth, persistence-contract or
device-permission change (all Prohibited categories untouched). No IDE-style
or heavyweight editing capability added (Out of scope per
`docs/product-foundation.md`).

## Test plan

- `test/features/projects/domain/project_health_test.dart` — label mapping.
- `test/features/projects/data/secure_project_favorites_store_test.dart` —
  round-trip, own key, fail-open on missing/unreadable/corrupt value,
  write-refusal propagates.
- `test/features/projects/presentation/project_favorites_controller_test.dart`
  — toggle on/off, persists under the right key, rollback on a refused write.
- `test/features/projects/presentation/filter_project_list_items_test.dart`
  — pure search+filter combinations, so a regression fails a unit test before
  a widget test.
- `test/features/projects/presentation/projects_screen_test.dart` — full
  list render, attention text visible without opening a card, search
  narrows, a health filter chip narrows, both empty states (and the "Clear"
  action), favorite toggle updates the icon and persists, favorites filter.

Run: `flutter analyze` (clean) and `flutter test` (182/182, including the
pre-existing suite — no regression).

## Definition of done

- [x] Acceptance criteria met: loading/empty/error states exist (loading and
      error via the shared `AsyncStateView`; two distinct empty states are
      screen-specific, see `RESUME.md` for how "offline" was scoped);
      favorites persist locally; attention states visible without opening
      the project.
- [x] `flutter analyze` clean.
- [x] Focused tests added and passing; full suite still green.
- [x] Operator review (operator directed merge/push/close directly).
- [ ] Council pass (optional — not run for this delivery; see `RESUME.md`).
- [x] Commit, merge to `development` (`db69745`), push, close #23 on GitHub.
