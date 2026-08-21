# Phase 5 Resume

- work_id: WK-20260821-gh-29-build-epics-and-issues-browser
- date: 2026-08-21
- status: #29 finished on `feature/gh-29/build-epics-and-issues-browser`,
  committed, pushed, PR open against `development` — **not merged, pending
  operator review**

## Current state

Recovery delivery: yesterday's session implemented #29 but its `git push`
failed (403/404) and the precautionary bundle it sent the operator could
not be located afterward. Redone from scratch off `origin/development`
(`b0ac4a1`), not restored.

`lib/features/issues/` (pre-existing, previously only a "Priority issues"
widget for #24's dashboard: `ProjectIssue{id, projectId, title, priority}`,
no screen of its own) is now #29's full browser. `ProjectIssue` gained
`status`, `assignee`, `epicId`, `summary`, `blockedReason`, `labels`,
`dependencies` — additive, so `_PriorityIssuesCard`/`_IssueDialog`
(`project_dashboard_screen.dart`), which read only
`id`/`title`/`priority`/`projectId`, needed zero changes. New `Epic` domain
class alongside it. `IssueRepository` gained `loadEpics`/`loadEpic`/
`loadIssue`; `MockIssueRepository` keeps its original four issues'
id/title/priority/projectId exactly (pinned by
`mock_issue_repository_test.dart` and the pre-existing dashboard tests) and
adds three epics, three more issues, and richer fields on the original four.

Two new screens, `EpicsScreen`/`IssuesScreen` (`?epics=<id>`/
`?issues=<id>` under the `projects` destination, matching `mission`/
`session`'s query-param dispatch under `work`), each project-scoped with
independent status/priority filters (`filterEpics`/`filterIssues`, pure)
and an app-bar toggle to the other view — #29 calls the two views
"distinct". Selecting a card opens `EpicDetailScreen`/`IssueDetailScreen`
(`?epic=<id>`/`?issue=<id>`), which resolve and link epic↔issue
relationships. Dashboard's "Priority issues" header now carries
`?issues=<projectId>` into the full browser (`onHeaderTap`, same pattern
`_CurrentMissionCard` (#28) already uses).

`flutter analyze`: clean. `flutter test`: 389/389 (65 new, 0 regressions —
confirmed the four pre-existing dashboard-visible issues and
`codex-bridge-cli`'s empty state still pass unchanged).

Not validated: same as #23-#28 (real Android Keystore path, on-device
visual check, no multi-round council — out of this recovery task's
explicit 9-step process).

## A false claim caught, not carried forward

The lost session's leftover code (`lib/features/planning/` in the main
checkout, untracked, **not** part of this delivery) documented CodexBridge
#8 ("Expose Epics and Issues API") as "merged... confirmed 2026-08-20".
`gh issue view 8 -R EDortta/CodexBridge` (run fresh this session) shows it
**open, unimplemented**. This session's own task briefing repeated the same
claim secondhand; verified and corrected before writing it into `README.md`
or code comments. #8's proposed scope (status, priority, labels, assignee,
dependencies, blocked reasons, epic–issue relationships) still matches
#29's shape directly, same as #27 shaped `Mission` off CodexBridge #7.

## `lib/features/planning/` — found, not used

Untracked in the main checkout: `Epic`, `Issue`, `PlanningRepository`,
`MockPlanningRepository` — domain-only, no presentation layer, no tests.
Well-reasoned and consistent with this repo's own conventions
(`blockedReason`, plain-string foreign ids), but its class `Issue` collides
with the naming rule `project_issue.dart` documents, and it duplicates the
pre-existing `lib/features/issues/`. Left untouched, out of this worktree's
scope (`docs/project-rules.md`'s workspace-scope rule) — flagged for the
operator to delete or reconcile.

## Next Step (DO THIS FIRST)

**Operator review is next, not more implementation.** #29 is committed,
pushed, and its PR is open against `development`; this session's standing
instructions require stopping before merge/deploy regardless of review
outcome. Review the diff and, if acceptable, merge the same way #21-#28
were closed. Separately: decide what to do with the untracked
`lib/features/planning/` directory in the main checkout (delete, or hand to
a future issue) — it was not touched by this delivery.
