# #68 — Reminders on the phone

- status: [draft]
- work_id: WK-20260830-gh-68-reminders-on-the-phone
- public issue: https://github.com/EDortta/CodexBridgeMobile/issues/68
- parent epic: https://github.com/EDortta/CodexBridgeMobile/issues/62

## Context

CodexBridge is adding Google Calendar reminders via ChatGPT
(`create_reminder`/`cancel_reminder`, `EDortta/CodexBridge#71`), but those
are MCP-only tools the phone cannot call directly -- it speaks REST.
`EDortta/CodexBridge#72` is the REST surface this issue actually depends on.

## Objective (from the public issue)

Surface CodexBridge-created reminders where the operator already is: a
list, a create form, and cancel.

## Scope

- New feature `lib/features/reminders/`: `domain/reminder.dart`,
  `domain/reminder_repository.dart`, `data/http_reminder_repository.dart`,
  `data/mock_reminder_repository.dart`, `presentation/reminder_providers.dart`,
  `presentation/reminders_screen.dart`, `presentation/reminder_compose_sheet.dart`
- `lib/app/reminder_repository_binding.dart`
- A route under Account (where `server`/`session` already nest, per
  `lib/core/navigation/app_routes.dart`) or a card on the Work screen --
  this issue must pick one explicitly and say why
- Reuse `lib/core/identifiers/idempotency_key.dart` for create

## ARO

Blocked on `EDortta/CodexBridge#72`. Independent of every other issue in
this epic -- no orchestration work required -- a good early, low-risk win
once #72 lands. Explicit non-goal: this app does not raise the
notification -- Google Calendar does; the UI copy must say so.

## Test plan

`MockReminderRepository` covering create, idempotent retry (no duplicate),
cancel, and the "calendar not configured" server message rendered verbatim
(not paraphrased).

## Definition of done

- [ ] Creating a reminder from the phone produces exactly one calendar event
      and it appears in the operator's Google Calendar app.
- [ ] A retry with the same idempotency key creates no duplicate.
- [ ] Cancelling removes it from both the list and the calendar.
- [ ] An unconfigured gateway shows the operator-actionable message from the
      CodexBridge side verbatim; the reminders entry point is hidden, not
      broken, when the feature is unavailable.
- [ ] `flutter analyze` clean, `flutter test` full suite green.
- [ ] Operator review.
