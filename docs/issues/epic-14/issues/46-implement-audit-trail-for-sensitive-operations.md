# #46 — Implement audit trail for sensitive operations

- status: [first-slice-delivered]
- work_id: WK-20260826-gh-46-audit-trail-for-sensitive-operations
- public issue: https://github.com/EDortta/CodexBridgeMobile/issues/46
- parent epic: https://github.com/EDortta/CodexBridgeMobile/issues/14
- branch: `feature/gh-46/audit-trail-for-sensitive-operations`

## Objective (from the public issue)

Record actor, action, target, time, result and relevant context for
decisions, session controls, file access and installation flows.
Acceptance criteria: records are immutable from normal UI; failed and
cancelled operations are included; sensitive values are redacted.

## What this slice delivers

Read `docs/architecture/security-threat-model.md` R8/R9/R10 first — they
name what this trail must log (this issue's own "When to revisit" line).

- `lib/core/audit/` — cross-cutting, like `core/gateway/` and
  `core/storage/`, because the audited operations live in several features
  and a feature must never import another feature:
  - `AuditEvent` (actor, area, action, target, occurredAt UTC, result,
    failureReason, context — context defensively unmodifiable).
  - `AuditResult.success/failure/cancelled` — failed and cancelled included
    by type, not by convention.
  - `AuditArea` — decision, liveSession, mission today; `fileAccess` and
    `installation` declared now, unused, so #37/#38/#39 build against an
    existing category (threat model R8/R9).
  - `audit_redaction.dart` — pure policy: key-based (password/token/
    secret/…), value-shape (JWT, `Bearer …`), length cap. Applied at the
    store boundary, not trusted to call sites.
  - `AuditTrailRepository` — two methods, `record` + `loadEvents`. No
    update, no delete: immutability enforced by the interface's shape.
  - `InMemoryAuditTrailRepository` — the stand-in for a backend that does
    not exist (no CodexBridge audit API; CodexBridge #8 is open,
    unimplemented, and scoped to epics/issues anyway — checked 2026-08-26).
    Same role `MockAuthGateway` plays for auth.
  - `AuditRecorder` + providers; `auditActorProvider` resolved by
    `lib/app/audit_actor_binding.dart` from the signed-in session
    (`operatorId`, server-resolved), `unknown` otherwise.
- Wiring, every outcome (success / failure / operator backed out):
  - Decision approve / reject / requestRevision
    (`decision_detail_screen.dart`). Discuss is deliberately not audited —
    no state change, content already in the decision's own discussion.
  - Live session pause / resume / restart / stop
    (`live_session_providers.dart`), including the not-signed-in
    precondition failure and the confirmation back-out.
  - Mission pause / resume / cancel (`mission_detail_screen.dart`).
- Read-only viewer: `lib/features/audit/presentation/audit_trail_screen.dart`,
  reached from Account (`/account/audit`), no mutating affordance.
- Redaction posture: the trail stores flags (`commentProvided`,
  `reasonProvided`), never the justification text — the feature's own
  record keeps content; the trail keeps the act.

## Not in this slice (next slices, in order of value)

- Auth lifecycle events (sign-in attempts, sign-out, renewals) — sensitive,
  but touching `SessionController`'s carefully guarded race handling
  deserves its own focused change; the issue text names "session controls"
  (live sessions), which this slice covers.
- File access (#39) and installation (#37/#38) call sites — those flows do
  not exist yet; their `AuditArea` values do.
- Durable/server-side persistence — needs a backend audit API that does not
  exist. When it lands, decide explicitly whether operations must block on
  a refused audit write (`AuditRecorder.record`'s doc comment flags this).
  Stated plainly (council 2026-08-26, the adversarial user): an in-memory
  trail gives **no accountability against the operator themselves** — a
  restart erases it. That is acceptable only because this is the first
  slice and the server-side trail is the accountability story; the Account
  tile and the empty state both say "this app session", never "device".

## Checks

- `flutter analyze`: clean.
- `flutter test`: full suite green (see epic RESUME for numbers), including
  redaction, immutability, recorder, binding, screen and per-feature
  wiring tests.
