# Project Rules

## Scope Anchor

The product scope for this repository is the one defined in `docs/product-foundation.md`.
When scope is ambiguous, treat that document as the canonical product framing before
assuming features or starting implementation.

## Workspace Scope and Cross-project References

- [MANDATORY] Codex Bridge Mobile is an independent project under
  `~/Sync/Projects/AI`; it has no technical, functional, or operational link to
  ZeeCred.
- [MANDATORY] All writes, modifications, creations, deletions, runtime commands,
  commits, and Git operations are restricted to
  `~/Sync/Projects/AI/CodexBridgeMobile`.
- [MANDATORY] Ideas from other projects may be consulted or adopted only after
  the agent identifies the intended project and receives the operator's explicit
  authorization. A reference is inspiration, never an imported contract.

## Product Boundary

- Codex Bridge Mobile is the mobile terminal for the Codex Bridge ecosystem.
- APK installation is a supported capability, not the product's core identity.
- The app exists to reduce human decision latency away from the desktop.

## In Scope

- approvals and operator authorizations
- operational follow-up and status visibility
- reviews, conversations, and actionable artifacts
- APK installation flows
- assisted reading of user-selected files

## Out of Scope

- a mobile IDE
- heavy code editing
- replacing the desktop development environment
- automations that require unrestricted device access

## Decision Rule

Before proposing or implementing a feature, ask whether it helps the operator decide,
follow, review, authorize, or collect context while away from the computer. If not,
default to keeping that capability on desktop.

## Technical Bias

- Prefer offline-capable and synchronizable flows.
- Prefer concise, actionable context over large raw payloads.
- Critical actions must keep an audit trail.
- Device permissions must stay granular and justified by the feature.
