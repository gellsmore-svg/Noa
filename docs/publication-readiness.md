# Noa Publication Readiness

This note records whether Noa should be made public and what must be true before
changing GitHub repository visibility.

## Recommendation

Do not make Noa public until the checklist below is complete.

Noa is valuable as a public orchestration layer, but it is also the repo that
describes how the family tools are installed, configured, observed, and run
together. That makes it the place where local-machine assumptions, operational
notes, and accidental secrets are most likely to leak. Treat publication as a
small release, not a settings toggle.

## Current Audit Notes

- `.env` is ignored by `.gitignore`; `.env.example` is the intended public
  template.
- `reports/` is ignored and should remain untracked. Live observer outputs can
  include prompts, traces, token counts, findings, and issue drafts.
- `versions.git.lock` points at public git refs for the sibling projects.
- Some historical docs describe Noa as private or mention old machine-specific
  defaults; these should be either updated, moved to a historical note, or made
  explicit as fixed legacy findings.
- No license file is present in Noa at the time of this note. A public repo
  should include an explicit license, or intentionally state that it is not
  licensed for reuse.

## Public-Ready Checklist

- Decide and add the repository license.
- Confirm all sibling repos referenced by `versions.git.lock` are public or
  intentionally accessible to the target audience.
- Run a tracked-file secret scan before changing visibility.
- Confirm no tracked file contains personal paths, credentials, private host
  names, customer data, prompts, traces, or live reports.
- Keep `.env`, backups, live reports, local issue drafts, databases, and queue
  outputs ignored.
- Update docs that still say Noa is private unless they are clearly historical.
- Add a short public-positioning paragraph to the README: Noa is an
  orchestration/runtime scaffold, not a vendor of sibling project code.
- Run install and review-gate tests from a clean checkout using
  `VERSIONS_LOCK=versions.git.lock`.

## What Should Stay Out Of The Public Repo

- Local `.env` files.
- Generated live observer reports from real sessions.
- Galeed trace exports from real work.
- Hoglah queue databases or outbox payloads.
- Machine-specific service overrides.
- Customer or workplace process artifacts.
- Any issue drafts generated from private observations.

## Visibility Decision

Once the checklist is complete, making Noa public is sensible. It gives the
family stack a clear, inspectable entry point and makes the installation story
more coherent. Until then, keep Noa private or publish a cleaned release branch
instead of flipping the current repository in place.
