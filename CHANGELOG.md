# Changelog

## [Unreleased]

## [v0.1.18] - 2026-07-11

- Extended the public Keturah MCP smoke to ingest a Hanani article and execute
  `hanani.map_relations`, proving persisted relation output as well as tool
  discovery.

## [v0.1.17] - 2026-07-11

- Promoted the public Hanani lock to `0.8.0`, including Fable's
  `FR-ANALYSIS-01` semantic atom-relation mapping and its federated Keturah
  MCP tool.

## [v0.1.16] - 2026-07-11

- Extended the public `pipx` installer smoke test to verify Keturah's
  federated Tirzah and Hanani MCP tools after all runtime injections.

## [v0.1.15] - 2026-07-10

- Split public installation verification into its own parallel CI job, reducing
  the normal workflow-test feedback time while preserving both clean-install
  checks.

## [v0.1.14] - 2026-07-10

- Added a clean public `pipx` installer smoke test to CI, including the
  cross-tool Galeed, Tirzah, Hoglah, Milcah, and Hanani/Keturah injections.

## [v0.1.13] - 2026-07-10

- Added CI coverage that installs the entire `versions.git.lock` into a clean
  virtual environment and verifies family imports plus all public CLI entry
  points.

## [v0.1.12] - 2026-07-10

- Normalised public Git lock URLs to canonical `.git` references so pip resolves
  them as the same direct requirements declared by sibling packages.

## [v0.1.11] - 2026-07-10

- Promoted the fresh-machine lock to the independently verified public family
  releases: Tirzah `1.12.0`, Hoglah `0.9.0`, Hanani `0.7.0`, and Keturah
  `0.3.0`.
- The public runtime graph now uses explicit Git release dependencies rather
  than attempting to resolve internal family packages from PyPI.

## [v0.1.10] - 2026-07-10

- Added Hanani install health coverage and Keturah MCP injection for local
  Hanani pins.

## [v0.1.9] - 2026-07-10

- Added matching Cairn agent-harness links to live-observer issue drafts.
- Included the current local family lock update for Tirzah `1.12.0`, Keturah
  `0.3.0`, and Hanani `0.4.0`.

## [v0.1.8] - 2026-07-10

- Added matching Cairn agent-harness paths to the scheduled live-observer
  Markdown and JSON indexes.

## [v0.1.7] - 2026-07-10

- Added `cairn-agent-harness-plan` to the Noa health check so missing harness
  guidance support is visible before live-observer runs.

## [v0.1.6] - 2026-07-10

- Added a companion Cairn agent-harness plan to live-observer runs so each
  report carries consuming-agent guidance for deterministic Cairn tooling,
  HCI touchpoints, cognitive aesthetic, interface overhead, and
  probability/impact/confidence/evidence separation.

## [v0.1.5] - 2026-07-10

- Updated the Cairn pin to `cairn-lang@v0.8.2`, bringing consuming-agent prompts
  for HCI touchpoints, cognitive aesthetic, interface overhead, and
  probability/impact/confidence separation into fresh Noa installs.

## [v0.1.4] - 2026-07-10

- Updated integration documentation so completed Tirzah-Mahalath work is not
  presented as an open TODO.

## [v0.1.3] - 2026-07-10

- Added Dependabot checks for GitHub Actions workflow updates.

## [v0.1.2] - 2026-07-10

- Seeded the first public Discussions announcement for the `v0.1.1` baseline.
- Linked GitHub Discussions from the README and contribution guidance.

## [v0.1.1] - 2026-07-10

- Added README badges for CI, release, and license.
- Added public `CONTRIBUTING.md` and `SECURITY.md` guidance.
- Added GitHub issue templates for bug reports and feature requests, with
  privacy reminders for traces, prompts, generated reports, and `.env` values.
- Added a pull request template with boundary, privacy, and validation checks.
- Enabled GitHub Discussions for public design/process conversations.
- Replaced public commit pins with release tags across the sibling lockfile.
- Updated the public Cairn pin to `cairn-lang@v0.8.1`.
- Promoted the Cairn -> Deborah/Huldah split note to an approved pre-execution
  roadmap.

## [v0.1.0] - 2026-07-09

First public baseline for Noa, the runtime scaffold for the family AI stack.

- Made the repository public under Apache License 2.0.
- Added public-readiness checks for license presence, tracked generated/private
  files, personal path markers, stale private wording, and optional public
  git-ref reachability.
- Added CI coverage for public-readiness, installer/workflow tests, and the
  Codex review-gate workflow.
- Added a clean public `versions.git.lock` for fresh-machine installs.
- Published the `v0.1.0` GitHub release.
