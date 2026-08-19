# Phase 1 Resume

- work_id: WK-20260804-phase-1-auth-and-connection
- date: 2026-08-04
- reconciled: 2026-08-19
- status: **done** (both issues finished; epic #2 closed)

## Current state (2026-08-19 reconciliation)

Phase 1 (Epic #2: #21, #22) is finished, and Epic #7 (#31, #32 — sessions
list, detail, logs, remote controls) shipped alongside it, out of the
originally planned order. See `README.md` for the full breakdown.

What actually happened, reconstructed from `git log` since this file was
last accurate (it still said "not_started" and blocked #21 on an unanswered
decision that had, in fact, already been answered and implemented):

- `feature/gh-21/...` and `feature/gh-22/...` were implemented and merged to
  `development` on 2026-08-14.
- `feature/gh-32/...` (which also closed #31's gap) was implemented and
  merged to `development` on 2026-08-18.
- None of the 6 resulting commits were pushed to `origin` until this
  reconciliation (2026-08-19) — `development` was 6 commits ahead of
  `origin/development` with nothing to indicate why.
- The 4 GitHub issues (#21, #22, #31, #32) stayed open on GitHub despite the
  code being done, because closing them was never done.
- This file and `README.md` were never updated past the point where #21 was
  still blocked on an operator decision — the decision was made and acted on,
  but the record of it stopped here.

## Decision that was actually taken (resolves the old "open decision" below)

The old blocking decision on **how to implement the connection probe** was
resolved as **option 1**: real paths + tolerant parsing + a fake still only
for auth. `lib/features/server/data/http_server_probe.dart` calls the real
`GET /health` / `GET /api/version` (now deployed, CodexBridge #2/#3), reading
only `status` and `apiVersion` as required fields and treating everything
else as optional/ignorable — exactly as scoped. `lib/features/auth/data/mock_auth_gateway.dart`
stays a deliberate fake because CodexBridge #4 (auth) is still unimplemented
upstream; that dependency has not moved.

## Session-close discipline gap (napkin lesson candidate)

Three real feature commits landed across two sessions without: closing their
GitHub issues, pushing to `origin`, updating this file, or adding a
`handoff.md` entry. `docs/napkin-lessons.md` should get an entry recommending
that `.docs/workflows/session-close.md` be run at the end of every session
that lands a commit, not only at the end of a phase — see that file for the
actual lesson text.

## Next Step

Phase 1 and the out-of-order Epic #7 work are done. The next unstarted issue
in mobile epic order is **#23 — Build projects list, search and filters**
(parent Epic #3, size M). `lib/features/projects/presentation/projects_screen.dart`
today is only the 38-line placeholder created by the Phase 0 navigation shell
(`d0cdda2`) — it has no search, favorites, or the attention/offline states
#23 requires.
