# #65 — Pre-authorize branch and push at launch time

- status: [draft]
- work_id: WK-20260830-gh-65-preauthorize-branch-push
- public issue: https://github.com/EDortta/CodexBridgeMobile/issues/65
- parent epic: https://github.com/EDortta/CodexBridgeMobile/issues/62

## Context

CodexBridge's delivery contract (`EDortta/CodexBridge#66`) makes commit/push
authorization an explicit, narrow, per-mission grant rather than a blanket
one. This issue is the mobile half: the same explicitness has to exist on
the screen that requests it, and the grant that is actually in effect has to
stay visible for the mission's whole lifetime.

## Objective (from the public issue)

Make branch and push authorization for a launched mission explicit, narrow,
and visible for the mission's whole lifetime -- never an implicit default.

## Scope

- `lib/features/missions/domain/delivery_authorization.dart` (branch name,
  base ref, `mayPush`, `mayOpenPullRequest`, expiry), serialized into the
  launch request from #63
- A confirmation section in `mission_launch_screen.dart` matching the
  existing irreversible-action confirmation pattern in
  `lib/features/missions/domain/live_session_repository.dart`
  (`LiveSessionControlAction.isDestructive` / `confirmTitle`)
- A read-only rendering of the granted envelope on
  `lib/features/missions/presentation/mission_detail_screen.dart`, sourced
  from what the server echoes back -- never from what the client sent

## ARO

Blocked on `EDortta/CodexBridge#68` (must accept and persist the envelope)
and `#66` (delivery pre-authorization semantics). A gateway that does not
report support for pre-authorization must leave the section absent and push
un-granted -- never silently granted. Branch-name validation on the client
is a hint only; the server is the authority, and the UI must say so.

## Test plan

Widget test asserting no submit path exists without an explicit push choice;
test that the rendered envelope always reflects the server response, not the
last client-side edit.

## Definition of done

- [ ] No launch reaches the server without an explicit push decision.
- [ ] Every mission detail screen shows the exact delivery envelope the
      server granted, not a client-side echo.
- [ ] `flutter analyze` clean, `flutter test` full suite green.
- [ ] Operator review.
