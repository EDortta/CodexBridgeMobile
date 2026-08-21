# Epic 14 — Segurança, privacidade e auditoria

- work_id: WK-20260821-gh-45-mobile-threat-model-and-security-baseline
- date: 2026-08-21
- public issue: https://github.com/EDortta/CodexBridgeMobile/issues/14

## Why this folder is named `epic-14`, not `phase-N`

`docs/issues/phase-0` through `phase-4` each hold one *sequential* epic
(`phase-N` → public issue `#(N+1)`, confirmed by reading each `README.md`'s
`public epic` line: phase-0→#1, phase-1→#2, phase-2→#3, phase-3→#4,
phase-4→#5). Epic #14 is not sequential — its own text says it "inicia após
a Epic #1 e acompanha todas as demais" (starts after Epic #1 and accompanies
all the others). Naming it `phase-13` would misrepresent it as "the 14th
thing worked in order", which is exactly what it is not: its issues get
picked up alongside whichever numbered phase is active, on a separate track.
`epic-14` names what it actually is instead of forcing it into a sequence it
was never part of.

## Objective (from the public issue)

Aplicar segurança e governança como capacidades transversais do aplicativo.

## Scope (from the public issue)

- [ ] Proteger segredos com Android Keystore — **done** (#21, #22)
- [ ] Implementar expiração, renovação e revogação de sessão — **done** (#22)
- [ ] Proteger ações críticas com biometria opcional — not started, no issue filed yet (see `docs/architecture/security-threat-model.md` R11)
- [x] Criar trilha de auditoria para decisões e operações sensíveis — issue filed (#46), not started
- [ ] Aplicar minimização de dados locais — not started, no issue filed yet (R11)
- [ ] Permitir limpeza segura de dados e revogação remota — not started, no issue filed yet (R11)
- [ ] Revisar permissões Android e exposição em logs — covered by #45's threat model (`docs/architecture/security-threat-model.md`, "Android permissions and local data exposure" section)
- [x] Produzir threat model inicial — **this issue (#45)**

## Acceptance criteria (from the public issue)

- Tokens e segredos não aparecem em armazenamento ou logs em texto aberto —
  verified for today's code in `docs/architecture/security-threat-model.md`
  (§Android permissions and local data exposure).
- Ações críticas são autenticadas e auditáveis — partially true today
  (auth exists); auditability is #46's job, not yet built.
- Permissões solicitadas são justificadas e mínimas — verified: exactly one
  runtime permission (`INTERNET`) exists today.

## Issues

- [#45 — Create mobile threat model and security baseline](https://github.com/EDortta/CodexBridgeMobile/issues/45)
  — size M, **finished**. See `issues/45-create-mobile-threat-model-and-security-baseline.md`
  and the deliverable itself, `docs/architecture/security-threat-model.md`.
- [#46 — Implement audit trail for sensitive operations](https://github.com/EDortta/CodexBridgeMobile/issues/46)
  — size L, not started. Scope boundary already recorded in
  `docs/issues/phase-3/README.md` ("Deliberately not built here: #46's audit
  trail") and `lib/features/decisions/domain/decision_audit_event.dart`'s own
  doc comment.
- #47 — Implement accessibility pass for core components and screens — filed
  under Epic #14 in GitHub but tracked as a separate, unrelated concern (a
  parallel worktree owns it); not covered by this folder or by the threat
  model.
