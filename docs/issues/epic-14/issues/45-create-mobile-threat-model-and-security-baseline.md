# #45 — Create mobile threat model and security baseline

- status: [finished]
- work_id: WK-20260821-gh-45-mobile-threat-model-and-security-baseline
- public issue: https://github.com/EDortta/CodexBridgeMobile/issues/45
- parent epic: https://github.com/EDortta/CodexBridgeMobile/issues/14
- branch: `feature/gh-45/create-mobile-threat-model-and-security-baseline`

## Context

Epic #14 (Segurança, privacidade e auditoria) is transversal and gates the
rest of its own issues — #46 (audit trail), and the still-unfiled biometric
gate / data minimization / remote wipe items — plus adjacent surfaces this
app has not built yet: APK install (#37/#38), SAF (#39), notifications
(#43/#44). None of those had a written threat model to build against; this
issue produces one, grounded in the authentication/session/network/storage
code that already exists (#16–#32) rather than a generic template.

## Objective (from the public issue)

Document assets, trust boundaries, actors, attack surfaces, abuse cases and
mitigations for authentication, decisions, files, artifacts and APK
delivery. Acceptance criteria: risks are prioritized; each critical risk has
an owner or follow-up issue; Android permissions and local data exposure are
covered.

## Scope

- Read the actual auth/session (#22), server (#21), and network client
  (#31/#32) code before writing anything, plus the Android manifest, network
  security config, Gradle signing config and CI workflow.
- `docs/architecture/security-threat-model.md`: assets, actors, trust
  boundaries, 7 concrete abuse cases against existing code (R1–R7, each
  prioritized Critical/High/Medium/Low with an owner or an explicit
  "recommend the operator file an issue" note), 4 baseline-requirement
  sections for unbuilt surfaces (R8 APK install, R9 SAF, R10 notifications,
  R11 unfiled Epic #14 checklist items), and an explicit "Android
  permissions and local data exposure" summary answering the issue's own
  acceptance criterion by name.
- `docs/issues/epic-14/` created (`epic.md`, `README.md`, this file) since
  Epic #14 has no existing phase folder and is not sequential — see
  `epic.md`'s own explanation.
- `docs/required-reading.md` gains one line under "Por área" pointing to the
  new doc.

Out of scope (deliberately, per this issue's own DoD and `docs/limits.md`):
no code changes. The threat model *names* R1 (debug-signed release build),
R4 (`SecureSessionStore` marker asymmetry) and R6 (`allowBackup`) as fixable
gaps rather than fixing them — each is either a decision needing a dedicated
keystore/issue of its own (R1), a narrow but separate hardening change with
its own test surface (R4), or tied to a feature that has not landed yet
(R6, Epic #12's local cache). Bundling any of them into a docs issue would
mix an undiscussed runtime change into a document review.

## ARO (Allowed / Prohibited / Out of scope) — carried from `docs/limits.md`

Implemented within "update project issue, handoff, and learning artifacts
that directly support the active work" and the security-review reading list
(`.docs/agents/security.md`, `.docs/agents/security-standards.md`). No
runtime code touched; no secret read, exposed or committed; no device
permission added; no backend/auth/persistence contract changed.

## Test plan

Docs-only delivery — no `flutter test` surface changed. Validated by:
`flutter analyze` (clean, unrelated to this change) and `flutter test`
(full suite green, unrelated to this change) run once at the end to confirm
the docs-only diff caused no regression, per `CLAUDE.md`'s "Report what was
validated and what was not validated."

## Definition of done

- [x] Assets, trust boundaries, actors, attack surfaces, abuse cases and
      mitigations documented for authentication, decisions, files (SAF
      baseline), artifacts and APK delivery (baseline).
- [x] Risks are prioritized (R1–R11, Critical→Low, in that order).
- [x] Each critical/high risk has an owner or an explicit follow-up-issue
      recommendation (R1, R2, R4, R6, R11) — three of Epic #14's own
      checklist items had no filed issue at all before this document named
      the gap.
- [x] Android permissions and local data exposure covered in a dedicated,
      issue-acceptance-criterion-named section.
- [x] `flutter analyze` clean, `flutter test` full suite green (docs-only
      diff, run to confirm no incidental regression).
- [ ] Operator review.
- [ ] Council pass (not run — docs-only delivery with no shared-contract or
      wide-file-count trigger per `.docs/workflows/git-delivery.md` §7's
      commit-de-entrega rule; reviewer.md's own scope is code review).
