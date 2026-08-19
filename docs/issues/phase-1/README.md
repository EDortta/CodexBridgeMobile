# Phase 1 — Autenticação e conexão com Codex Bridge

- work_id: WK-20260804-phase-1-auth-and-connection
- date: 2026-08-04
- reconciled: 2026-08-19
- public epic: https://github.com/EDortta/CodexBridgeMobile/issues/2

This local mirror tracks the active public epic. Work proceeds in the public
issue order, one feature branch and one validated commit at a time.

## Issues

- [#21 — Implement Codex Bridge server configuration and connection test](https://github.com/EDortta/CodexBridgeMobile/issues/21) — size M, **finished**. Real `HttpServerProbe` (`lib/features/server/data/http_server_probe.dart`) against the now-deployed `GET /health`, `GET /ready`, `GET /api/version` (CodexBridge #2/#3, deployed 2026-08-10). Commit `8f5804b`, merged `4f4545e`.
- [#22 — Implement authentication and session lifecycle](https://github.com/EDortta/CodexBridgeMobile/issues/22) — size L, **finished**, backed by a fake. `lib/features/auth/data/mock_auth_gateway.dart` is a deliberate fake — CodexBridge #4 (auth/authorization/mobile session) is still open, so there is no real contract to call yet. Commits `65b1799`/`ea6146e`, merged `f4a9cd9`.

Epic #2 (this phase) is now fully closed. Both branches were committed
directly to `development` without an intermediate PR or an issue mirror file
under `docs/issues/phase-1/issues/` — that step was skipped in the moment and
is being corrected now (2026-08-19 reconciliation) rather than retroactively
faked.

## Out-of-order work already done: Epic #7 (Sessions, agents and logs)

Epic #7 was not part of this phase's plan, but its two issues shipped ahead
of schedule, directly on `development`:

- [#31 — Build agent sessions list and status model](https://github.com/EDortta/CodexBridgeMobile/issues/31) — finished as part of `d149a2d`.
- [#32 — Implement session detail, logs and remote controls](https://github.com/EDortta/CodexBridgeMobile/issues/32) — finished, `d149a2d`, merged `e8d26ba`. Council-reviewed (2 rounds, 13 findings closed, 3 questions left open — see commit body for the machine record path under `.gk/council/`).

Both closed on GitHub 2026-08-19 referencing these commits, after pushing the
6 commits that were sitting only in the local `development` (never pushed to
`origin` until this reconciliation).

## External dependency: the backend API contract

The Codex Bridge backend is an external dependency and is not operated from this
repository (`docs/software-overview.md`). Its API is being specified in
**`EDortta/CodexBridge`**, epic
[#1 — Expose contract-first API for CodexBridgeMobile](https://github.com/EDortta/CodexBridge/issues/1).

| CodexBridge | What it fixes | Status | Binds |
|---|---|---|---|
| [#2](https://github.com/EDortta/CodexBridge/issues/2) | canonical OpenAPI, `/api/v1` namespace, shared schemas | **closed, deployed to production 2026-08-10** | field-level shapes |
| [#3](https://github.com/EDortta/CodexBridge/issues/3) | `GET /health`, `GET /ready`, `GET /api/version` | **closed, deployed to production 2026-08-10** | #21 (now real) |
| [#12](https://github.com/EDortta/CodexBridge/issues/12) | standardized errors, pagination, idempotency, concurrency | **closed, deployed to production 2026-08-10** | all future clients |
| [#4](https://github.com/EDortta/CodexBridge/issues/4) | authentication, authorization, mobile session | **open, not implemented** | #22 (still a fake, `mock_auth_gateway.dart`) |

CodexBridge #1's completion criterion states that the mobile client "can replace
its fake API implementation with a generated or handwritten HTTP client
validated against the canonical contract." #21 already did this for the
health/version surface. #22 is the next one to convert once CodexBridge #4
lands — this repository cannot implement that side; only consume it once it
exists.
