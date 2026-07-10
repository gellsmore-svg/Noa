# Contributing

Noa is the runtime scaffold for the family AI stack. Contributions are welcome
when they keep that boundary clear: Noa installs, configures, observes, and
health-checks sibling tools; it does not vendor their product code.

## Before Opening A Change

- Run `bash scripts/public_readiness_check.sh`.
- Run `bash tests/install_lib_test.sh`.
- Run `bash tests/codex_review_gate_test.sh`.
- If you touch `versions.git.lock`, also run
  `NOA_PUBLIC_CHECK_NETWORK=1 bash scripts/public_readiness_check.sh`.

## Change Guidelines

- Keep generated reports, `.env`, queue databases, backups, and local issue
  drafts out of Git.
- Prefer small, reviewable changes to install scripts, workflow scripts, and
  docs.
- Keep local-dev pins in `versions.lock` and fresh-machine public pins in
  `versions.git.lock`.
- Do not copy sibling project source into Noa. Update the sibling repo and bump
  Noa's pin instead.

## Good First Areas

- Documentation clarity for fresh installs.
- Better diagnostics in `health/healthcheck.sh`.
- Safer install/upgrade checks.
- Live-observer workflow improvements that keep raw private reports ignored.

## Issues

Use the GitHub issue templates for bugs and feature requests. Do not open public
issues containing secrets, `.env` values, raw traces, generated observer
reports, customer data, or private prompts. Use the security process for
vulnerabilities.

## Discussions

Use [GitHub Discussions](https://github.com/gellsmore-svg/Noa/discussions) for
design questions, install experience, public lockfile/tag strategy, and broader
family-stack coordination. Use issues for actionable bugs or scoped feature
requests.

## Pull Requests

Use the pull request template and complete the validation checklist. If a change
touches sibling versions, explain why the pin moved and whether the target ref
is public and reachable.
