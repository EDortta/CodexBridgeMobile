# #66 — Follow a running mission: live log tail and progress (polling)

- status: [draft]
- work_id: WK-20260830-gh-66-follow-running-mission
- public issue: https://github.com/EDortta/CodexBridgeMobile/issues/66
- parent epic: https://github.com/EDortta/CodexBridgeMobile/issues/62

## Context

`work_session_detail_screen.dart` today has a manual refresh button and
nothing else. The server already implements an `offset`/`limit` log contract
(`HttpLiveSessionRepository.loadSessionLogs`) that this issue simply has to
drive from the UI side -- no server work needed, which is why this is the
one issue in the epic deliverable today.

## Objective (from the public issue)

Give the operator a live-updating view of a running mission instead of
today's manual-refresh-only screen, using the log offset/limit contract the
server already implements.

## Scope

- New `lib/core/async/foreground_poller.dart` (interval, backoff on error,
  `AppLifecycleState`-aware, cancel on dispose) -- placed in `core/` because
  a future event-stream fallback and other follow surfaces will reuse it
- Changes to `lib/features/missions/presentation/live_session_providers.dart`
  (a log-tail provider holding the last offset), `work_session_detail_screen.dart`,
  `mission_detail_screen.dart`
- No change to `lib/features/missions/data/http_live_session_repository.dart`
  -- `loadSessionLogs(server, accessToken, sessionId, offset, limit)` already
  implements the offset contract this issue needs

## ARO

Deliberately polling, not streaming: the gateway's own capability report
currently answers `eventStream: false` (`probes.py`). Fully independent of
every other issue in this epic -- not blocked.

## Test plan

A test driving `AppLifecycleState.paused` and asserting no further network
calls within one interval; a test asserting the log tail never re-fetches or
duplicates already-displayed lines (offset honored); a test asserting a
terminal state stops the loop permanently.

## Definition of done

- [ ] Opening a running session shows new log lines within the poll
      interval with no operator action.
- [ ] Backgrounding the app stops polling within one interval.
- [ ] A terminal mission state stops the loop permanently.
- [ ] A poll failure degrades to the existing manual refresh with a visible
      reason, never an empty screen.
- [ ] `flutter analyze` clean, `flutter test` full suite green.
- [ ] Operator review.
