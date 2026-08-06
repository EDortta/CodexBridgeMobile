# Phase 0 Resume

- work_id: WK-20260804-gh-1-introduce-app-layer
- date: 2026-08-04
- status: done

## Current state

- All five Phase 0 issues (#16, #20, #17, #19, #18) are implemented, validated,
  merged into `development`, pushed, and closed on GitHub.
- **Epic #1 is closed.** Its two open points were resolved today: `lib/app/` now
  exists, and the CI has executed on GitHub for the first time — green.
- PR #49 (`development` → `main`) was merged on operator instruction, and
  `development` fast-forwarded to it. Both branches are at `f3a834c`, with 0/0
  divergence. No deploy was performed; none is implied.

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

## Closed

PR #49 was merged: `main` and `development` are both at `f3a834c`. Phase 0 needs
nothing further. Active work continues in
[`docs/issues/phase-1/RESUME.md`](../phase-1/RESUME.md).

## Council round — 2026-08-06

- work_id: WK-20260806-phase-0-council
- Instrument: `.docs/agents/council.md`, default three members, one lens each:
  claim auditor, sweep skeptic, second caller. Run against approved, merged work.
- Trigger that applied: §4 `[MANDATORY]` — this RESUME's `Not validated:` on a
  runtime path — plus §4 `[DEFAULT]`, operator asked.
- **Contract deviation, recorded:** §5 `[MANDATORY]` requires reading the Target
  Project Checklist from `.docs/software-overview.md` and stopping if it is not
  ready. That path no longer resolves (see sweep F1); the checklist was read from
  `docs/software-overview.md` instead and the round proceeded. By the letter of
  §5 it should have stopped. The gate failed open.

**Counts:** findings raised 18 | survived §2 18 | became tests 0 | questions 13

Findings are recorded, not fixed: §1 forbids the council from modifying code, and
§2 requires each surviving finding to close with a failing test or a written risk
acceptance (`/AGENTS.md` §9). None has closed yet. Highest-severity first:

1. `.gitignore` lost `.env`, `.env.*`, `build/`, `.dart_tool/`, `.idea/`, `*.iml`,
   `.flutter-plugins*`, `android/.gradle/` — the project's own ignores had been
   placed inside the kit-managed block, which a rewrite replaced. 711 untracked
   paths; `.env` no longer ignored, against `docs/limits.md` Security Boundary.
2. `android/app/src/main/AndroidManifest.xml` declares no `INTERNET` permission;
   it exists only in the debug and profile manifests. CI builds `--debug` only,
   so the gap is invisible until a release build — which is Phase 1 (#21) work.
3. The CI gate never ran on any of the six local merges it exists to gate:
   `.github/workflows/flutter-ci.yml` triggers on `pull_request` and
   `workflow_dispatch`, while `epic.md` mandates local merges into `development`.
   Neither branch is protected (`branches/*/protection` → 404, rulesets `[]`).
4. Issue #16 claims a `jkx_dev` AVD launch that this RESUME and the Epic #1
   closing comment both deny. No artifact exists for either statement.
5. The `.docs/` → `docs/` relocation updated none of its 23 inbound references,
   exists only in the working tree with no commit, and hard-fails the installer's
   readiness gate (`scripts/install-agents-kit.sh:1980`).
6. Named mechanisms credited as test-covered are not: per-branch navigator keys
   (`go_router` supplies them by default), the design tokens (`AppSpacing`,
   `AppRadius`, `AppElevation`, `AppMotion`, `AppIcons` — zero test references),
   and the `features → core` boundary, which no lint or CI step enforces.

### Remediation — 2026-08-06, same day

Applied on operator instruction, after the round. Each item names how it was
verified; §2 wants a failing test or a written acceptance, not a claim.

1. **`.gitignore`** — project ignores restored *outside* the kit-managed block,
   plus `*.keystore`, `*.jks`, `key.properties`. Verified: `git check-ignore` now
   returns IGNORED for `.env`, `.env.*`, `build/`, `.dart_tool/`, `.idea/`,
   `*.iml`, `android/local.properties`; untracked count 711 → 2.
2. **`INTERNET`** — declared in `android/app/src/main/AndroidManifest.xml`, with
   `res/xml/network_security_config.xml` denying cleartext globally and naming
   the gateway host. Verified by building the variant that was never built:
   `flutter build apk --release` succeeded (48.3MB) and the merged manifest at
   `build/app/intermediates/merged_manifest/release/processReleaseMainManifest/`
   grants `android.permission.INTERNET` and carries `networkSecurityConfig`.
   CI now builds release too and asserts the permission on the merged manifest,
   so this class of gap fails in the gate rather than on a device.
3. **CI triggers** — `push:` on `main` and `development` added, matching the
   local-merge integration this epic mandates. **Branch protection was NOT
   enabled** — it changes how the operator may push and is his call; still open.
4. **#16's AVD claim** — withdrawn in the issue file and in `handoff.md`. Which
   of the two contradicting records was false is unrecoverable, so the record now
   carries the conservative reading: no evidence this app has ever started on
   Android. Treat first launch as unproven work.
5. **Docs location** — `docs/` is canonical and is the only copy. Symlinks in
   `.docs/` were tried first and then removed on operator instruction: the
   documentation moves, it does not get aliased. All operational references were
   repointed at `docs/` — including the kit-owned contract files (`AGENTS.md`,
   `CLAUDE.md`, `GEMINI.md`, `.cursorrules`, `.windsurfrules`,
   `.github/copilot-instructions.md`, `.amazonq/`, the generated block in
   `required-reading.md`, `.gk/project-config.json`, `.docs/agents/_shared.md`,
   `.docs/agents/council.md`, `.docs/workflows/*-audit.md`,
   `.docs/context-manifest.yaml`). Verified: an enumeration that does not rely on
   `.gitignore`-blind `grep -r` returns no operational reference to
   `.docs/(software-overview|limits).md`. Historical records — `handoff.md`,
   `docs/napkin-lessons.md`, `.gk/config-session.json`, `.gk/overwritten/` — were
   left untouched: rewriting a record of what happened falsifies it.
   `required-reading.md` now names phase-1 as the active epic.

   **Correction, same day.** This entry first recorded an accepted risk: that
   `install-agents-kit.sh` reads its readiness gate from `.docs/` (~line 1980),
   so `--upgrade` would exit 30 forever and the kit "is not fixable from this
   repository". That was wrong, and the operator caught it by asking whether the
   kit source was not simply a sibling directory. It is:
   `/home/esteban/Sync/Projects/AI/Agents` (`EDortta/AI-Agents`).

   **The upstream installer already reads `docs/`** — `SO_FILE`/`LIM_FILE` at
   source lines 2070-2071, against 1980-1981 in the copy vendored here, which is
   90 lines behind (2021 vs 2111). Upstream also ships
   `migrate_readiness_files_to_docs()` (source line 1847), whose only job is to
   move these two files out of `.docs/` — and which deletes a `.docs/` symlink on
   sight, commenting that the symlink "was the workaround for this very
   misfiling". The kit's layout is: kit files in `.docs/`, the two files the
   project fills in `docs/`.

   So the move made here is not a deviation the project must carry — it is the
   layout upstream already converged on, and the `exit 30` is a stale vendored
   copy, not a boundary. The remaining action is to upgrade the kit copy from the
   sibling source, not to accept anything. Nothing about this is a standing risk.

   The lesson is recorded in `docs/napkin-lessons.md`: "not fixable from here"
   was asserted about a repository that was one directory away and already had
   the fix.
6. **The three untested mechanisms** — `test/architecture/layer_boundaries_test`
   and `test/core/design/app_tokens_test` added; suite 12 → 17, `analyze` clean.
   Each new assertion was falsified before being trusted: a feature importing
   `app/`, a cross-feature import, a hardcoded `EdgeInsets`, and an off-catalogue
   icon each make the suite fail with the violation named, and the tree was
   restored after every probe. The navigator-key credit was corrected in
   `docs/architecture/navigation.md` and issue #18 — `go_router` supplies branch
   keys by default; ours carry only a `debugLabel`. `AppMotion` was deleted
   rather than tested, having no consumer.

**Still open after remediation:** branch protection (item 3); widget-state
preservation, untestable until a screen holds real state; a first run on device
or emulator; `dart format` drift in two files and the unpinned `ubuntu-latest`
runner, both raised by the round and not in the operator's fix list.

**Audited and clean:** the `lib/app/` extraction has no stragglers in any form
checked (bare token, `./`, `../`, markdown link, code fence, dotted, `package:`).
CI run 30903017809 is real and green over the shipped source. `flutter analyze`
clean, `flutter test` 12/12 at HEAD. The six extra lints in `analysis_options.yaml`
match #20's claim exactly.

## Loose end (not owned by any issue)

`mobile/codexbridgemobile-workspace.zip` is untracked and predates every Phase 0
issue; it was deliberately left alone. Decide whether to remove or track it.
