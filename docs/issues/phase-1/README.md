# Phase 1 — Autenticação e conexão com Codex Bridge

- work_id: WK-20260804-phase-1-auth-and-connection
- date: 2026-08-04
- public epic: https://github.com/EDortta/CodexBridgeMobile/issues/2

This local mirror tracks the active public epic. Work proceeds in the public
issue order, one feature branch and one validated commit at a time.

## Issues

- [#21 — Implement Codex Bridge server configuration and connection test](https://github.com/EDortta/CodexBridgeMobile/issues/21) — size M, not started
- [#22 — Implement authentication and session lifecycle](https://github.com/EDortta/CodexBridgeMobile/issues/22) — size L, not started

## External dependency: the backend API contract

The Codex Bridge backend is an external dependency and is not operated from this
repository (`.docs/software-overview.md`). Its API is being specified in
**`EDortta/CodexBridge`**, epic
[#1 — Expose contract-first API for CodexBridgeMobile](https://github.com/EDortta/CodexBridge/issues/1),
created 2026-08-04. None of it is implemented yet.

The issues that bind this phase:

| CodexBridge | What it fixes | Binds |
|---|---|---|
| [#2](https://github.com/EDortta/CodexBridge/issues/2) | canonical OpenAPI, `/api/v1` namespace, shared schemas | field-level shapes |
| [#3](https://github.com/EDortta/CodexBridge/issues/3) | `GET /health`, `GET /ready`, `GET /api/version` | #21 |
| [#4](https://github.com/EDortta/CodexBridge/issues/4) | authentication, authorization, mobile session | #22 |

CodexBridge #3 fixes the **paths** but describes the response only in prose
(status and timestamp, application/API version, build or commit identifier when
available, capability flags, no sensitive infrastructure details). The
field-level contract lands with #2, which is not written yet.

CodexBridge #1's completion criterion states that the mobile client "can replace
its fake API implementation with a generated or handwritten HTTP client
validated against the canonical contract" — so the backend already expects this
repository to hold a fake in the meantime.
