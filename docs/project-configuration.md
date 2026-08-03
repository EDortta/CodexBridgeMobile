# Project Configuration

- project_name: CodexBridgeMobile
- project_state: existing
- languages: shell
- frameworks: (none)
- package_managers: (none)
- automation_commands: (none)
- domains: collaboration-review, decision-governance, file-assistance, package-installation
- capabilities: actionable-artifacts, apk-installation, approvals, assisted-reading, conversations, operational-follow-up, operator-authorizations, reviews
- agents: claude, cursor, gemini, llm-api, openai-agents
- selected_agent: llm-api
- integration_status: missing

## Providers

- nvidia: purpose=general, model=nvidia/nemotron-3-super-120b-a12b, base_url=https://integrate.api.nvidia.com/v1, role=primary, mode=file-ref, credential_ref=.credentials/llm/nvidia.key

## Capability Ownership

- actionable-artifacts: collaboration-review
- apk-installation: package-installation
- approvals: decision-governance
- assisted-reading: file-assistance
- conversations: collaboration-review
- operational-follow-up: decision-governance
- operator-authorizations: decision-governance
- reviews: collaboration-review

## Required Reading Used For Scope

- `docs/required-reading.md`
- `AGENTS.md`
- `.docs/software-overview.md`
- `.docs/limits.md`
- `docs/project-rules.md`
- `.docs/agents/programmer.md`
- `.docs/agents/design-standards.md`
- `.docs/agents/reviewer.md`
- `.docs/agents/issue-automation.md`
- `.docs/agents/council.md`
- `.docs/agents/security.md`
- `.docs/agents/security-standards.md`
- `.docs/agents/privacy-compliance.md`
- `.docs/workflows/session-restore.md`
- `.docs/workflows/session-close.md`
- `.docs/context-optimization.md`
- `docs/napkin-lessons.md`
- `docs/product-foundation.md`

## Scope Summary

Codex Bridge Mobile is a mobile terminal for the Codex Bridge ecosystem that reduces human decision latency by supporting approvals, authorizations, follow‑up, reviews, conversations, actionable artifacts, assisted file reading, and APK installation while operating offline‑capable and audit‑ready.

## Notes

- detected 21 non-governance file(s); adoption flow should inspect before writing
- provider credentials stay outside project-config.json; use credential_ref only
