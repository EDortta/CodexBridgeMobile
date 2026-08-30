# #64 — Executor/engine picker with capability-aware controls

- status: [draft]
- work_id: WK-20260830-gh-64-executor-engine-picker
- public issue: https://github.com/EDortta/CodexBridgeMobile/issues/64
- parent epic: https://github.com/EDortta/CodexBridgeMobile/issues/62

## Context

CodexBridge is gaining a second agent engine (Claude Code, alongside Codex --
`EDortta/CodexBridge#64`), each with different declared capabilities
(`sandbox_enforced_by`, `supports_resume`, cost reporting). Picking the wrong
executor or engine is how a mission stalls in `waiting_executor` overnight;
this issue gives the operator that choice at launch time instead of leaving
it implicit.

## Objective (from the public issue)

Let the operator choose which executor and which agent engine runs a
launched mission, with controls limited to what the chosen combination
actually supports.

## Scope

- New feature `lib/features/executors/`: `domain/executor.dart`,
  `domain/executor_capability.dart`, `domain/executor_repository.dart`,
  `data/http_executor_repository.dart`, `data/mock_executor_repository.dart`,
  `presentation/executor_providers.dart`, `presentation/executor_picker.dart`
- `lib/app/executor_repository_binding.dart`
- Because the picker is consumed by the missions launcher (#63) and features
  may not import each other (`test/architecture/layer_boundaries_test.dart`),
  this issue must explicitly choose one of: (a) host the executor domain
  type in `lib/core/` with the picker widget owned by the missions feature,
  or (b) expose the picker on its own route returning a selection through a
  `core/` result channel.

## ARO

Blocked on `EDortta/CodexBridge#68` (executor id travels with the create
call) and informed by `EDortta/CodexBridge#64` (runner capability
declarations). Until capability data exists server-side, capability
rendering degrades to "unknown" rather than inventing flags. There is no
`GET /api/v1/executors` today -- this issue also needs a small dedicated
read endpoint on the CodexBridge side, or reuse of adjacent data; do not
assume one exists.

## Test plan

Unit tests for `Executor.fromJson` against the real gateway shape; a widget
test proving a missing capability removes (not disables) the corresponding
control.

## Definition of done

- [ ] The launcher cannot submit without a resolved executor.
- [ ] A mission queued to an offline executor renders `waiting_executor`,
      not "running", and requires explicit confirmation to queue.
- [ ] Every control gates on a declared capability, never an assumed one.
- [ ] `flutter analyze` clean, `flutter test` full suite green.
- [ ] Operator review.
