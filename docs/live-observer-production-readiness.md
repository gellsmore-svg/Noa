# Live Observer Production Readiness

Date: 2026-07-08

This is the current production-readiness snapshot for the Noa live-observer path:

```text
Galeed trace events -> Cairn observations -> Cairn live-observer report -> Noa workflow artifacts
```

## Current Pins

The reproducible fresh-machine lock is `versions.git.lock`.

- Hoglah: `b8ff2416885e`
- Galeed: `b4b8961499e1`
- Cairn: `a516844a454b`
- Noa workflow: tracked in this repository on `main`

## Verified

- Noa public-readiness checks pass:
  - `bash scripts/public_readiness_check.sh`
  - `NOA_PUBLIC_CHECK_NETWORK=1 bash scripts/public_readiness_check.sh`
- Noa installer/workflow tests pass:
  - `bash tests/install_lib_test.sh`
  - `bash tests/codex_review_gate_test.sh`
- Noa CI runs the public-readiness, installer/workflow, and Codex review-gate tests on pushes and pull requests to `main`.
- Noa's live observer fails on an empty Galeed export by default, with `--allow-empty` reserved for deliberate baseline tests.
- Noa's scheduled observer wrapper writes timestamped report directories.
- Noa's live observer writes a companion Cairn agent-harness plan beside each
  report so operator or agent follow-up carries the HCI/cognitive-aesthetic
  review prompts from the pinned Cairn release.
- Noa's scheduled observer refreshes Markdown and JSON indexes over repeated findings.
- Noa drafts local GitHub-ready issue Markdown when findings cross repeat/risk thresholds.
- Noa can dry-run or explicitly publish those drafts through the GitHub CLI.
- On native Linux, `install/install.sh` renders and enables a systemd user timer for scheduled observer runs.
- Noa can fall back to a local Cairn virtualenv when `cairn-galeed-observe` is not on `PATH`.
- Cairn live-observer CLIs now return clean errors for invalid input and output-write failures.
- Hoglah emits queue lifecycle duration metadata to Galeed.
- Galeed exposes a producer helper for Cairn-readable observations.

## Local Production Smoke

Command:

```bash
./workflows/live_observer.sh \
  --session hoglah \
  --limit 100 \
  --title "Noa Hoglah live observer production smoke" \
  --out-dir /tmp/noa-observer-smoke-final
```

Observed output:

- Galeed export: 24 Hoglah queue events.
- Cairn observations: 24 JSONL observations.
- Cairn report findings:
  - queue vigilance load,
  - long queue lifecycle, with 9 lifecycles at or above 30000 ms,
  - repeated observation cluster.
- Report risk: moderate.

## Production-Ready Enough For

- Running an operator-triggered live observer workflow against local Galeed traces.
- Running scheduled observer reports through a native Linux systemd user timer, or manually through `workflows/live_observer_scheduled.sh`.
- Reviewing repeated live-observer findings through `index.md` and `index.json`.
- Drafting local issue files for repeated moderate-or-higher findings, without mutating GitHub.
- Previewing exact `gh issue create` commands before explicitly publishing drafts.
- Producing durable report artifacts from Hoglah queue traces.
- Detecting queue-vigilance load, long-running queue lifecycles, repeated observation clusters, runtime errors, missing evidence, unsupported outputs, and explicit Cairn observation tags.
- Using exact git pins for fresh-machine installs while local releases/tags catch up.

## Still Later, Not Blocking This Path

- Release tags and changelogs across every sibling repo.
- A dashboard over repeated Cairn findings.
- Automatic issue creation from high-confidence repeated findings.
- Wider end-to-end UI observation with Playwright or browser-control agents.
