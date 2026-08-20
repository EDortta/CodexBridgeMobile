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
- [#28 — Implement mission detail, timeline and controls](https://github.com/EDortta/CodexBridgeMobile/issues/28) — size L, **finished and closed**. Merged `b0ac4a1` (`--no-ff`, 2026-08-20), pushed to `origin/development`. See `issues/28-implement-mission-detail-timeline-and-controls.md`.

## External dependency: the backend API contract

**CodexBridge #7 — Expose missions and mission-control API** is now merged
into the CodexBridge gateway's own `development` (commit `16ce28e`, part of
the `gh-5-6-7-8-contract-align` integration — confirmed directly with the
CodexBridge session, 2026-08-20). `MockMissionRepository` still stands in on
this side: #28 shipped against the mock deliberately (CodexBridge #7 was
still open when #28 was implemented), and no issue has picked up wiring a
real `HttpMissionRepository` yet.

The real contract diverges structurally from the mock, not just by field
name — worth reading before anyone opens that issue: the DTO
(`_mission_dto`, `gateway/app/api/routes/missions.py`) is `id, projectId,
assignedAgent, objective, mode, state, stage, risk, blocked,
blockedReason{code,summary}, priority, revision, createdAt, startedAt,
completedAt, expiresAt, approvalState, requestedBy, lastError` — no
`title`/`status`/`owner`/`progress`/`dependencies`/`tests`/`files`/
`artifacts`/`relatedDecisionIds`, `blockedReason` is an object not a plain
string, timeline is a separate paginated `GET /api/v1/missions/{id}/timeline`
rather than embedded, `state` is the raw `TaskState` value rather than the
mock's `active/paused/blocked/completed/cancelled` enum, and mission
control is **cancel-only** — no pause/resume at the mission-control level
(session-level pause/resume from issue #16 has no mission-control
equivalent). A real integration needs to read `state` directly for a
`paused` mission, not `stage` (which only groups pending/active/done).

| CodexBridge | What it fixes | Status | Binds |
|---|---|---|---|
| [#7](https://github.com/EDortta/CodexBridge/issues/7) | missions API (list, detail, timeline, cancel) | **merged to CodexBridge `development`, not yet wired from this app** | #27 (fake), #28 (fake) |
