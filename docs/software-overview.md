# Software Overview

## Metadata

- work_id: WK-20260803-governancekit-project-configuration
- date: 2026-08-03
- owner: Esteban
- project_context_ready: yes

## Product

Codex Bridge Mobile is the Android mobile terminal for the Codex Bridge ecosystem.
It gives an operator a concise, actionable way to decide, follow, review,
authorize, discuss, and collect context while away from a desktop. It does not
replace the desktop development environment and is not a mobile IDE.

## Users and Core Behavior

- Operators review operational decisions with context, impact, risks,
  recommendation, and evidence.
- Operators follow long-running work through Missions, including planning,
  implementation, tests, validation, and documentation.
- Operators use projects, work, conversations, and account as the four primary
  navigation areas.
- APK installation and assisted reading of user-selected files are supported
  capabilities, not the product's central identity.

## Technical and Runtime Boundary

- Target client: Android mobile application.
- Delivery target: an installable APK for an operator-controlled Android device.
- Product requirements: offline-capable and synchronizable data, relevant
  notifications, Android Keystore-backed local secrets, and OAuth-based account
  access.
- This repository owns the mobile client and its build artifacts. Codex Bridge
  backend services, their hosting, credentials, and deployment are external
  dependencies and are not operated from this repository.

## Product Constraints

- The decision-centered flow is `Missions + Decision Center`.
- Critical actions require an auditable trail.
- Device permissions must be granular and feature-justified.
- Keep heavyweight code editing, complex technical navigation, and unrestricted
  device access out of scope.

## Canonical Product Reference

`docs/product-foundation.md` is the canonical product framing. Any feature that
does not help the operator decide, follow, review, authorize, or collect context
away from the computer remains a desktop concern unless explicitly approved.
