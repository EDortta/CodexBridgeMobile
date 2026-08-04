# 01 - First Day Setup

## Happy story: Lia started the right way
Lia is a junior developer. She wants AI speed without losing control. On day one, she does not start coding. She first prepares context and boundaries, so the agent works with clarity.

## What is yours (programmer)
- Write real project context in `.docs/software-overview.md`.
- Define hard boundaries in `.docs/limits.md`.
- Set readiness flags to `yes`.

## What is the agent's
- Read these files before planning or editing.
- Respect boundaries and flag conflicts.
- Propose a plan consistent with project reality.

## Step by step

**1. Install the policy pack with GovernanceKit.**

```bash
pip install git+https://github.com/EDortta/AI-GovernanceKit.git
governancekit --root "$PWD" install-agents
```

This keeps kit files and project-owned documentation separate. Do not copy a kit
directory into a project by hand.

**2. Validate the setup.**

```bash
governancekit doctor
```

You will see a list of checks. Most will fail on a fresh install — that is expected. Fix each `[FAIL]` line before moving on.

**3. Fill `.docs/software-overview.md`** with your product purpose, tech stack, and main modules.

**4. Fill `.docs/limits.md`** with what agents are allowed and not allowed to do in this project.

**5. Fill `docs/project-rules.md` and list every required project contract in `docs/required-reading.md`.**

**6. Set the readiness flags.**

Open both files and set:
```
project_context_ready: yes
limits_ready: yes
```

Run `governancekit doctor` again — it should pass now.

**7. Generate the code map.**

```bash
governancekit map
```

This creates `docs/codemap.md` — a Markdown index of your files and symbols. Commit it. Agents read this at session start instead of scanning files one by one.

**8. Only then request implementation.**

## Prompt starter
"Run `governancekit resume` first, then read AGENTS.md, software-overview, and limits. Confirm constraints and propose a short plan before coding."

## Definition of done
- `governancekit doctor` passes all checks.
- `docs/codemap.md` exists and is committed.
- The agent knows what to do and what to avoid.
- You can restart any session without losing context.
