# Phase 3 — Centro de Decisões

- work_id: WK-20260819-gh-25-decision-inbox-and-filters
- date: 2026-08-19
- public epic: https://github.com/EDortta/CodexBridgeMobile/issues/4

First phase folder for Epic #4. Depends on Epics #1, #2 and #3 (all
satisfied). Note: an earlier `docs/issues/phase-2/RESUME.md` entry
mislabeled #25/#26 as "Epic #3's remaining issues" — they belong to Epic #4;
corrected here and there.

## Issues

- [#25 — Build decision inbox and filters](https://github.com/EDortta/CodexBridgeMobile/issues/25) — size M, **finished**. See `issues/25-build-decision-inbox-and-filters.md`.
- [#26 — Implement decision detail and resolution flows](https://github.com/EDortta/CodexBridgeMobile/issues/26) — size L, not started.

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
| [#6](https://github.com/EDortta/CodexBridge/issues/6) | operational decisions API (list, detail, approve/reject/request-revision) | **open, not implemented** | #25 (fake), #26 |
