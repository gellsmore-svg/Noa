# Noa

[![CI](https://github.com/gellsmore-svg/Noa/actions/workflows/ci.yml/badge.svg)](https://github.com/gellsmore-svg/Noa/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/gellsmore-svg/Noa)](https://github.com/gellsmore-svg/Noa/releases)
[![License](https://img.shields.io/github/license/gellsmore-svg/Noa)](LICENSE)

**Noa installs, configures and runs the family's local AI tools together, as
one stable stack on your machine.** It pins released versions of each tool,
installs them away from any development checkout, starts the one stateful
service they share (MongoDB), and checks that the whole stack is healthy.

Noa orchestrates; it never vendors. It contains only compose, configuration,
scripts and docs, and all product code stays in the sibling repositories.

## What it runs

| Tool | Does |
|---|---|
| [Tirzah](https://github.com/gellsmore-svg/tirzah) | Graph memory and retrieval |
| [Mahalath](https://github.com/gellsmore-svg/mahalath) | Ontology building and semantic precision |
| [Hoglah](https://github.com/gellsmore-svg/hoglah) | LLM job queue: every product submits model calls through it |
| [Milcah](https://github.com/gellsmore-svg/Milcah) | Coherence engine |
| [Deborah](https://github.com/gellsmore-svg/Deborah) and [Huldah](https://github.com/gellsmore-svg/Huldah) | Process language, and human-systems analysis |
| [Hanani](https://github.com/gellsmore-svg/Hanani) | Evidence synthesis |
| [Galeed](https://github.com/gellsmore-svg/galeed) | Trace and log spine |
| [Keturah](https://github.com/gellsmore-svg/keturah) | Capability manifest and MCP bridge |

The exact versions are in [`versions.git.lock`](versions.git.lock) (public git
refs, for a fresh machine) and [`versions.lock`](versions.lock) (local source
paths, for a development machine).

## Is it for you?

**Good fit:** you want the family stack running on Linux or WSL as a
dependable environment, with services, a worker and health checks, rather
than a set of dev checkouts.

**Not a fit:** developing one of the tools (use that tool's repo), or native
Windows (an installer is under analysis, not yet built).

## Try it

You need Docker with the compose plugin, Ollama running on the host,
Python 3.11+, pipx, git and curl.

```bash
gh repo clone gellsmore-svg/Noa noa && cd noa
cp .env.example .env                                   # set OLLAMA_BASE_URL and MONGO_URI
VERSIONS_LOCK=versions.git.lock ./install/install.sh   # Mongo up, pinned tools installed, health checked
./health/healthcheck.sh                                # run it again any time
```

[docs/fresh-install.md](docs/fresh-install.md) walks through it step by step,
including running on a machine where port 27017 is already taken. To upgrade
after a lock bump, run `./install/upgrade.sh`, which backs up, reinstalls the
pinned versions, migrates and re-checks health, with rollback guidance.

## What you get

- **MongoDB** on `127.0.0.1:27017`, the only containerised service. Ollama
  stays on the host and is reached by URL.
- **A Hoglah worker** as a systemd user service on native Linux, which
  restarts automatically and survives logout. On WSL, or without systemd, it
  runs as a background process.
- **Configuration for each tool**, rendered from your `.env` at install time.
  An existing config file is never overwritten.
- **Optional web views:** Galeed's trace API on `:8785` (`galeed serve`;
  browse it with [Mizpah](https://github.com/gellsmore-svg/Mizpah)), Deborah's
  process views on `:8795` (`deborah-serve`) and Hanani's docs on `:8805`
  (`hanani docs serve`). For a terminal trace view, run
  `galeed trace --follow`.

## Workflows

| Script | Does |
|---|---|
| `workflows/ingest_document.sh <file>` | Mahalath extracts the document's terms, then Tirzah ingests it, so retrieval resolves against those terms |
| `workflows/semantic_smoke.py` | End-to-end proof that the Mahalath–Tirzah seam works |
| `workflows/codex_review_gate.py` | Runs `codex exec` behind the Deborah/Milcah acceptance gate |
| `workflows/live_observer.sh` | Turns Galeed traces into a Huldah observation report; on native Linux `install.sh` also schedules it as a timer |
| `workflows/live_observer_index.py`, `…_issue_drafts.py`, `…_publish_issues.py` | Index repeated findings, draft GitHub issues for them, and publish the drafts (dry run by default) |

Observer details: [docs/live-observer.md](docs/live-observer.md).

## Rules the stack follows

- **LLM calls go through Hoglah.** Direct Ollama adapters are standalone and
  development fallbacks only ([llm-access-policy.md](docs/llm-access-policy.md)).
- **Released versions only.** Noa pins and installs releases and never copies
  sibling code.

## More

- [Stack readiness and integration report](docs/STACK-READINESS-REPORT.md),
  the full plan, and [integration notes](docs/integration.md).
- Windows: the [installer analysis bundle](docs/windows-installer-bundle.md).
  The Linux installer remains the reference implementation.
- Maintaining the public repo: `scripts/public_readiness_check.sh` (run in
  CI) and [publication-readiness.md](docs/publication-readiness.md).
- [Discussions](https://github.com/gellsmore-svg/Noa/discussions) ·
  [CHANGELOG](CHANGELOG.md) · [CONTRIBUTING](CONTRIBUTING.md) ·
  [SECURITY](SECURITY.md) · Apache 2.0, see [LICENSE](LICENSE).

*Noa is one of the five daughters of Zelophehad: a peer among her sisters,
not a parent over them.*
