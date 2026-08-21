# Phase 4 — Missões

- work_id: WK-20260819-gh-27-missions-list-and-lifecycle-model
- date: 2026-08-19
- public epic: https://github.com/EDortta/CodexBridgeMobile/issues/5

First phase folder for Epic #5. Depends on Epics #1, #2 and #3 (all
satisfied). Chosen as the next work after Epic #4 (#25/#26) closed: natural
epic order, dependencies satisfied, and the same list+filters /
detail+actions shape #25/#26 just proved out — see
`docs/issues/phase-3/RESUME.md`'s final entry for the reasoning and the
`gh issue view` sweep across #23/#24/#27-#40 that picked it.

## Issues

- [#27 — Build missions list and lifecycle model](https://github.com/EDortta/CodexBridgeMobile/issues/27) — size M, **finished and closed**. Commit `6a37230`, merged `f30cec5`. See `issues/27-missions-list-and-lifecycle-model.md`.
- [#28 — Implement mission detail, timeline and controls](https://github.com/EDortta/CodexBridgeMobile/issues/28) — size L, **finished and merged** into `development` (`b0ac4a1`, confirmed 2026-08-21). See `issues/28-implement-mission-detail-timeline-and-controls.md`.

## External dependency: the backend API contract

**CodexBridge #7 — Expose missions and mission-control API** is still open
and unimplemented. `MockMissionRepository` stands in until
then. Its proposed scope names the same fields #27 needed: "Filters for
project, stage, state, risk and blocked status" and "Objective, assigned
agent, progress, dependencies and related entities" —
`Mission`'s new fields (`stage`, `risk`, `state`, `owner`, `progress`,
`startedAt`, `latestEvent`, `blockedReason`) follow that shape directly.

| CodexBridge | What it fixes | Status | Binds |
|---|---|---|---|
| [#7](https://github.com/EDortta/CodexBridge/issues/7) | missions API (list, detail, timeline, pause/resume/cancel/explain) | **open, not implemented** | #27 (fake), #28 |
