# Phase 2 — Projetos e dashboard operacional

- work_id: WK-20260819-gh-23-projects-list-search-and-filters
- date: 2026-08-19
- public epic: https://github.com/EDortta/CodexBridgeMobile/issues/3

This is the first phase folder for Epic #3. Phase 1 (Epic #2, `docs/issues/phase-1/`)
closed on 2026-08-19; Epic #7 (#31/#32, sessions) shipped out of order alongside
it and has no phase folder of its own — see `docs/issues/phase-1/README.md`'s
"Out-of-order work" section. Given that precedent, phase folders in this
repository track an epic each rather than a strict chronological sequence.

## Issues

- [#23 — Build projects list, search and filters](https://github.com/EDortta/CodexBridgeMobile/issues/23) — size M, **finished and closed**. Commit `93b9c85`, merged `db69745`. See `issues/23-build-projects-list-search-and-filters.md`.
- [#24 — Implement project operational dashboard](https://github.com/EDortta/CodexBridgeMobile/issues/24) — size L, **finished and closed**. Commit `43cc3e4`, merged `c92a5ec`. See `issues/24-implement-project-operational-dashboard.md`.

## New features introduced by #24

Three small features were added to back sections #24 needs and no earlier
issue created: `lib/features/issues/` (`ProjectIssue`, named to avoid
colliding with "GitHub issue"), `lib/features/artifacts/`
(`Artifact`), `lib/features/activity/` (`ActivityEntry`). Each follows the
same domain/data/presentation shape as `projects`/`decisions`, mock-backed
until a real backend contract exists.

## External dependency: the backend API contract

Epic #3 depends on Epics #1 and #2 (both satisfied) and, for real data, on
several still-open CodexBridge issues. `MockProjectRepository` and the mocks
introduced by #24 stand in until then, the same shape #21 and #22 used for
the server/auth contract before CodexBridge #2/#3 shipped.

| CodexBridge | What it fixes | Status | Binds |
|---|---|---|---|
| [#5](https://github.com/EDortta/CodexBridge/issues/5) | projects and project operational summary API | **open, not implemented** | #23, #24 (health/attention) |
| [#8](https://github.com/EDortta/CodexBridge/issues/8) | Epics and Issues API | **open, not implemented** | #24 (priority issues section) |
| [#11](https://github.com/EDortta/CodexBridge/issues/11) | artifacts, downloads and APK metadata API | **open, not implemented** | #24 (recent artifacts section) |
| [#13](https://github.com/EDortta/CodexBridge/issues/13) | mobile event stream and notification subscription API | **open, not implemented** | #24 (recent activity section) — closest fit, not a precise match; it is a live push/subscription contract, not a historical activity log |
