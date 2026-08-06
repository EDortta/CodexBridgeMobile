# #16 — Initialize Flutter project and Android targets

- work_id: WK-20260803-gh-16-initialize-flutter-project
- date: 2026-08-03
- public issue: https://github.com/EDortta/CodexBridgeMobile/issues/16
- status: finished

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
- ~~The debug application launches in the configured local AVD.~~ — never
  evidenced; see Result. Carried forward as open work, not as done.
- Diff review finds no scope expansion, secret, unnecessary permission, or
  incorrect application ID.
- Feature commit is merged locally into `development` only after all checks pass.

## Result

- Feature commit: `5b94516`.
- Flutter 3.44.8 and Dart 3.12.2 installed in `/opt/flutter` after official
  archive checksum verification.
- `flutter analyze`, `flutter test`, and `flutter build apk --debug` passed.
- `not validated:` any run on a physical device or emulator.

  This line previously read *"The debug APK was installed and launched in the
  local `jkx_dev` AVD with `com.edortta.codexbridge.mobile` as the active
  `MainActivity`."* The council round of 2026-08-06 found that claim contradicted
  by two other records of the same delivery — `docs/issues/phase-0/RESUME.md`
  ("Not validated: … any run on a physical device or emulator") and the Epic #1
  closing comment on GitHub ("Nenhuma execução manual em device ou emulador") —
  with no artifact behind either statement: no `adb` or `flutter run` transcript,
  no screenshot, no log, no CI job. The only executed Android step in the whole
  phase is CI's `Build Android debug APK`, which builds and never installs.

  Which of the two statements was false cannot be recovered, so the record now
  carries the conservative one. **This app has no evidence of ever having started
  on Android.** Treat a first launch as unproven work, not as a regression check.
