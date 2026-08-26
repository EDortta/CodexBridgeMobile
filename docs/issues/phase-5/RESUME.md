# Phase 5 Resume

- work_id: WK-20260822-gh-30-issue-creation-editing-and-planning-review
- date: 2026-08-26
- status: #29 **merged and closed** (PR #51 UI browser + PR #59 HTTP
  repository, both merged into `development`); #30 finished on
  `feature/gh-30/issue-creation-editing-and-planning-review`, committed
  (`2ee1007`), pushed, **PR #60 open against `development` — not merged,
  pending operator review**

## Current state

#29 (Epics and Issues browser) is done: PR #51 merged the browser UI and
PR #59 merged `HttpIssueRepository` (real HTTP epics/issues repository
against Codex Bridge). The issue is closed on GitHub.

#30 (Issue creation, editing and planning review) is implemented on
`feature/gh-30/issue-creation-editing-and-planning-review` (single commit
`2ee1007`), PR #60 open against `development`:

- Domain: `IssueRepository` gains `createEpic`/`createIssue`/
  `updateIssue`/`linkIssueToEpic`; `IssueFormValidation` (pure, explicit);
  `IssueHistoryEvent` + `ProjectIssue.history` (additive);
  `describeIssueChanges` as the one pure diff function the review step and
  the history entries both render from. `MockIssueRepository` implements
  the four write methods in-memory with revision-guarded optimistic
  concurrency (`StaleIssueRevisionException`) and history built from the
  diff on every real change. `HttpIssueRepository` parses an optional
  `history` array from the wire, falling back to empty — CodexBridge #8
  does not send one yet.
- Presentation: `IssueFormScreen` (Stepper: Details → Planning → Review)
  wired into `IssuesScreen` ("New issue") and `IssueDetailScreen` ("Edit")
  via the same query-param dispatch (`newIssue`/`editIssue`);
  `IssueDetailScreen` gains a History card; stale writes surface an
  explicit conflict dialog.

`flutter analyze`: clean. `flutter test`: 562/562 (up from 507), including
a real-router end-to-end suite (`test/app/issue_form_flow_test.dart`).

Not validated: server-persisted issue history (CodexBridge #8 still open —
mock-only until the wire grows a `history` field); real Android Keystore
path; on-device visual check.

## A false claim caught, not carried forward

The lost 2026-08-20 session's leftover code (`lib/features/planning/` in
the main checkout, untracked, **not** part of any delivery) documented
CodexBridge #8 ("Expose Epics and Issues API") as "merged... confirmed
2026-08-20". `gh issue view 8 -R EDortta/CodexBridge` shows it **open,
unimplemented** (last checked 2026-08-26). Do not let that claim re-enter
docs or code comments.

## `lib/features/planning/` — found, not used

Untracked in the main checkout: `Epic`, `Issue`, `PlanningRepository`,
`MockPlanningRepository` — domain-only, no presentation layer, no tests.
Its class `Issue` collides with the naming rule `project_issue.dart`
documents, and it duplicates `lib/features/issues/`. Left untouched —
**operator decision pending: delete or reconcile.**

## Next Step (DO THIS FIRST)

**Operator review of PR #60 is next, not more implementation.** #30 is
committed, pushed, PR open against `development`; standing instructions
require stopping before merge/deploy regardless of review outcome.
Separately, still pending operator decisions: the untracked
`lib/features/planning/` directory (delete or reconcile), and the
threat-model R1/R4/R6/R11 issue archiving question.
