# Phase 1 Resume

- work_id: WK-20260804-phase-1-auth-and-connection
- date: 2026-08-04
- status: not_started (planning only)

## Current state

- Phase 0 is done and Epic #1 is closed. `main` and `development` are both at
  `f3a834c` — PR #49 was merged and `development` fast-forwarded to it, so the
  two branches are identical (0/0 divergence).
- **No branch, no code, no mirror file exists for #21 or #22.** The working tree
  is clean apart from the untracked `mobile/` zip.
- Epic #2 has two issues: #21 (server configuration and connection test, M) and
  #22 (authentication and session lifecycle, L). #21 comes first.

## Decisions already taken (operator, 2026-08-04)

- Persist the selected server with **`flutter_secure_storage`** (Android
  Keystore), not `shared_preferences` — the epic needs the Keystore for #22
  anyway, so one persistence layer serves both.
- Branch authorized for #21: **`feature/gh-21/server-configuration-and-connection-test`**
  (not created yet).

## Decision still open (BLOCKS #21's network layer)

How to implement the connection probe while `EDortta/CodexBridge#2` (the
canonical OpenAPI) is unwritten. Three options were put to the operator and the
session closed before an answer:

1. **Real paths + tolerant parsing + fake** — call `GET /health` and
   `GET /api/version` at the paths CodexBridge#3 already fixes, measure latency,
   read the `X509Certificate` via `dart:io HttpClient` (no new dependency).
   Require only `status` and `apiVersion`; treat every other field as optional
   and ignore unknown fields, so #2's final shape cannot break the client.
2. **Wait for CodexBridge#2** — build UI, URL validation, states and persistence
   against a fake probe; add HTTP later.
3. **Generic probe** — HTTP status, latency and certificate only, without
   interpreting the body.

See [README.md](README.md) for what CodexBridge#3 does and does not fix.

## Next Step (DO THIS FIRST)

Get the operator's answer on the connection-probe option above, then create
`feature/gh-21/server-configuration-and-connection-test` from `development`,
mirror #21 into `docs/issues/phase-1/issues/`, and implement.

Note: `android/app/src/main/AndroidManifest.xml` has **no `INTERNET`
permission**. Debug builds get it injected automatically; a release build will
not. #21 must add it.
