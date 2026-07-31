# Design: split Cairn, and rename to Deborah (core) + Huldah (analysis)

**Date:** 2026-07-09 · **Status: EXECUTED 2026-07-31.** Shipped as
[Deborah](https://github.com/gellsmore-svg/Deborah) `v0.9.0` (the Cairn repo,
renamed — history preserved), [Huldah](https://github.com/gellsmore-svg/Huldah)
`v0.1.0`, and the [cairn-lang](https://github.com/gellsmore-svg/cairn-lang)
`v0.9.0` compatibility shim.

> **Three corrections this document needed, found during execution:**
>
> 1. **`web.py`** — the doc suspected two web surfaces. There is one; it imports
>    only `render` and is the core view composer, so it stayed in Deborah.
> 2. **`manifest.py`** — absent from the module lists below, but it *fused both
>    products*: 11 capabilities, 6 of them analysis. Split so each package
>    advertises only what it can execute.
> 3. **Extras** — docx/pdf were assigned to Huldah, but the exporters live in
>    Deborah's `render/export.py`. Deborah keeps `[export]`; `huldah[export]`
>    defers to it.
>
> Also: "cross-family ripple (the real cost)" overstated the code coupling.
> There is exactly **one** Python import of cairn estate-wide, in a Tirzah test
> (since migrated). The real ripple is Noa's shell and config, still pending.
>
> **The language keeps the Cairn name.** `.cairn.md` sources and ```cairn fences
> are unchanged and the grammar is byte-identical to v0.8.2 — the rename fixed a
> crowded namespace, not the language. Console scripts are deliberately *not*
> shimmed: they run from shell and CI, where a silent alias hides the migration.
>
> **Noa is not yet migrated and does not need to be urgently** — its
> `cairn-lang @ git+.../Cairn.git@v0.8.2` pin still resolves through GitHub's
> redirect to the unchanged pre-split tag. Verified.

## Summary

Cairn is two products in one package. Split them, and take the opportunity to
rename off the crowded `cairn` namespace into the family's biblical convention:

- **Deborah** — the **process language** (spec, grammar, conformance, render).
  *Deborah was a judge:* judgment, governance, decisions, conformance.
- **Huldah** — the **human-systems analysis product** (human-factors, UX/UI
  evidence, layout, live observation, interface recommendations, agent harness,
  LLM provider wrappers). *Huldah was a prophetess who interpreted and
  authenticated a text:* interpretation of signals/evidence.

The working decision is to keep the mapping above unless a later naming review
finds a concrete conflict.

## Why now

1. **Two products, one package.** Core ≈ 2.5k LOC (dependency-free spec/grammar/
   conformance/render). Analysis ≈ 4k LOC, **14 of 17 console scripts**, LLM
   provider wrappers (OpenAI/Claude/Gemini/Grok), and fastapi/docx/pdf extras.
   Different users, different cadence, different dependency profile.
2. **The seam is already clean** (verified): `grammar/`, `render/`,
   `conformance.py` import **nothing** from the analysis layer; the analysis
   layer imports the core one-way. The *only* thing fusing them is
   `cairn/__init__.py` (23 eager imports of analysis modules into the top level).
3. **The name is a liability.** `cairn` is the only non-biblical name in the
   family; GitHub has ~100 `cairn` repos; PyPI `cairn` is an unrelated project
   (we already ship as `cairn-lang` to dodge it). Renaming during the split
   fixes discoverability and family consistency in one move.

## Target state

### `deborah` (was Cairn core)
- Modules: `conformance.py`, `grammar/`, `render/`.
- Console scripts: `deborah-render`, `deborah-validate`, `deborah-serve`.
- Extras: `[render]` (pyyaml), `[web]` (fastapi/uvicorn) — for the view composer.
- Docs: SPEC.md, GRAMMAR.md, examples. Dependency-free by default.
- Distribution `deborah`; import `deborah`.

### `huldah` (new — the analysis product)
- Modules: `human_factors`, `ui_evidence`, `ui_scenarios`, `layout_load`,
  `interface_recommendations`, `live_observer`, `system_discovery`, `reporting`,
  `agent_harness`, `observation_contract`, `galeed_adapter`, `llm_wrappers`,
  `llm_adapters`, and the analysis `web` UI if applicable.
- Console scripts: the 14 `cairn-ui-*` / `cairn-human-factors` /
  `cairn-live-observe` / `cairn-system-discover` / `cairn-layout-load` /
  `cairn-recommend-interface-changes` / `cairn-generate-report` /
  `cairn-agent-harness-plan` / `cairn-galeed-observe` → `huldah-*`.
- Depends on `deborah>=<v>`; owns the LLM/web/docx/pdf extras.
- Distribution + import `huldah`.

### Boundary calls to confirm per-module
- `web.py`: is it the **core view-composer** (`cairn-serve`) → Deborah, or an
  analysis UI → Huldah? (Likely there are two; keep the composer in Deborah.)
- `galeed_adapter` / `observation_contract`: analysis-side (Huldah), since they
  bridge observations, not the language.

## Cross-family ripple (the real cost)

`cairn` is consumed beyond its own repo. Renaming the import touches:

| Consumer | What references `cairn` | Change |
|---|---|---|
| **Tirzah** | `cairn.validate_plan`, `parse_document`, `document_to_plan`; planner tested against conformance; `cairn-lang` dep | → `deborah.*`; dep bump |
| **Keturah** | `_SIBLING_PACKAGES` includes `cairn`; MCP `tools/list` exposes `cairn.parse_document`/`render_plan`/`validate_*` | → `deborah`; MCP tool namespace `cairn.*` → `deborah.*` |
| **Noa** | `versions.lock` pins `cairn-lang`; `install_cairn_app` (cairn-serve); wheelhouse `FAMILY_LIBS` | → `deborah` (+ add `huldah`); `install_deborah_app` |
| **Galeed/Mizpah** | any `cairn.*` trace/tool names | rename references |

**Mitigation — a compat shim for one deprecation cycle:** ship a thin `cairn`
package whose modules re-export from `deborah` (and the moved analysis names from
`huldah`) with a `DeprecationWarning`. Nothing downstream breaks on day one; the
family repos migrate imports over 1–2 cycles; drop the shim next minor.

## Migration plan (phased; each phase ships green)

1. **Scaffold `huldah`** (new repo/package), depending on `deborah` (still named
   cairn-lang at this point). `pip install -e`, CI green with moved tests.
2. **`git mv` the analysis modules + tests + CLIs into `huldah`**, re-point their
   internal imports (`cairn.human_factors` → `huldah.human_factors`; keep
   `cairn.grammar`/`render` imports until step 4). Redistribute analysis extras
   and the 14 scripts to `huldah/pyproject`.
3. **Slim `cairn/__init__.py`** to export only the core; verify the core repo is
   dependency-free again and its 3 scripts remain.
4. **Rename the core `cairn` → `deborah`** (repo, distribution, import). Add the
   `cairn` compat shim (re-exports + DeprecationWarning). Update SPEC/GRAMMAR/OKF.
5. **Migrate family consumers** (Tirzah, Keturah MCP, Noa lock/install, Galeed)
   to `deborah`/`huldah` imports and pins; keep the shim until they're all moved.
6. **Drop the compat shim** and the `cairn-lang` alias next minor.

## Effort & risk

- **Effort:** ~2 focused sessions for steps 1–4 (mostly mechanical relocation +
  import re-pointing); step 5 (family migration) is spread across the normal
  per-repo cadence behind the shim.
- **Risk:** low *architecturally* (clean one-way seam), **medium
  operationally** because grok/codex are actively developing Cairn — a big
  module move must land as **one atomic PR at a lull** to avoid brutal conflicts,
  or be sequenced with them.
- **Payoff:** `deborah` becomes a lean, dependency-free process language (its
  stated identity, minus the crowded name); `huldah` gets room to grow its
  LLM/UX/observation surface without bloating the language contract.

## Execution Checklist

Before any module move:

- Tag the current integrated Cairn state. Done: `v0.8.1`.
- Keep Noa pinned to the tagged integrated state until Deborah/Huldah have their
  own public tags. Done: `versions.git.lock` uses `cairn-lang@v0.8.1`.
- Create the Huldah repository/package scaffold with Apache License 2.0,
  `pyproject.toml`, CI, README, and compatibility notes.
- Create the Deborah repository/package scaffold or rename Cairn only after the
  analysis extraction is green.
- Add a `cairn` compatibility package for one deprecation cycle.
- Open tracking issues in Cairn/Deborah/Huldah for each migration phase.
- Update Noa only after both new packages have public tags and green CI.

## Open Decisions

1. `web.py` split: composer stays in Deborah; any analysis dashboard goes to
   Huldah.
2. Compatibility duration: default one minor cycle after all family consumers
   migrate.
3. Timing / executor: choose a low-conflict window because Cairn has active
   concurrent work.
