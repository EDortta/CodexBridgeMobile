# Epic 14 — Segurança, privacidade e auditoria

- work_id: WK-20260821-gh-45-mobile-threat-model-and-security-baseline
- date: 2026-08-21
- public epic: https://github.com/EDortta/CodexBridgeMobile/issues/14

See `epic.md` for why this folder is named `epic-14` rather than
`phase-N`, and for the epic's objective, scope checklist and status.

## Issues

- [#45 — Create mobile threat model and security baseline](https://github.com/EDortta/CodexBridgeMobile/issues/45)
  — size M, **finished**. See `issues/45-create-mobile-threat-model-and-security-baseline.md`.
- [#46 — Implement audit trail for sensitive operations](https://github.com/EDortta/CodexBridgeMobile/issues/46)
  — size L, not started.

## The deliverable

The threat model and baseline itself lives in
`docs/architecture/security-threat-model.md` — grouped with this
repository's other cross-cutting architecture docs
(`state-architecture.md`, `navigation.md`) rather than under this folder,
since it is read by name from `docs/required-reading.md`'s "Por área"
section whenever anyone touches auth, storage, network, files, APK
delivery or notifications, not only when working an Epic #14 issue.

## Follow-ups this issue surfaced but did not file

`docs/architecture/security-threat-model.md` names several risks and
checklist gaps that need a GitHub issue but do not have one yet (R1, R4, R6,
R11). Filing them is the operator's call — recorded here so the next reader
of this folder sees the list without re-reading the full threat model:

- R1 (critical): dedicated release signing keystore — release build is
  currently signed with this project's own debug keystore, which must never
  leak (see the threat model for why "debug keystore" isn't a shared secret
  across machines).
- R4 (medium): `SecureSessionStore` pending-removal marker fail-open/
  fail-closed asymmetry.
- R6 (low/medium): `android:allowBackup="false"` / `dataExtractionRules`
  before Epic #12 adds a local cache.
- R11 (three items): biometric gate for critical actions, local data
  minimization policy, remote wipe/revocation — all listed in Epic #14's own
  scope with no issue filed against any of them.
