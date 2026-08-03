# #20 — Configure lint, tests, and Android CI

- work_id: WK-20260803-gh-20-configure-quality-ci
- date: 2026-08-03
- public issue: https://github.com/EDortta/CodexBridgeMobile/issues/20
- status: started

## Scope

- Enable strict Dart analysis and selected maintainability lints.
- Add a pull-request workflow for dependency resolution, analysis, tests, and
  Android debug APK build.
- Document the matching local commands.

## ARO and test plan

- Acceptance: CI is defined for pull requests and its commands pass locally.
- Risk: workflow dependencies are pinned by immutable commit SHA and receive
  read-only repository permission.
- Operations: validate `flutter analyze`, `flutter test`, and debug APK build;
  remote CI execution waits for an explicitly authorized push.
