# Noa Publication Readiness

This note records the publication-readiness review that was completed before
Noa was made public.

## Result

Noa is public as of `v0.1.0` on 2026-07-09.

Noa is valuable as a public orchestration layer, but it is also the repo that
describes how the family tools are installed, configured, observed, and run
together. That makes it the place where local-machine assumptions, operational
notes, and accidental secrets are most likely to leak. Publication was treated
as a small release, not a settings toggle.

## Current Audit Notes

- `.env` is ignored by `.gitignore`; `.env.example` is the intended public
  template.
- `reports/` is ignored and should remain untracked. Live observer outputs can
  include prompts, traces, token counts, findings, and issue drafts.
- `versions.git.lock` points at public git refs for the sibling projects.
- Historical docs may mention old machine-specific defaults; keep those generic
  and explicit as historical findings rather than live configuration advice.
- Noa uses the same license as the sibling repositories:
  [Apache License 2.0](../LICENSE).

## Public-Ready Checklist

- Confirm the repository license remains aligned with the sibling repositories. Done: Apache License 2.0.
- Confirm all sibling repos referenced by `versions.git.lock` are public or intentionally accessible to the target audience.
- Run `bash scripts/public_readiness_check.sh` before changing visibility.
- Run `NOA_PUBLIC_CHECK_NETWORK=1 bash scripts/public_readiness_check.sh` to verify public git refs are reachable. Done in clean clone at `1efd90c0c593`.
- Run a broader tracked-file secret scan before changing visibility. Done for tracked docs and scripts; only benign documentation terms and token-budget variable names were found.
- Confirm no tracked file contains personal paths, credentials, private host
  names, customer data, prompts, traces, or live reports. Done by automated
  check plus tracked documentation review; generated `reports/` content remains
  ignored.
- Keep `.env`, backups, live reports, local issue drafts, databases, and queue
  outputs ignored.
- Update docs that still say Noa is private unless they are clearly historical. Done for the fresh-install path and lockfile comments.
- Add a short public-positioning paragraph to the README: Noa is an orchestration/runtime scaffold, not a vendor of sibling project code. Done.
- Run install and review-gate tests from a clean checkout using `VERSIONS_LOCK=versions.git.lock`. Done in clean clone at `1efd90c0c593`.

## What Should Stay Out Of The Public Repo

- Local `.env` files.
- Generated live observer reports from real sessions.
- Galeed trace exports from real work.
- Hoglah queue databases or outbox payloads.
- Machine-specific service overrides.
- Customer or workplace process artifacts.
- Any issue drafts generated from private observations.

## Visibility Decision

Noa is public at [github.com/gellsmore-svg/Noa](https://github.com/gellsmore-svg/Noa).
The `v0.1.0` release records the first public baseline. Automated hygiene
checks, network pin checks, install workflow tests, and Codex review-gate tests
passed from a fresh GitHub clone before publication, and public CI is green.
