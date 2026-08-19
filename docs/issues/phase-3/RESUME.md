# Phase 3 Resume

- work_id: WK-20260819-gh-25-decision-inbox-and-filters
- date: 2026-08-19
- status: #25 finished, merged (`dda3992`), pushed, and closed on GitHub; #26 not started

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

## Next Step (DO THIS FIRST)

#25 is done. **#26 — Implement decision detail and resolution flows**
(size L) is next in Epic #4: show context, impact, risks, evidence,
affected entities and discussion; implement approve, reject, request
revision and discuss actions. Depends on #25's richer `Decision` model
(already in place) and needs a real decision detail route (today, tapping
an inbox card does nothing — #25 was explicitly scoped to list + filter,
not per-item navigation, since #26 owns the detail screen).
