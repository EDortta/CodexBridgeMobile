# #29 — Build Epics and Issues browser

- status: [finished, pending operator review/merge]
- work_id: WK-20260821-gh-29-build-epics-and-issues-browser
- public issue: https://github.com/EDortta/CodexBridgeMobile/issues/29
- parent epic: https://github.com/EDortta/CodexBridgeMobile/issues/6
- branch: `feature/gh-29/build-epics-and-issues-browser`

## Context — recovery delivery

A prior session (2026-08-20, an ephemeral cloud container) implemented #29:
5 commits, 41 new tests, `flutter analyze` clean, 365/365 passing — but
`git push` failed with 403/404. As a precaution it bundled the branch with
`git bundle` and sent the file to the operator directly, but the operator
could not locate it the next day and this filesystem (Downloads, `/tmp`,
scratchpad, the whole repo tree) turned up nothing. Treated as
unrecoverable; redone from scratch on a fresh
`feature/gh-29/build-epics-and-issues-browser` off `origin/development`
(`b0ac4a1`), not restored from any artifact of the lost session.

An untracked `lib/features/planning/` directory was found in the main
checkout during recovery — `Epic`, `Issue`, `PlanningRepository`,
`MockPlanningRepository`, domain-only, no tests, no presentation layer.
Judged not directly usable: its class `Issue` collides with the naming
rule `lib/features/issues/domain/project_issue.dart` already documents,
and it duplicates a feature that already existed on `development` — see
`docs/issues/phase-5/README.md` for the full reasoning. Left untouched in
the main checkout, out of this worktree's scope.

## Objective (from the public issue)

Create project-scoped lists with status, priority, labels, dependencies,
assignee and blocked indicators. Acceptance criteria: Epic and Issue views
are distinct; filters identify blocked and priority work; selecting an item
opens full context. Size: M.

## Scope

- `IssueStatus` domain enum (`todo`/`inProgress`/`blocked`/`done`), shared
  by `Epic` and `ProjectIssue` the same way `MissionStage` is shared by
  every mission.
- `ProjectIssue` (pre-existing, `features/issues/`) gains `status`,
  `assignee`, `epicId`, `summary`, `blockedReason`, `labels`,
  `dependencies`, `createdAt`, and an `isBlocked` getter — additive; the
  four fields `project_dashboard_screen.dart`'s "Priority issues" section
  already read (`id`/`title`/`priority`/`projectId`) are untouched.
- New `Epic` domain class: `id`, `projectId`, `title`, `status`,
  `priority` (reuses `IssuePriority`), `createdAt`, `summary`,
  `blockedReason`, `issueIds` (plain string ids, not object references,
  the same shape `Mission.relatedDecisionIds` uses).
- `IssueRepository` gains `loadEpics`, `loadEpic`, `loadIssue` (plus
  `EpicNotFoundException`/`IssueNotFoundException`); `MockIssueRepository`
  rewritten as map-backed storage with 3 epics and 7 issues across 3
  projects, `codex-bridge-cli` deliberately left empty.
- `filterEpics`/`filterIssues` (pure, `issue_filter.dart`): project scope
  plus independently-selectable status/priority, AND-combined.
- `EpicsScreen`/`IssuesScreen`: project-scoped lists, filter row
  (`FilterMenuButton`), blocked items visually distinct (never color
  alone — an explicit "Blocked" label always accompanies the red border,
  same rule `_MissionCard`/`_DecisionCard` already follow), an app-bar
  action toggling to the sibling view for the same project.
- `EpicDetailScreen`/`IssueDetailScreen`: full context (summary, badges,
  blocked reason in text), epic↔issue cross-links resolved to titles.
- Routing: `?epics=<id>`/`?issues=<id>`/`?epic=<id>`/`?issue=<id>` under
  the `projects` destination's detail route, the same query-param dispatch
  `mission`/`session` already use under `work`
  (`lib/app/destination_detail_screen.dart`).
- Dashboard entry point: `_PriorityIssuesCard`'s header now carries
  `?issues=<projectId>` (`onHeaderTap`), the same "carry the id, not just
  the destination" pattern `_CurrentMissionCard` (#28) uses. The existing
  per-row dialog is untouched.
- `AppIcons.epics`, `AppIcons.blocked` added.

Out of scope: creating/editing issues (#30, per the lost session's own mock
data narrative — not independently verified against GitHub this session),
and wiring a real `HttpIssueRepository` (blocked on CodexBridge #8, open
and unimplemented as of 2026-08-21).

## ARO (Allowed / Prohibited / Out of scope) — carried from `docs/limits.md`

Implemented within "explicitly requested mobile-client issue, including
focused tests" (Allowed). No backend, auth, persistence-contract or device-
permission change. No merge, push-to-`main`, or deploy performed or
attempted.

## Test plan

65 new tests: `IssueStatus` label test; `ProjectIssue`/`Epic` construction,
defaults and `isBlocked`; `mock_issue_repository_test.dart` (unique ids,
the four pre-#29 issues' id/title/priority/projectId pinned unchanged,
`codex-bridge-cli` still issue/epic-free, every epic's `issueIds` resolves
to a real issue, at least one blocked epic/issue each carry a reason);
`issue_filter_test.dart` (project scope, status, priority, AND-combination,
for both `filterEpics` and `filterIssues`); `issue_providers_test.dart`
(provider wiring, not-found propagation, filter provider defaults);
`epics_screen_test.dart`/`issues_screen_test.dart` (project scope, blocked
label, filters, empty states, clear); `epic_detail_screen_test.dart`/
`issue_detail_screen_test.dart` (full context, blocked reason in text,
cross-links, not-found vs. generic error branches); `app_router_test.dart`
(reaching each screen, card taps carrying the right id, the epics↔issues
toggle); one added test in `project_dashboard_screen_test.dart` (header tap
reaches the project-scoped browser).

Run: `flutter analyze` (clean) and `flutter test` (389/389, 0 regressions
on the 324 that existed after #28 merged).

Not validated: real Android Keystore path, on-device visual check (same
pre-existing gap #23-#28 carry), no multi-round council pass (out of this
recovery task's explicit 9-step process, which did not call for one).
