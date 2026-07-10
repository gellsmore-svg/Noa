## Summary

Describe the change and why it belongs in Noa rather than a sibling repository.

## Boundary Check

- [ ] This keeps Noa as orchestration/runtime scaffolding.
- [ ] This does not vendor sibling project source code.
- [ ] Generated reports, `.env`, queue databases, backups, local issue drafts,
      raw traces, customer data, and private prompts are not included.

## Validation

- [ ] `bash scripts/public_readiness_check.sh`
- [ ] `bash tests/install_lib_test.sh`
- [ ] `bash tests/codex_review_gate_test.sh`
- [ ] If `versions.git.lock` changed:
      `NOA_PUBLIC_CHECK_NETWORK=1 bash scripts/public_readiness_check.sh`

## Notes

Mention any install, upgrade, health-check, observer, systemd, or lockfile
implications.
