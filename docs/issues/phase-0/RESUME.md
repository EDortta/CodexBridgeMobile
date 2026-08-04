# Phase 0 Resume

- work_id: WK-20260804-gh-1-introduce-app-layer
- date: 2026-08-04
- status: done

## Current state

- All five Phase 0 issues (#16, #20, #17, #19, #18) are implemented, validated,
  merged into `development`, pushed, and closed on GitHub.
- **Epic #1 is closed.** Its two open points were resolved today: `lib/app/` now
  exists, and the CI has executed on GitHub for the first time — green.
- `origin/development` is at `dd16f52`. `main` stays at `f33db38`.
- **PR #49 (`development` → `main`) is open and unmerged.** It is what triggered
  the CI run; merging it is an operator decision (AGENTS.md §7). Merging does
  not imply deploy.

## Changed files (this session)

- `lib/app/` — new: `app.dart` (root widget, extracted from `main.dart`),
  `app_router.dart`, `app_shell.dart`, `destination_detail_screen.dart`, the
  last three moved from `lib/core/navigation/`.
- `lib/main.dart` — reduced to `runApp` only.
- `test/app/app_router_test.dart` — moved from `test/core/navigation/`.
- `test/widget_test.dart` — imports updated.
- `docs/architecture/state-architecture.md` — new "Top-level layers" section.
- `docs/architecture/navigation.md` — paths and composition root updated.

`AppRoutes` and `AppDestination` stayed in `lib/core/navigation/`: four feature
screens import them, so moving them would invert the feature → app boundary.

## Checks

- Local on `development` at `dd16f52`: `flutter analyze` clean,
  `flutter test` 12/12, `flutter build apk --debug` OK.
- CI run 30903017809 (first ever on this repo): `verify` green in 4m41s —
  Analyze, Test, Build Android debug APK.
- Not validated: OS-level deep linking, unknown-path handling, any run on a
  physical device or emulator.

## Next Step (DO THIS FIRST)

Ask the operator whether to merge PR #49 into `main` (consolidating Phase 0), or
to leave `main` at `f33db38` and start Epic #2 — Autenticação e conexão com
Codex Bridge — from `development`.

## Loose end (not owned by any issue)

`mobile/codexbridgemobile-workspace.zip` is untracked and predates every Phase 0
issue; it was deliberately left alone. Decide whether to remove or track it.
