# Phase 5 — Epics, Issues e planejamento

- work_id: WK-20260821-gh-29-build-epics-and-issues-browser
- date: 2026-08-21
- public epic: https://github.com/EDortta/CodexBridgeMobile/issues/6

First phase folder for Epic #6. Depends on Epics #1-#5 (all satisfied —
Epic #5/Phase 4 closed with #28 merged into `development` at `b0ac4a1`).
This is a **recovery delivery**: a prior session (2026-08-20, an ephemeral
cloud container) implemented #29 fully — 5 commits, 41 tests, `flutter
analyze` clean, 365/365 passing — but `git push` failed with 403/404 and
the precautionary `git bundle` sent to the operator could not be located
afterward on this filesystem or in the chat history. That work is treated
as unrecoverable and #29 was redone from scratch on a fresh branch off
`origin/development` (`b0ac4a1`), not restored.

An untracked `lib/features/planning/` directory (`Epic`, `Issue`,
`PlanningRepository`, `MockPlanningRepository` — no presentation layer, no
tests) was found in the main checkout, left over from the lost session.
Its domain shape was well-reasoned and consistent with this repo's
conventions, but its class name `Issue` collides with the naming rule
`lib/features/issues/domain/project_issue.dart` already documents ("Named
`ProjectIssue` rather than `Issue`... to avoid colliding with 'GitHub
issue'"), and it duplicated a feature — `lib/features/issues/` —that
already existed on `development`, wired into `_PriorityIssuesCard`
(#24's dashboard). Rather than adding a second, overlapping
epics/issues concept, #29 **extended the existing `lib/features/issues/`**:
`ProjectIssue` gained `status`/`assignee`/`epicId`/`summary`/
`blockedReason`/`labels`/`dependencies` (additive — the dashboard's own
`_IssueListTile`/`_IssueDialog`, which read only
`id`/`title`/`priority`/`projectId`, needed zero changes), a new `Epic`
domain class was added alongside it, and `IssueRepository` gained
`loadEpics`/`loadEpic`/`loadIssue`. The untracked `lib/features/planning/`
directory was left as-is in the main checkout (out of this worktree's
scope) and is not part of this delivery.

## Issues

- [#29 — Build Epics and Issues browser](https://github.com/EDortta/CodexBridgeMobile/issues/29) — size M, **merged and closed** (PR #51 browser UI, PR #59 HTTP repository). See `issues/29-build-epics-and-issues-browser.md`.
- [#30 — Issue creation, editing and planning review](https://github.com/EDortta/CodexBridgeMobile/issues/30) — size L, **finished, PR #60 open, pending operator review/merge**. Branch `feature/gh-30/issue-creation-editing-and-planning-review`.

## External dependency: the backend API contract

**CodexBridge #8 — Expose Epics and Issues API** is still open and
unimplemented (`gh issue view 8 -R EDortta/CodexBridge`, checked
2026-08-21). The lost session's own leftover code (`lib/features/planning/`
in the main checkout, not part of this delivery) claimed in a doc comment
that #8 was "merged... confirmed 2026-08-20" — that claim does not match
GitHub's current state and was not carried into this delivery.
`MockIssueRepository` stands in until #8 lands, the same "mocked
deliberately, backend ready but unwired" state #27/#28 left
`MockMissionRepository` in. #8's proposed scope names the same fields #29
needed: "Status, priority, labels, assignee, dependencies and blocked
reasons" and "Epic–Issue relationships" — `ProjectIssue`'s and `Epic`'s new
fields follow that shape directly.

| CodexBridge | What it fixes | Status | Binds |
|---|---|---|---|
| [#8](https://github.com/EDortta/CodexBridge/issues/8) | epics/issues API (list, detail, create/update) | **open, not implemented** | #29 (mocked) |
