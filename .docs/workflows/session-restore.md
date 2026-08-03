# Session-Restore Workflow

Use only when resuming active work.

## Active Work Detection

Identify active work from one source:
- current branch name
- explicit user instruction
- last updated epic in `docs/issues/`

Prefer CLI helpers when available, for example:
- `jkctl resume <work_id>`

## Required Read Order

Read in this order:
1. `docs/issues/<epic>/RESUME.md`
2. `handoff.md`
3. current task file under `docs/issues/<epic>/issues/`

If `RESUME.md` is missing:
1. create it from the latest handoff and issue file
2. define one valid `Next Step (DO THIS FIRST)`
3. keep it under roughly 50 lines

## Next Step Rule

`RESUME.md` is the source of truth for the immediate action.

It must contain exactly one:
- `Next Step (DO THIS FIRST)`

The next step must be concrete and actionable.
Do not accept vague instructions such as:
- continue work
- refactor module
- improve logic

Each session must either complete the next step or replace it with a new valid next step.
