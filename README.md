# Noa — the runtime that holds the family together

[![CI](https://github.com/gellsmore-svg/Noa/actions/workflows/ci.yml/badge.svg)](https://github.com/gellsmore-svg/Noa/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/gellsmore-svg/Noa)](https://github.com/gellsmore-svg/Noa/releases)
[![License](https://img.shields.io/github/license/gellsmore-svg/Noa)](LICENSE)

Public discussion: [Noa v0.1.1 public baseline](https://github.com/gellsmore-svg/Noa/discussions/6)

**Noa** is the orchestration sibling for the local AI stack: **Mahalath** (semantic
precision), **Tirzah** (memory/retrieval), **Hoglah** (serialized LLM queue), and
later **Milcah** (coherence engine). It does **not** replace those projects — it
*installs, configures, and runs them together* as a stable, production-like local
environment, separate from any dev checkout or virtualenv.

> Named for the fifth daughter of Zelophehad (Mahlah→Mahalath, Noa, Hoglah, Milcah,
> Tirzah) — a peer among the siblings, not a parent over them.

## What's here
- `compose.yaml` — the one always-up stateful service: **MongoDB** (Ollama stays on
  the host, configured by URL; never containerised here).
- `.env.example` — the single place you configure the stack (Ollama URL, Mongo, queue
  dir, version pins). Copy to `.env`.
- `versions.lock` — the pinned versions of each sibling (local source paths).
  `versions.git.lock` pins the same versions to **public git refs** for a fresh
  machine that can't see the local repos: `VERSIONS_LOCK=versions.git.lock ./install/install.sh`.
- `docs/publication-readiness.md` — checklist and recommendation before changing
  Noa's GitHub visibility.
- `scripts/public_readiness_check.sh` — repeatable checks for public-facing
  hygiene before changing repository visibility.
- `CONTRIBUTING.md` and `SECURITY.md` — public collaboration and vulnerability
  reporting guidance.
- `install/` — `install.sh` (bring the stack up), `upgrade.sh` (backup → reinstall
  pinned → migrate → health, with rollback guidance), `lib.sh` (shared helpers).
- `services/hoglah-worker.service` — systemd **user** unit for the Hoglah worker.
  install.sh runs the worker as a durable systemd service on native Linux (auto-
  restart, survives logout via linger) and falls back to a background process on
  WSL / no-systemd.
- `health/healthcheck.sh` — is Ollama reachable? Mongo up? queue writable? CLIs present?
- `config/` — per-tool config templates, rendered from `.env`.
- `workflows/ingest_document.sh <file>` — **integrated ingestion**: Mahalath ingests
  + extracts the document's MPL terms first, then Tirzah ingests the same document, so
  retrieval resolves against those terms.
- `workflows/semantic_smoke.py` — the end-to-end seam proof (A/B; passes on live labels).
- `workflows/codex_review_gate.py` — wraps `codex exec --json --output-schema`
  with the Cairn/Milcah acceptance gate.
- `workflows/live_observer.sh` — exports Galeed trace events and produces a
  Cairn live-observation report plus agent-harness guidance for human-load,
  agent-effectiveness, HCI/cognitive-aesthetic follow-up, and runtime findings.
- `workflows/live_observer_scheduled.sh` — runs the live observer into a
  timestamped report folder; `install.sh` enables it as a systemd user timer on
  native Linux.
- `workflows/live_observer_index.py` — builds `index.md` / `index.json` over
  scheduled observer reports so repeated findings are visible.
- `workflows/live_observer_issue_drafts.py` — writes local GitHub-ready Markdown
  issue drafts for repeated, high-enough-risk findings.
- `workflows/live_observer_publish_issues.py` — dry-runs or explicitly publishes
  those drafts through the GitHub CLI.
- `docs/` — the **[readiness & integration report](docs/STACK-READINESS-REPORT.md)**
  (the full plan), plus runtime/change-management notes.
- `CHANGELOG.md` — public release history.

## Quick start (target state)
```bash
cp .env.example .env          # set OLLAMA_BASE_URL, MONGO_URI, …
./install/install.sh          # mongo up + pipx-install pinned tools + health
./health/healthcheck.sh       # confirm the stack is live (also run by install.sh)
```
Upgrades (after bumping `versions.lock`):
```bash
./install/upgrade.sh          # backup → reinstall pinned → migrate → health
```

## Status
**Public baseline:** `v0.1.9` is live at
[github.com/gellsmore-svg/Noa](https://github.com/gellsmore-svg/Noa). Public
CI passes for readiness checks, installer/workflow tests, and the Codex
review-gate workflow. GitHub Discussions are enabled for design/process
conversation that does not belong in bug reports.

The stack is Mahalath + Tirzah + Hoglah + Galeed + Keturah + Cairn + Milcah,
with Noa providing installation, configuration, health checks, and observer
workflows. The current reproducible fresh-machine lock is
[`versions.git.lock`](versions.git.lock).

## Hard rule
Noa **orchestrates, it does not vendor.** It pins *released* versions of the siblings
and installs them; it never copies their code. Contents stay limited to compose +
config templates + scripts + docs.

For public use, think of Noa as the runtime scaffold for the family stack: it
documents and automates how the sibling tools are installed, configured,
observed, and health-checked together. Product logic and library code remain in
the sibling repositories.

## LLM access
Products submit LLM inference **through Hoglah**; direct Ollama adapters are
standalone/dev fallbacks only. See [llm-access-policy.md](docs/llm-access-policy.md).

## Windows Support (in progress)

A native Windows installer is under analysis and development. See the
**Windows Installer Analysis Bundle** in `docs/`:

- [windows-installer-bundle.md](docs/windows-installer-bundle.md) (overview)
- [windows-installer-analysis.md](docs/windows-installer-analysis.md)
- [windows-service-options.md](docs/windows-service-options.md)
- [python-embedding-options.md](docs/python-embedding-options.md)
- [windows-config-and-selection.md](docs/windows-config-and-selection.md)

The goal is a selectable installer (repos other than Relational-Substrate) that
produces a working default local configuration on Windows 10/11. The Linux
bash path (`install/install.sh`) remains the primary reference implementation.

## License

[Apache License 2.0](LICENSE).
