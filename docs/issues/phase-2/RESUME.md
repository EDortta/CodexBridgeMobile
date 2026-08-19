# Phase 2 Resume

- work_id: WK-20260819-gh-23-projects-list-search-and-filters
- date: 2026-08-19
- status: #23 finished; #24 not started

## Current state

`feature/gh-23/build-projects-list-search-and-filters` implements #23:
project cards with a health badge (active/unhealthy/pending decision/offline,
never color alone — icon and label always shown), a card-visible
`attentionSummary` so a project needing attention is legible without
opening it, a search field, a single-select health/favorites filter chip
row, and locally-persisted favorites (`SecureProjectFavoritesStore`, reusing
the Keystore seam `SecureKeyValueStore` already shares with #21/#22 — fails
open on read since favorites are a convenience, not a secret).

`flutter analyze`: clean. `flutter test`: 182/182 passing (25 new: domain,
data, controller, pure-filter and widget tests for #23).

Not validated:
- The real Android Keystore path (`FlutterSecureKeyValueStore`) — no host-VM
  test can reach it; same limit `secure_server_config_store_test.dart`
  documents for #21.
- A multi-round adversarial council pass, unlike #21/#22/#31/#32. This
  delivery had a single self-review pass instead; flagging in case the
  operator wants the fuller process run separately before merge.

## Decision made without an operator round-trip (documented here, not silently assumed)

"Offline" appears twice in #23's acceptance text: as one of the four filter
categories, and in "loading, empty, error and offline states exist." Device
network-connectivity detection was **not** built as a separate screen-level
state: `ProjectRepository` is still `MockProjectRepository`, so there is no
real network call yet for a connectivity banner to describe, and
`ProjectHealth.offline` already carries the "this project is unreachable"
meaning on both the card and the filter chip. Building real connectivity
detection (a new `connectivity_plus`-style dependency) against a fake
repository would be inventing infrastructure ahead of the real contract —
the exact mistake `docs/napkin-lessons.md`'s 2026-08-04 entry warns against.
Revisit when #24 or a real `HttpProjectRepository` (blocked on CodexBridge
#5) gives this a real network call to report on.

## Next Step (DO THIS FIRST)

Operator reviews #23 (branch not yet merged). Once accepted: council pass
(optional, operator's call), commit, merge to `development`, push, close
#23 on GitHub referencing the commit, update this file.

After that, **#24 — Implement project operational dashboard** (size L) is
next in Epic #3, and depends on #23's `ProjectSummary`/health model existing,
which it now does.
