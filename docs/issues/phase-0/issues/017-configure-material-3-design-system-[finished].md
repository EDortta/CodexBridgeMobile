# #17 — Configure Material 3 design system

- work_id: WK-20260803-gh-17-material-3-design-system
- date: 2026-08-03
- public issue: https://github.com/EDortta/CodexBridgeMobile/issues/17
- status: finished

## Context and objective

Centralize the first Material 3 visual contract so upcoming screens retain a
consistent operational interface in either system theme.

## Scope

- Define light and dark Material 3 themes.
- Define reusable spacing, radius, elevation, icon, and motion tokens.
- Define explicit styles for metadata, code, and logs alongside the Material UI
  text theme.
- Make the bootstrap screen consume only those centralized values.

## Out of scope

- Navigation, feature-state conventions, remote data, persistence, and
  authentication.
- Custom fonts, brand assets, or Android permissions.

## ARO and test plan

- Acceptance: both themes and all requested token categories exist; the
  bootstrap screen uses them without local visual constants.
- Restated 2026-08-06: the bootstrap screen was deleted by #18, so this criterion
  named a non-existent artifact and could no longer be checked. It now reads:
  **no screen under `lib/features/` or `lib/app/` hardcodes a visual constant the
  tokens already name**, enforced by `test/core/design/app_tokens_test.dart`.
- Risk: a nullable theme extension would make semantic typography unreliable.
  The app theme installs the extension for both brightnesses and the screen
  requires it at its consumption point.
- Operations: validate analysis, widget/theme tests, and the Android debug APK.

## Definition of done

- Focused tests prove the Material 3 light/dark themes and semantic typography.
- The Flutter analyzer and Android debug build pass.
- Diff review confirms no unrelated feature, permission, or secret is added.

## Result

- Feature commit: `f967f09`.
- `flutter analyze`, `flutter test`, and Android `assembleDebug` pass locally.
- Android build emits pre-existing Gradle/Kotlin deprecation warnings; no build
  configuration is changed by this issue.
- Corrected 2026-08-06: this issue's GitHub closing comment said the tokens were
  "Coberto por teste". They were not — no test referenced `AppSpacing`,
  `AppRadius`, `AppElevation`, `AppMotion` or `AppIcons`; the one theme test
  covered `OperationalTextTheme` only. `test/core/design/app_tokens_test.dart`
  now covers them, verified by falsification (a hardcoded `EdgeInsets` and an
  off-catalogue icon each make it fail). `AppMotion` was removed instead: nothing
  consumed it, so any test of it would assert a literal against itself.
