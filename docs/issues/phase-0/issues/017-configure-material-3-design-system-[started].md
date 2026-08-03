# #17 — Configure Material 3 design system

- work_id: WK-20260803-gh-17-material-3-design-system
- date: 2026-08-03
- public issue: https://github.com/EDortta/CodexBridgeMobile/issues/17
- status: started

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
- Risk: a nullable theme extension would make semantic typography unreliable.
  The app theme installs the extension for both brightnesses and the screen
  requires it at its consumption point.
- Operations: validate analysis, widget/theme tests, and the Android debug APK.

## Definition of done

- Focused tests prove the Material 3 light/dark themes and semantic typography.
- The Flutter analyzer and Android debug build pass.
- Diff review confirms no unrelated feature, permission, or secret is added.
