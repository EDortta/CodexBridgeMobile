# #16 — Initialize Flutter project and Android targets

- work_id: WK-20260803-gh-16-initialize-flutter-project
- date: 2026-08-03
- public issue: https://github.com/EDortta/CodexBridgeMobile/issues/16
- status: ready

## Context and objective

Create the initial null-safe Flutter application, define Android identifiers,
and prove a debug build runs on a local emulator.

## Scope

- Install the official stable Flutter SDK in `/opt/flutter`.
- Create the Flutter project at the repository root.
- Set Android application ID to `com.edortta.codexbridge.mobile`.
- Record exact Flutter and Dart versions in `README.md`.
- Add one widget smoke test and validate debug build and emulator launch.

## Out of scope

- Material 3 design work, Riverpod, routing, authentication, and product
  features.
- Extracting, importing, deleting, or versioning
  `mobile/codexbridgemobile-workspace.zip`; it is an HTML page, not a ZIP.

## ARO

- Acceptance: null safety, defined Android identifiers, documented SDK versions,
  passing local analysis/tests, debug APK built and launched in an AVD.
- Risk: host-level Flutter/AVD installation must not introduce credentials,
  untracked generated artifacts, or Android permissions beyond the default app.
- Operations: keep `/opt/flutter` outside Git; no deploy, APK distribution, or
  remote push.

## Test plan and definition of done

- `flutter doctor -v`, `flutter analyze`, `flutter test`, and
  `flutter build apk --debug` pass.
- The debug application launches in the configured local AVD.
- Diff review finds no scope expansion, secret, unnecessary permission, or
  incorrect application ID.
- Feature commit is merged locally into `development` only after all checks pass.
