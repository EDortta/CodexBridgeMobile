# #67 — "Your mission finished": delivery evidence and completion notification

- status: [draft]
- work_id: WK-20260830-gh-67-delivery-evidence-and-notification
- public issue: https://github.com/EDortta/CodexBridgeMobile/issues/67
- parent epic: https://github.com/EDortta/CodexBridgeMobile/issues/62

## Context

`lib/features/missions/domain/mission.dart` has declared `tests`, `files`,
`artifacts` since #28 and no server response has ever populated them --
`_session_dto`/`_mission_dto` on the gateway explicitly omit the result blob.
`EDortta/CodexBridge#69` finally exposes it. Separately, this app has zero
device-notification infrastructure today (`AndroidManifest.xml` declares
only `INTERNET`) and the gateway has no push channel at all (council finding
F27) -- `EDortta/CodexBridge#70` only covers email. Conflating the two into
one issue is how an app ends up promising a notification it cannot send;
this issue keeps them explicitly separate.

## Objective (from the public issue)

Close the loop the operator actually asked for: know when a launched
mission finished, with enough evidence to judge it.

## Scope -- Part A (deliverable, blocked on `EDortta/CodexBridge#69`)

- `lib/features/missions/domain/delivery_evidence.dart`, mapped in
  `lib/features/missions/data/http_mission_repository.dart` from a new
  `GET /api/v1/missions/{id}/delivery`
- Rendered in `mission_detail_screen.dart`, finally populating
  `Mission.files` / `Mission.tests` / `Mission.artifacts`
- A "what changed since you last looked" surface on next foreground, landing
  in the notification centre `#43` already owns

## Scope -- Part B (do not start; blocked indefinitely)

- `POST_NOTIFICATIONS` runtime permission + manifest entry, a
  notification plugin, device-token registration, a channel per event
  class, deep links into `AppRoutes`
- None of this can be built yet: no FCM, no local-notification plugin, no
  foreground service exist in this app, and the server has no device-push
  channel

## ARO

Part A blocked on `EDortta/CodexBridge#69`. Part B blocked on a CodexBridge
device-push/notification-channel issue that does not exist yet (recommend
filing one referencing council finding F27). This issue must not be closed
on the strength of an in-app banner alone.

## Test plan

Golden/widget tests for the delivery evidence section (present,
absent-with-reason, redacted values never rendered raw).

## Definition of done

- [ ] Part A: a completed mission shows branch, head commit, changed-file
      count/list, and test outcomes sourced from the server, redacted per
      the gateway's own rules -- no absolute path, no credential-shaped
      string, ever.
- [ ] Part A: a gateway build that does not serve the delivery endpoint
      shows "delivery evidence not available from this gateway", not an
      empty section.
- [ ] Part B: not closeable without a working end-to-end OS notification
      with the app closed.
- [ ] `flutter analyze` clean, `flutter test` full suite green (Part A).
- [ ] Operator review.
