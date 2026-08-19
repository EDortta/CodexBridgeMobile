# Phase 3 — Centro de Decisões

- work_id: WK-20260819-gh-26-decision-detail-and-resolution-flows
- date: 2026-08-19
- public epic: https://github.com/EDortta/CodexBridgeMobile/issues/4

First phase folder for Epic #4. Depends on Epics #1, #2 and #3 (all
satisfied). Note: an earlier `docs/issues/phase-2/RESUME.md` entry
mislabeled #25/#26 as "Epic #3's remaining issues" — they belong to Epic #4;
corrected here and there.

## Issues

- [#25 — Build decision inbox and filters](https://github.com/EDortta/CodexBridgeMobile/issues/25) — size M, **finished and closed**. Commit `6d65c1b`, merged `dda3992`. See `issues/25-build-decision-inbox-and-filters.md`.
- [#26 — Implement decision detail and resolution flows](https://github.com/EDortta/CodexBridgeMobile/issues/26) — size L, **finished**. See `issues/26-decision-detail-and-resolution-flows.md`.

## External dependency: the backend API contract

**CodexBridge #6 — Expose operational decisions API** is still open and
unimplemented. `MockDecisionRepository` stands in until then. Its proposed
scope already names the fields #25 needed: "Filters for project, state,
urgency, risk and deadline" and "Request, rationale, impact, risk, evidence
and recommendation fields" — `Decision`'s new fields (`urgency`, `risk`,
`state`, `deadline`, `impactSummary`, `recommendationSummary`) follow that
shape directly rather than guessing independently.

| CodexBridge | What it fixes | Status | Binds |
|---|---|---|---|
| [#6](https://github.com/EDortta/CodexBridge/issues/6) | operational decisions API (list, detail, approve/reject/request-revision) | **open, not implemented** | #25 (fake), #26 (fake) |

## Deliberately not built here: #46's audit trail

#26's "all outcomes create an audit event" is satisfied by
`DecisionAuditEvent`, scoped to this feature's own resolution actions. The
cross-cutting, immutable audit *store* — session controls, file access,
installation flows, redaction, tamper-resistance — is
[#46 — Implement audit trail for sensitive operations](https://github.com/EDortta/CodexBridgeMobile/issues/46)
(Epic #14, size L, not started). Building that here would have been doing
#46's job under #26's name.
