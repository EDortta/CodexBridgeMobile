# Epic 62 — CBM: launch, follow, and get notified about ChatGPT-originated work

- work_id: WK-20260830-chatgpt-entry-mobile-control-plane
- date: 2026-08-30
- public issue: https://github.com/EDortta/CodexBridgeMobile/issues/62

## Objective (from the public issue)

Give the operator a path from a ChatGPT-originated request through to a
running, followable, and eventually notifiable piece of work on the phone:
launch a mission from an issue (choosing which agent runs it and
pre-authorizing branch/push), follow it live, see what it delivered, and get
told when it's done.

## Why this exists now

The CodexBridge (backend) sibling epic (`EDortta/CodexBridge#63`) adds a
conversational entry point for ChatGPT: `start_development_task` (#65),
pre-authorized delivery (#66), and completion notification (#70). None of
that reaches the phone yet, and three verified gaps in this repo made that
concrete before any code was written here:

1. **No REST endpoint creates work today.** The only way to start a task is
   the MCP tool `submit_codex_task` (soon `start_development_task`) --
   `EDortta/CodexBridge#68` (`POST /api/v1/missions`) is what gives this app
   its first way to launch anything at all. Every launcher-shaped issue
   below is blocked on it.
2. **Branch/commit/diff never cross the mobile HTTP boundary.** Both
   `_session_dto` and `_mission_dto` on the gateway explicitly omit the
   result blob, while `Mission.files`/`Mission.tests`/`Mission.artifacts`
   (`lib/features/missions/domain/mission.dart`) have existed since #28 and
   have never once been populated by a real response. `EDortta/CodexBridge#69`
   is what finally fills them.
3. **No event stream, no device push.** `android/app/src/main/AndroidManifest.xml`
   declares only `INTERNET` -- no `POST_NOTIFICATIONS`, no FCM, no
   local-notification plugin, no foreground service -- and the gateway's own
   `probes.py` reports `eventStream: false`. Anything promising "you'll know
   when it's done with the app closed" is undeliverable until a device-push
   channel exists on the CodexBridge side, which is not filed yet. Issue #67
   below says this plainly instead of quietly promising more than the system
   can do.

## Scope

- #63 Mission launcher (blocked on CB#68)
- #64 Executor/engine picker with capability-aware controls (blocked on CB#68, informed by CB#64)
- #65 Pre-authorize branch and push at launch time (blocked on CB#68, CB#66)
- #66 Follow a running mission: live log tail, polling-based (not blocked -- deliverable today)
- #67 "Your mission finished": delivery evidence (Part A, blocked on CB#69) + completion notification (Part B, blocked indefinitely -- no device-push infrastructure exists anywhere in this app)
- #68 Reminders on the phone (blocked on CB#72)

## Dependencies on CodexBridge (`EDortta/CodexBridge`)

| CBM issue | Depends on |
|---|---|
| #63 launcher | #68 (`POST /api/v1/missions`) |
| #64 executor picker | #68, informed by #64 (runner capabilities) |
| #65 push pre-authorization | #68, #66 (delivery contract) |
| #66 live log tail | none |
| #67 delivery evidence + notification | Part A: #69. Part B: an unfiled device-push issue (F27) |
| #68 reminders | #72 (REST surface; #71 is MCP-only, unreachable from the phone) |

## Non-goals

- Building any client-side push/FCM infrastructure in this epic (separate,
  currently unfiled CodexBridge issue -- see #67's Part B).
- Choosing paths, sandbox modes, or provider CLI flags from the phone --
  those stay server-side decisions the launcher only requests.

## Done when

From the phone, an authorized operator can pick a project issue, choose an
engine, decide whether push is authorized, submit it, watch it run, see what
it delivered, and learn it's done -- with every currently-undeliverable
piece named as such rather than silently promised.
