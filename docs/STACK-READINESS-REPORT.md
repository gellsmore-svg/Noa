# Semantic AI Stack — Readiness, Integration & Runtime Plan
**MAHALATH · TIRZAH · HOGLAH · MILCAH**
Date: 2026-06-22 · Method: code inspection at each repo's `main` HEAD (pyproject, README, config, models, web routes, cross-references, test layout). Verified claims carry file:line; inferences and open questions are marked.

---

## Executive summary
- **Hoglah is production-ready now** and is the dependency root (clean `pydantic-settings`, portable paths, validates its own packaged install).
- **Mahalath and Tirzah are "mostly ready"** — each blocked only by a small number of *config defaults* (a hardcoded WSL `ollama.exe` path in both; Mahalath also reads `/etc/resolv.conf` and has a `1.1.0` vs `0.0.1` version mismatch). None are structural.
- **Milcah is intentionally pre-production** (no persistence yet, can't run standalone) — defer it to a later opt-in.
- **The one real integration gap is Tirzah → Mahalath.** Hoglah↔Mahalath is *already live*; Tirzah↔Mahalath is **design intent with zero implementing code** and **no shared schema contract**. That gap — not any missing capability in Mahalath — is what stands between you and "semantic precision actually used."
- **Recommended runtime: Hybrid** — MongoDB in Docker Compose, Ollama on the host (configured by URL), the CLIs + Hoglah worker via pipx, one shared `~/ai-stack/` config+queue dir.
- **Recommended meta-repo: yes — `Noa`** (the unclaimed fifth daughter of Zelophehad), kept thin (orchestration + config + docs; pins released versions, never vendors code).
- **MVP = Mahalath + Tirzah + Hoglah + exactly one new read-only seam** (Tirzah retrieval → Mahalath label resolution), proven done by an A/B run where semantic-on visibly disambiguates and names the MPL sense the off-run misses.

---

## 1. Repository Readiness Assessment

| Repo | Version | Rating | One-line reason |
|---|---|---|---|
| **Hoglah** | 0.7.0 | ✅ Ready now | Clean settings, portable paths, validates its own packaged install |
| **Tirzah** | 1.2.0 | 🟡 Mostly ready | Hardcoded `ollama.exe` default + cwd-relative `config.yaml` |
| **Mahalath** | 1.1.0* | 🟡 Mostly ready | Version mismatch + hardcoded `ollama.exe` + `/etc/resolv.conf` WSL hack |
| **Milcah** | 0.2.0 | 🟠 Not ready (by design) | Pre-prod, no persistence, can't run standalone |

### Hoglah — Ready now (the foundation)
- v0.7.0 Alpha; only hard runtime dep is Ollama (HTTP `localhost:11434`); queue/store works standalone. CLI `hoglah` (needs `[cli]` extra for `typer`).
- **Config (best of the four):** `pydantic-settings` `BaseSettings` (env-var support), `~/.hoglah/hoglah.db` via `expanduser()`, no laptop-specific abs paths in runtime `src/`.
- **Tests:** 7 files, 6 with real integration signals gated by `RUN_OLLAMA_TESTS`; includes `test_packaged_install.py` — actually validates a packaged install.

### Tirzah — Mostly ready
- v1.2.0 (classifier still "Pre-Alpha"); largest codebase (115 py / 33 test files). **Only repo with Docker** (`Dockerfile` + `docker-compose.yml`).
- Needs MongoDB (`mnemosyne_dev`) + Ollama. Config is `config.yaml` with a **cwd-relative default** (`load_config(path="config.yaml")`).
- **Verified blocker:** `config.py:48` hardcodes `ollama_executable = /mnt/c/Users/cello/AppData/Local/Programs/Ollama/ollama.exe` (a pydantic default → overridable; primary `ollama_base_url` is portable `http://localhost:11434`).
- **Tests:** mostly hermetic (22/33 use fakes/fixtures, 3 touch live services).

### Mahalath — Mostly ready (two portability hazards)
- **Version mismatch:** `pyproject` = `1.1.0`, `__init__.__version__` = `0.0.1`. 73 py / 33 test files.
- Needs MongoDB (`mahalath_dev`) + Ollama. Exposes a Python package, `mahalath` CLI, and an optional FastAPI service (`[web]` extra).
- **Verified hazards:** `config.py:88` hardcodes the same WSL `ollama.exe`; `adapters/factory.py:33` reads `/etc/resolv.conf` (WSL→Windows-host networking hack). Both assume your specific WSL setup.
- **Tests:** strongly hermetic (12 fixtures, 1 live signal across 33 files).

### Milcah — Not ready (intended)
- v0.2.0; functionally rich after recent work (FR1–FR7, FR9, FR11), but pre-production. **Cleanest code hygiene** (zero hardcoded paths, zero env coupling, fully hermetic tests — 12 files, all LLM seams injected).
- Every real analysis needs a live Hoglah daemon + Ollama; **FR10 persistence unbuilt**, so nothing is durable. Borrows Hoglah's config; can't stand alone.

**Cross-cutting fresh-laptop blocker:** the shared `/mnt/c/Users/cello/.../ollama.exe` default in Tirzah + Mahalath, plus Mahalath's `/etc/resolv.conf` read, encode your current WSL machine. Not structural — config defaults — but the first things to break on a clean install.

---

## 2. Semantic Integration Assessment

### Mahalath's semantic interface — usable on three surfaces (verified)
- **Python package / module:** `labels.parse` / `is_valid` / `MplLabel` (hierarchical MPL label grammar w/ depth/parent/variant numbering); `mappings.resolve_mapping` / `compare_illocution` / `attribute_mapping` / `generate_mappings`; `glossary.export_json` / `export_markdown`.
- **CLI:** `mahalath`.
- **Service:** FastAPI app (`[web]` extra) with real routes incl. **`POST /api/retrieve`**, `POST /api/propose_term`, `GET /ontology/{mpl_label}`, `POST /api/chat`.
- **Caveat:** `mahalath/__init__.py` has **no `__all__` / no re-exports** — no curated facade; consumers must import internal module paths.

### Direct answers (verified from code)
- **Does Mahalath expose a clean API/CLI/package/service?** — Yes (all four), modulo the missing top-level facade.
- **Can Tirzah call Mahalath today during retrieval/memory?** — **No.** No `import mahalath` in Tirzah `src/`; separate Mongo DBs (`mnemosyne_dev` vs `mahalath_dev`); the only source reference is a *comment* in `adapters/hoglah_runtime.py`. All other references are design docs.
- **Can Hoglah orchestrate Mahalath's LLM calls?** — **Yes, already does.** `mahalath/adapters/hoglah.py` is a pure Hoglah submitter: every `generate()`/`embed()` is queued; a separate `hoglah run` daemon executes against Ollama (poll/callback). The one cross-project integration that is live.
- **Shared semantic schema?** — A rigorous schema **exists** (`db/models.py`) but is **Mahalath-private**; no shared/published contract Tirzah also imports. *This is the central gap.*
- **Reusable format?** — Yes: Mongo collections (`ontology_entries`, `mappings`, `definition_contexts`, `entry_embeddings`) + `export_json`/`export_markdown`.
- **Versioned?** — Yes, well: `schema_version: int = 1` on every record ("migrations bump this"); `DefinitionVersion`; staleness via `is_stale` / `stale_reasons` / `mark_dependents_stale` / `mark_mappings_stale`.
- **Resolve / retrieve / compare / validate?** — All present: `labels.is_valid`/`parse`; `mappings.resolve_mapping`/`compare_illocution`/`attribute_mapping`/`parse_mapping_verdict`; repositories + `POST /api/retrieve`.

### What's missing before Tirzah can use Mahalath
1. **A shared schema contract** — the load-bearing gap (shared model package, or a documented stable JSON contract from `export_json` / `/api/retrieve`).
2. **An integration-mode decision:** data-level (read Mahalath's Mongo) vs service-level (call `/api/retrieve` / package). *Inference:* service-level is cleaner — raw-collection reads bypass `is_stale`.
3. **A curated public API** in Mahalath's `__init__` (or a thin client) so Tirzah doesn't bind to internal paths.
4. **Actual call sites** in Tirzah's retrieval/memory pipeline (none exist).
5. **Embedding alignment (verified concern):** Tirzah's Hoglah embeddings are Ollama-dim (768/1024); AMS corpus used bge-small (384); Mahalath keeps its own `entry_embeddings`. Cross-system *vector* comparison needs one shared embedding model — for MVP, interoperate on **symbolic MPL labels only**.

**Verdict:** the semantic substrate is more ready than expected; the gap is the absence of any Tirzah→Mahalath contract/call site, a bounded integration task — not structural work on Mahalath.

---

## 3. Production-Like Local Runtime Proposal

### Fixed constraints (verified)
1. **Ollama stays host-native** — owns the GPU + your already-pulled models; configured by URL/path. (Tirzah's compose already treats it as host via `host.docker.internal`.)
2. **One MongoDB** serves both DBs.
3. **Hoglah is the serialization point** — shares a SQLite queue + `output_dir`, concurrency=1; must reach host Ollama.
4. **The CLIs are invoked by hand** — must be on `PATH`.

### Option comparison (vs your priorities: reliability, easy fresh install, easy upgrades, separation from dev, low cognitive burden, usable now, no fragile venvs)
- **A — All-native (pipx/uv):** usable now, but shares your host Python / is the fragile-venv situation you're escaping (pipx mitigates tool isolation; native Mongo is fiddlier to install/upgrade/back up).
- **B — All Docker Compose:** strong isolation **except** can't contain Ollama (GPU passthrough in WSL is fragile), needs Dockerfiles in 3 repos that lack them, and puts the shared SQLite queue across a bind-mount (lock-contention risk). All the cost, still runs Ollama natively.
- **C — Hybrid:** Mongo containerised (the always-up stateful service); Ollama on host; CLIs + Hoglah worker via pipx/native; one shared config+queue dir.

### Recommendation: **Option C — Hybrid**
```
host: Ollama (:11434, GPU, models)              # external, configured by URL
  └─ docker compose (always-up):  mongo:8.0 (:27017)   [+ redis:7 later, optional]
  └─ pipx (on PATH):              mahalath, tirzah, (milcah later)
  └─ native background service:   hoglah worker → host Ollama, shared ~/ai-stack/hoglah queue
config root: ~/ai-stack/  (config.yaml per tool + .env; one OLLAMA_BASE_URL)
```
- Fresh install = `docker compose up -d mongo` + 3 × `pipx install`.
- Upgrades = image tag bump or `pipx upgrade`.
- Fully separated from any dev checkout/venv.
- **Optional later hardening:** switch Hoglah's transport from SQLite `store` to a **Redis broker** (already validated) and add one `redis:7` service — removes the shared-file queue entirely. Not MVP.

---

## 4. New Meta-Repository Proposal

### Recommendation: **Yes — create it; keep it thin.**
A real shared concern (compose, env templates, version pins, upgrade/backup scripts, health checks, the end-to-end workflow) has no home today — the only orchestration artifact lives *inside Tirzah*, which wrongly centres one sibling. **Hard rule:** it orchestrates and pins *released* versions; it never vendors tool code. Contents = compose + config templates + scripts + docs only.

### Name: **`Noa`** (recommended)
The projects are the five daughters of Zelophehad (Mahlah→**Mahalath**, **Hoglah**, **Milcah**, **Tirzah**); the fifth, **Noa(h)**, is unclaimed (verified: no such repo). Adopt it as the *orchestration sibling that holds the others together* — completes the set, stays a peer (consistent with the flat "all contributors equal" ethos). Alternative: `Zelophehad` (the father; thematically apt but implies hierarchy). Keep `ai-stack` only as the local directory name.

### Structure
```
noa/
├── README.md                  # fresh-laptop install; topology diagram
├── compose.yaml               # mongo:8.0 (+ redis:7 later). NOT ollama — external.
├── .env.example               # OLLAMA_BASE_URL, MONGO_URI, HOGLAH_QUEUE_DIR, version pins
├── versions.lock              # mahalath==…, tirzah==…, hoglah==…  (the pin contract)
├── install/  {install.sh, upgrade.sh, uninstall.sh}
├── config/   {mahalath.config.yaml, tirzah.config.yaml, hoglah.env}   # rendered from .env
├── services/ hoglah-worker.service        # native worker launcher / user unit
├── health/   healthcheck.sh               # ollama? mongo? queue writable? CLI --version?
├── workflows/semantic_smoke.py            # the MVP A/B end-to-end (Section 6)
├── backups/  backup.sh                    # mongodump both DBs + queue snapshot
└── docs/     {runtime.md, change-management.md, integration.md}
```
**Bonus it fixes:** `config/` templates render each tool's Ollama path from one `OLLAMA_BASE_URL` — the hardcoded `ollama.exe` defaults die here; a fresh laptop sets one variable.

**Guardrails:** pin-and-install only (never vendor/fork); MVP is just `compose.yaml` + `install.sh` + `.env.example` + `healthcheck.sh` + `semantic_smoke.py` — defer upgrade/backup/systemd.

---

## 5. Change Management / Release Management

**The firewall principle:** the runtime consumes **pinned released versions**, never `main`, never a `pip install -e` checkout. `versions.lock` is the seam between developing and running — dev proceeds freely; the install moves only when you bump a pin and run `upgrade.sh`.

- **Branches:** keep the current trunk model. `main` = always-releasable; short-lived feature branches only for risky changes; no long-lived "stable" branch (the pin is your stable channel).
- **Tagging:** SemVer `vX.Y.Z` per runtime-consumable release. Adopt **Hoglah's discipline** (11 tags) on the others. **First:** fix Mahalath's version mismatch.
- **Release notes:** one `CHANGELOG.md` per repo (Hoglah has one; Tirzah/Mahalath/Milcah don't).
- **Upgrade path (`upgrade.sh`):** backup → bump pins → `pipx upgrade` → migrate → healthcheck → on failure restore pins + backup.
- **Backup (`backup.sh`, pre-upgrade):** `mongodump` both DBs + Hoglah queue snapshot + copy `versions.lock`. The rollback point.
- **Config migration:** render from `.env`/templates; `install/upgrade` diff `.env` vs `.env.example`, warn on missing keys.
- **Semantic-schema migration (the important one):**
  - Mahalath has `SCHEMA_VERSION = 1` (good) but migrations are **scattered one-shot CLI flags** — consolidate into a numbered, idempotent `mahalath migrate` (`001_*.py`…) that bumps `schema_version`.
  - **Tirzah has no `schema_version`** — add it + the same pattern before real memory data accumulates.
  - Give the Tirzah↔Mahalath contract its own **`contract_version`** + a startup compatibility check, so the two evolve independently.

**Per-repo starting state (verified):** Hoglah 11 tags + CHANGELOG (the model); Tirzah 4 tags, no changelog, no schema_version; Mahalath 1 tag, no changelog, partial/ad-hoc migrations + version mismatch; Milcah 0 tags (defer until FR10).

---

## 6. Minimum Viable Usable Stack

**Stack:** Mahalath + Tirzah + Hoglah. **Milcah deferred.**

**The honest line:** *MVP-0* (runs today, no new code) leaves precision merely **stored** — it fails your "actually used" criterion. **MVP = MVP-1 = MVP-0 + one thin read-only seam** (Tirzah retrieval → Mahalath resolves retrieved terms to MPL labels/senses → those shape and annotate the output).

- **Must work:** one Mongo (two DBs); Ollama reachable; Hoglah worker serialising calls; Mahalath resolves term→MPL label+sense (via `/api/retrieve` or `resolve_mapping`); Tirzah store/retrieve; **the new seam** `annotate_with_mahalath(context_chunks)` (one call site, symbolic labels only).
- **Defer:** Milcah; write-back; cross-system vector/embedding alignment (symbolic only); shared model package / `contract_version` formalism; broker transports; migration tooling; extra UIs.
- **Smoke tests:** health (ollama/mongo/queue/CLI versions); Hoglah round-trip; Mahalath `is_valid`/`parse` + one live `resolve_mapping`; Tirzah store→retrieve; the integration A/B script.
- **End-to-end workflow + proof:**
  1. Input passage with an ambiguous key term → Tirzah ingest.
  2. Tirzah stores, retrieves context for a query.
  3. Tirzah → Mahalath: resolve key terms → MPL label + definition-context (sense).
  4. Hoglah serialises the answer call, conditioned on the sense-annotated context.
  5. Output = answer + "interpreted as …" naming the MPL senses used.
  - **Acceptance = an A/B run** (`--semantic on/off`): if identical, precision was only stored (fail); if `on` visibly disambiguates and names the sense, precision was **used** (pass). Bake into `semantic_smoke.py`.
- **Definition of done:** fresh-laptop install (compose + 3 pipx + Hoglah worker) → all smoke tests green → A/B shows semantic-on resolving senses the off-run misses.

---

## 7. Immediate Action Plan

*(Stages 3 and 5 are the same effort — the meta-repo is the packaging vehicle.)*

**Stage 1 — Audit** ✅ — *Done* (this report; verified blocker list).

**Stage 2 — Stabilise**
- Tasks: drive Tirzah+Mahalath off `OLLAMA_BASE_URL` (kill the `ollama.exe` defaults); gate/remove Mahalath's `/etc/resolv.conf` read; reconcile Mahalath version; make Tirzah `config.yaml` location explicit; verify clean wheel installs.
- Output: three tool releases that install on a machine that isn't yours.
- Risks: hidden WSL assumptions; embedding-dim mismatch if vectors wired early (keep symbolic).
- Done: `pipx install <wheel>` + `--version` succeed in a clean container; no `/mnt/c/...` or `/etc/resolv.conf` on default paths.

**Stage 3 — Package (= meta-repo MVP)**
- Tasks: 5-file `Noa` MVP — `compose.yaml` (mongo), `.env.example`, `install.sh`, `health/healthcheck.sh`, `workflows/semantic_smoke.py` stub.
- Output: `~/ai-stack/` comes up with `compose up -d mongo` + `install.sh`.
- Risks: SQLite-over-bind-mount (keep Hoglah worker native); config-template drift.
- Done: clean-machine `install.sh` → 4 health smoke tests green.

**Stage 4 — Integrate (the seam)**
- Tasks: `annotate_with_mahalath()` on Tirzah retrieval (one read-only Mahalath call, symbolic labels); surface senses in output; implement the A/B `semantic_smoke.py`; write `docs/integration.md` (+ `contract_version`).
- Output: working Tirzah→Mahalath link; A/B proof; contract doc.
- Risks: scope creep (no write-back / vectors in MVP); avoid deep-importing Mahalath internals (prefer HTTP/thin client).
- Done: `--semantic on` disambiguates + names the MPL sense the off-run misses. **(= MVP done.)**

**Stage 5 — Runtime Repo**
- Tasks: promote `~/ai-stack/` into the `Noa` repo (Section 4 layout); add `versions.lock`; confirm no vendored code.
- Output: `Noa` repo reproducing the stack from pins + scripts.
- Risks: drift / over-build.
- Done: a second clean machine reproduces the stack from `Noa` alone.

**Stage 6 — Change Control**
- Tasks: tags + changelogs on Tirzah/Mahalath; consolidate `mahalath migrate`; add Tirzah `schema_version`; build `upgrade.sh` + `backup.sh`.
- Output: SemVer + changelogs; numbered migrations where data persists; reversible upgrades.
- Risks: over-engineering; Tirzah migration arriving after data accumulates (do early).
- Done: pin bump + `upgrade.sh` → migrate → health pass → can roll back to backup.

**Critical path:** Stage 2 → Stage 3 → Stage 4. That reaches "usable now, precision actually used." 5–6 harden and sustain.

---

## 8. Questions Answered Directly

1. **Can MAHALATH, TIRZAH, HOGLAH be used now in a practical local runtime?**
   *Partially.* Each runs; Hoglah↔Mahalath is live. But used **together with precision flowing through** — no, not until the one Tirzah→Mahalath seam exists. Standalone-usable now; integrated-usable after Stage 4.

2. **If not, what exactly blocks that?** (verified)
   (a) No Tirzah→Mahalath code or shared schema contract. (b) Hardcoded WSL `ollama.exe` defaults in Tirzah + Mahalath. (c) Mahalath's `/etc/resolv.conf` read + version mismatch. (d) No packaging/orchestration layer (compose lives only inside Tirzah). None structural.

3. **Does MAHALATH need refinement before TIRZAH can use it semantically?**
   *Minor.* Capability is there (labels, resolve/compare, versioned store, `/api/retrieve`). Needs: a curated public API/`__all__` (or thin client) + a documented contract payload. No deep refactor.

4. **Does TIRZAH need refinement before it can consume MAHALATH?**
   *Yes — this is where most of the missing work is.* Add the retrieval-side seam + call site; surface resolved senses; later add `schema_version` for its own store. The integration code lives mostly on Tirzah's side.

5. **Does HOGLAH need refinement before it can orchestrate this reliably?**
   *No.* It already serialises Mahalath's calls live. Optional later: Redis-broker transport if the shared SQLite queue gets awkward with multiple submitters.

6. **Should MILCAH be included now or later?**
   *Later.* Pre-production, no persistence (FR10 unbuilt), can't run standalone. Design for integration; don't put it in the first install. Adding it later = one `versions.lock` pin + one config template.

7. **Should we create a new meta-repo?**
   *Yes* — recommended name **`Noa`**, kept thin (orchestration + config + docs; pins released versions, never vendors). It's the missing piece that makes the three usable together and the right home for the single Ollama config path.

8. **What is the first concrete implementation step?**
   **Stage 2, item 1:** make Tirzah and Mahalath read the Ollama endpoint from `OLLAMA_BASE_URL` and drop the hardcoded `/mnt/c/.../ollama.exe` defaults — the smallest change that makes a fresh-laptop install possible, and the prerequisite for everything downstream. (In parallel, scaffold the `Noa` MVP.)

---

### Fact / inference / open-question ledger
- **Verified (code):** all readiness ratings' blockers (file:line); Hoglah↔Mahalath live submitter integration; Tirzah↔Mahalath absence; Mahalath's label/mapping/export API, `schema_version`, FastAPI routes; per-repo tags/changelogs; hardcoded paths.
- **Inference:** service-level > data-level integration (preserves `is_stale`); Hybrid > native/Docker for your constraints; `Noa` naming fit; A/B as the "used vs stored" test.
- **Open questions:** exact shape of the shared schema contract; whether any Tirzah WSL assumptions exist beyond config (its 115-py surface wasn't exhaustively read); embedding-model unification if/when vector interop is wanted; whether to formalise a shared model package vs a JSON contract.
