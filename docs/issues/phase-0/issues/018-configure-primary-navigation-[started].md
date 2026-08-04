# #18 — Implement application shell and primary navigation

- work_id: WK-20260803-gh-18-configure-primary-navigation
- date: 2026-08-03
- public issue: https://github.com/EDortta/CodexBridgeMobile/issues/18
- status: started

## Scope

- Add GoRouter and an application shell that hosts the four primary
  destinations: Projects, Work, Conversations, and Account.
- Preserve each destination's navigation state across tab switches.
- Resolve deep-link paths to the correct destination with the shell intact.
- Expose a Decisions entry point reachable from every primary destination.
- Document the navigation and routing conventions.

## Out of scope

- The real content of each destination; each one lands as a placeholder screen
  consuming its own feature state.
- Registering external URL schemes or Android App Links in the manifest, which
  needs domain verification and its own issue.
- Remote services, persistence, authentication, and new Android permissions.

## ARO and test plan

- Acceptance: the four destinations are reachable from the shell; leaving a
  destination and returning preserves its state; a deep-link path resolves to
  the matching destination; the Decisions entry point is reachable from all
  four.
- Risk: a shell that rebuilds its subtree on every tab change silently loses
  state, and the failure looks like normal navigation. Per-branch navigator
  keys prevent it, and a widget test asserts state survives a round trip.
- Operations: run dependency resolution, analysis, widget tests, and the
  Android debug build.

## Assumptions

- "Supports deep links" is read as router-level path resolution, the narrowest
  interpretation that satisfies the acceptance criterion without OS-level
  registration. Manifest intent filters remain a separate, explicitly gated
  change.
