# Phase 0 Resume

- work_id: WK-20260803-gh-18-configure-primary-navigation
- date: 2026-08-03
- status: done_pending_epic_closure

## Current state

- All five Phase 0 issues (#16, #20, #17, #19, #18) are implemented, validated,
  merged into `development`, pushed to `origin`, and closed on GitHub.
- `origin/development` is at `30def3a`. `main` stays at `f33db38` by operator
  decision: consolidation into `main` waits for more cycles (AGENTS.md §7).
- Public Epic #1 is still open. Two of its items are not satisfied yet, so it
  was deliberately not closed.

## Epic #1 open points

1. Its scope asks for an `app/`, `core/`, and `features/` structure. `lib/core/`
   and `lib/features/` exist; there is no `lib/app/`. Either create it or record
   that the shell in `lib/core/navigation/` replaces it.
2. Its acceptance asks that `flutter analyze` and `flutter test` pass **in CI**.
   The workflow only triggers on `pull_request` and `workflow_dispatch`, and the
   epic was integrated through local merges without a PR, so the CI has never
   executed on GitHub. All three steps pass locally.

   Fixing this is a decision about the workflow itself: add a `push` trigger for
   `development`, or start opening PRs, or run it once via `workflow_dispatch`.

## Next Step (DO THIS FIRST)

Decide how Epic #1's CI acceptance criterion gets met — CI has never run on
GitHub. Then settle the `app/` directory question and close Epic #1.

## Loose end (not owned by any issue)

`mobile/codexbridgemobile-workspace.zip` is an untracked leftover from before
this epic. It predates every Phase 0 issue and was deliberately left alone;
decide whether it should be removed or tracked.
