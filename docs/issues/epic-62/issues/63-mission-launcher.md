# #63 — Mission launcher: run "resolve issue X" from the phone

- status: [draft]
- work_id: WK-20260830-gh-63-mission-launcher
- public issue: https://github.com/EDortta/CodexBridgeMobile/issues/63
- parent epic: https://github.com/EDortta/CodexBridgeMobile/issues/62

## Context

Today the app can read issues (`issues_screen.dart`, `issue_detail_screen.dart`)
and watch missions (`work_screen.dart`), but the two are unconnected: there
is no create path in `MissionRepository` because there is no create path on
the gateway. `EDortta/CodexBridge#68` (`POST /api/v1/missions`) is what makes
this issue buildable at all.

## Objective (from the public issue)

Let the operator pick an issue on a project and launch it as a mission from
the phone, choosing which agent engine runs it.

## Scope

- `lib/features/missions/domain/mission_launch_request.dart`,
  `mission_launch_repository.dart` (new domain types/port)
- `lib/features/missions/data/http_mission_launch_repository.dart`,
  `mock_mission_launch_repository.dart`
- `lib/features/missions/presentation/mission_launch_screen.dart`, additions
  to `mission_providers.dart`
- `lib/app/mission_launch_binding.dart`, a new segment in
  `lib/core/navigation/app_routes.dart`, route registered in
  `lib/app/app_router.dart`
- Entry point from `lib/features/issues/presentation/issue_detail_screen.dart`
  via `context.go(AppRoutes.missionLaunchFor(issueId))` -- a route, never a
  direct import: `test/architecture/layer_boundaries_test.dart` fails the
  build on any feature-to-feature import
- Reuse `lib/core/identifiers/idempotency_key.dart` (generate once per
  logical launch, reuse on retry, per its own doc comment)

## ARO

Allowed: new feature-local files under `lib/features/missions/`, one new
`lib/app/` binding, one new route segment. Prohibited: any feature importing
another feature directly; inventing a mission-creation endpoint shape ahead
of the server. Out of scope: engine choice (#64), delivery pre-authorization
(#65), following the run (#66).

Blocked on `EDortta/CodexBridge#68` -- there is no way to create work from
mobile today, only from the MCP tool.

## Test plan

`MockMissionLaunchRepository` covering success, 409-conflict replay (same
idempotency key returns the same mission, not a duplicate), 403 missing
scope, and capability-off (no launch affordance rendered). Widget tests
under `test/features/missions/presentation/mission_launch_screen_test.dart`.

## Definition of done

- [ ] A launch from an issue creates exactly one mission and navigates to
      its detail screen.
- [ ] A retried request after a lost connection creates no second mission.
- [ ] The launch control is absent, not disabled, when the server reports no
      mission-creation capability.
- [ ] A launch landing in an approval-pending state deep-links to the
      existing decision surface rather than reporting failure.
- [ ] `flutter analyze` clean, `flutter test` full suite green.
- [ ] Operator review.
