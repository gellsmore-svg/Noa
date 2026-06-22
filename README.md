# Noa — the runtime that holds the family together

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
- `versions.lock` — the pinned, runtime-consumable versions of each sibling.
- `install/` — `install.sh` (bring the stack up), `upgrade.sh`/`uninstall.sh` (later).
- `health/healthcheck.sh` — is Ollama reachable? Mongo up? queue writable? CLIs present?
- `config/` — per-tool config templates, rendered from `.env`.
- `workflows/semantic_smoke.py` — the end-to-end MVP proof (needs the Tirzah→Mahalath
  seam from Stage 4; currently a stub).
- `docs/` — the **[readiness & integration report](docs/STACK-READINESS-REPORT.md)**
  (the full plan), plus runtime/change-management notes.

## Quick start (target state)
```bash
cp .env.example .env          # set OLLAMA_BASE_URL, MONGO_URI, …
docker compose up -d mongo    # the one persistent service
./install/install.sh          # pipx-install the pinned tools, render configs
./health/healthcheck.sh       # confirm the stack is live
```

## Status
**Early scaffold (2026-06-22).** Mahalath/Tirzah are Stage-2 stabilised (portable
Ollama config + env overrides). The minimum-viable stack is Mahalath + Tirzah +
Hoglah; Milcah is deferred. See the report's §6–§7 for what "done" means and the
staged plan to get there.

## Hard rule
Noa **orchestrates, it does not vendor.** It pins *released* versions of the siblings
and installs them; it never copies their code. Contents stay limited to compose +
config templates + scripts + docs.
