# Phase 3 Resume

- work_id: WK-20260819-gh-26-decision-detail-and-resolution-flows
- date: 2026-08-19
- status: #25 and #26 both finished, merged, pushed, and closed on GitHub

## Current state

`feature/gh-25/build-decision-inbox-and-filters` implements #25.
`decisions_screen.dart` was a 39-line Phase-0 placeholder (`ListTile`,
no filters, no tap) — replaced with an inbox showing urgency/risk/state/
project/deadline filters that combine (`filterDecisions`, pure and
independently tested), a critical decision visually distinct from a routine
one (red border **and** an explicit "Critical" label — never color alone),
and each card showing the request (title), impact and agent recommendation
summary #25's acceptance text asks for.

`Decision` gained `urgency` (`DecisionUrgency`), `risk` (`DecisionRisk`),
`state` (`DecisionState`), `deadline`, `impactSummary`,
`recommendationSummary` — all additive, shaped directly off CodexBridge #6's
proposed scope rather than guessed independently (see `README.md`).
`DecisionRepository.loadPendingDecisions()` → `loadDecisions()` (returns
every state now, not just pending; the inbox filters client-side, defaulting
to `state == pending` since an inbox opens on what still needs the
operator). `pendingDecisionsProvider` — which #24's dashboard already
depends on — is now a **derived** view of `decisionsProvider` narrowed to
`pending`, so `project_dashboard_screen.dart` needed **zero changes**: same
provider name, same `AsyncValue<List<Decision>>` type at the watch site.

`flutter analyze`: clean. `flutter test`: 235/235 passing (24 new, 0
regressions — confirmed #24's dashboard tests, which depend on the exact 3
pre-existing `codex-bridge-mobile`/`codex-bridge-desktop` decision fixtures,
still pass unchanged).

Not validated:
- The real Android Keystore path / on-device visual check — same
  pre-existing environment NDK issue #24 hit (`docs/napkin-lessons.md`
  2026-08-03 WK-20260803-gh-16).
- A multi-round adversarial council pass — single self-review pass, same as
  #23/#24.

## Judgment calls made without a further operator round-trip (documented, not silently assumed)

- **`state` default = `pending`, not "all"** — "inbox" implies what still
  needs the operator; the mock repository was expanded with 2 resolved
  decisions (approved/rejected) specifically so the state filter, and the
  default view's exclusion of them, has something real to demonstrate.
- **"Pending and critical decisions are visually distinct" read as two
  independent things**, not one state: `state == pending` decisions render
  full-opacity (actionable), everything else recedes (0.6 opacity, but the
  state badge always says so in text — opacity is never the only signal);
  `urgency == critical` gets the red border + explicit "Critical" label
  regardless of state, matching the accessibility rule #23/#24 already
  established (icon/label pairing, never color alone).
- **Project filter shows raw `projectId` strings**, not project names —
  joining to `ProjectSummary.name` would require `decisions` importing
  `projects`' presentation layer, which `test/architecture/layer_boundaries_test.dart`
  forbids (a feature may not import another feature). `LiveSession.projectId`
  is already shown as a raw string elsewhere in the app (`SessionCard`) —
  same precedent.
- **Deadline filter buckets are duration-based** (`overdue` / within 24h /
  within 7 days), not calendar-day based, so `classifyDeadline` needs no
  time-zone-aware calendar math — consistent with `RelativeMoment`'s own
  duration-based staleness math from #24.
- **Filter menu = `PopupMenuButton` per axis**, not five chip rows or a
  combined filter sheet — five independent single-select menus is the
  simplest widget that still satisfies "filters can be combined" (each axis
  narrows independently, AND-combined in `filterDecisions`).

## #26 — Implement decision detail and resolution flows

Branch `feature/gh-26/decision-detail-and-resolution-flows`.
`DecisionDetailScreen` (`lib/features/decisions/presentation/`, fully
self-contained — no cross-feature composition needed, unlike #24's
dashboard) reached via `?decision=<id>` on a new `/decisions/detail` route
(`AppRoutes.decisionDetail`, same query-param convention `?session=<id>`/
`?project=<id>` already established). `_DecisionCard.onTap` (#25 left this
unwired on purpose) now navigates there.

`Decision` gained `context`, `riskDetails`, `evidence`, `affectedEntities`
(all default to empty — `''`/`const []` — so #25's inbox-only fixtures
still compile unchanged), `discussion` (`List<DecisionComment>`) and
`auditTrail` (`List<DecisionAuditEvent>`), plus a `copyWith`.
`DecisionRepository` gained `loadDecision`, `approve`, `reject`,
`requestRevision`, `discuss` — the first **write-capable** repository
interface in this app. `MockDecisionRepository` is now genuinely stateful
(an in-memory `Map<String, Decision>`, mutated in place) rather than
returning a fresh `Future.value(list)` every call, the same way a real
backend would persist a resolution — the first mock repository here that
needed this, since nothing earlier ever wrote through one. Its clock is
injectable (`Clock` from `core/format/relative_moment.dart`) so audit
timestamps are deterministic in tests.

Rejection and request-revision both require a non-empty comment (thrown as
`ArgumentError` from an `async` method, so it always surfaces through the
returned `Future` — not synchronously out of the call, which the first
version of this code got wrong and a test caught immediately). A critical
decision's approve/reject/request-revision additionally requires an
explicit, decision-and-action-specific acknowledgement checkbox before
submit enables (`_ResolutionDialog`) — deliberately **not**
`runSessionControlAction`'s plain Yes/No dialog (`features/missions/`),
since Epic #4's own text rules out generic confirmation for critical
actions. Discuss never requires the critical checkbox (it doesn't change
`state`) but does require non-empty text.

`flutter analyze`: clean. `flutter test`: 260/260 passing (25 new — 21
decisions-feature tests plus 1 new `app_router_test.dart` case pinning
inbox-card → detail navigation — 0 regressions; #24's dashboard tests, which
read `Decision` through the unchanged `pendingDecisionsProvider` shape,
still pass with no edits).

Not validated: same as #25 (real Android Keystore path, on-device visual
check blocked by the pre-existing NDK environment issue, no multi-round
council).

## Judgment calls made without a further operator round-trip (documented, not silently assumed)

- **"All outcomes create an audit event" scoped to this feature only.**
  `DecisionAuditEvent` records approve/reject/revision locally; the
  cross-cutting, immutable, redacted audit *store* is #46's job (Epic #14,
  not started) — see `README.md`'s dedicated section. Building #46 here
  would have been out of scope for a size-L issue that already touches
  domain model, repository, provider and two screens.
- **"Discuss" never requires the critical-decision checkbox.** Only
  approve/reject/request-revision change `state`; a comment thread is not
  the "critical action" the epic worries about.
- **Approve's comment is optional; reject's and request-revision's are
  required.** The issue text only states rejection's requirement
  explicitly ("Aprovar com comentário opcional" for approve, from the epic).
  Request-revision's requirement is inferred: a revision request with
  nothing to revise is not actionable — same reasoning discuss's
  requirement uses.
- **Critical-decision confirmation = a decision-and-action-specific
  checkbox**, not a typed confirmation phrase or a second dialog step. A
  checkbox is simpler to build and test than type-to-confirm while still
  satisfying "not generic" — the checkbox label names the specific decision
  title and the specific action, so it cannot be satisfied by a reflexive
  tap the way a bare "Are you sure?" can.
- **Actor is hardcoded to `'You'`.** No seam currently exposes the signed-in
  operator's name to `decisions/` without a cross-feature import (auth's
  `Session.operatorName` would require one); in the real backend, actor
  identity comes from the auth token server-side anyway, so a mock actor
  string is a reasonable stand-in, not a gap worth new architecture for.

## Next Step (DO THIS FIRST)

#26 is done: merged to `development` (`dac015d`), pushed, closed on GitHub.

Epic #4 has no further issues currently tracked beyond #25/#26.

Correction (2026-08-19): the line this replaced said "#29/#30 epics/issues
browser, #35/#36 artifacts" were "Epic #3's remaining issues" — wrong on two
counts. Epic #3 (Projects and dashboard) is fully done: #23 and #24 were its
only two issues, both closed. #29/#30 belong to **Epic #6** (Epics, Issues
e planejamento); #35/#36 belong to **Epic #9** (Artefatos e visualização).
Verified via `gh issue view <n> --json body` on all of #23/#24/#27-#40
before picking the next issue — see `docs/issues/phase-4/RESUME.md` for
what came next (**Epic #5**, Missions: #27/#28), chosen over #46 (audit
trail, Epic #14) and Epic #6/#9 as the most appropriate next step —
dependencies satisfied, natural epic order, and the same list+filters /
detail+actions shape #25/#26 just proved out.
