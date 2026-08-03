# Agent Operational Limits

## Metadata

- work_id: WK-20260803-governancekit-project-configuration
- date: 2026-08-03
- owner: Esteban
- limits_ready: yes

## Allowed

- Implement explicitly requested mobile-client issues, including focused tests,
  documentation, and directly required refactors.
- Build and validate local Android artifacts when the relevant issue requires it.
- Update project issue, handoff, and learning artifacts that directly support the
  active work.

## Prohibited Without Explicit Approval

- Deploy, publish, or distribute an APK; push to production; restart remote
  services; or change backend infrastructure.
- Read, expose, commit, or copy credentials, OAuth secrets, Keystore material,
  `.env*`, or `.credentials/` contents.
- Add unrestricted device permissions, background collection, or external
  communications not required by an approved issue.
- Turn the application into a mobile IDE or add heavyweight desktop-development
  workflows.
- Make backend API, authentication, persistence, or audit-contract changes
  without declaring their compatibility and downstream impact.

## Workflow Constraints

- Work one issue at a time. Each behavior change receives focused tests, a
  critical diff review, and a separate commit after applicable checks pass.
- Never start implementation on `main` or `master`; create or switch branches
  only with explicit operator permission.
- Preserve offline behavior, concise actionable context, granular permissions,
  and auditability for critical actions.
- Treat the Android APK as the local delivery artifact. Any external hosting or
  backend deployment requires a separate explicit authorization.

## Security Boundary

- Security-sensitive changes require threat-aware review and tests proportionate
  to the affected surface.
- No secret may appear in source, logs, screenshots, issue bodies, commits, or
  generated artifacts.
