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

- [#23 — Build projects list, search and filters](https://github.com/EDortta/CodexBridgeMobile/issues/23) — size M, **finished**. See `issues/23-build-projects-list-search-and-filters.md`.
- [#24 — Implement project operational dashboard](https://github.com/EDortta/CodexBridgeMobile/issues/24) — size L, not started.

## External dependency: the backend API contract

Epic #3 depends on Epics #1 and #2 (both satisfied) and, for real data, on
**CodexBridge #5 — Expose projects and project operational summary API**,
which is still open and unimplemented. `MockProjectRepository` stands in
until then, the same shape #21 and #22 used for the server/auth contract
before CodexBridge #2/#3 shipped.

| CodexBridge | What it fixes | Status | Binds |
|---|---|---|---|
| [#5](https://github.com/EDortta/CodexBridge/issues/5) | projects and project operational summary API | **open, not implemented** | #23 (fake), #24 |
