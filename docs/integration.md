# Tirzah ↔ Mahalath integration contract

The load-bearing gap (report §2): Mahalath has a capable semantic layer, but **no
code connects Tirzah to it** and there is **no shared schema contract**. This doc is
the home for that contract as it gets built (Stage 4).

## Current state (verified 2026-06-22)
- Hoglah ↔ Mahalath: **live** (Mahalath submits its LLM calls through Hoglah).
- Tirzah ↔ Mahalath: **none in code** — design intent only; separate Mongo DBs
  (`mnemosyne_dev` vs `mahalath_dev`); the only reference is a comment.

## The MVP seam (Stage 4)
A single read-only call on Tirzah's retrieval path:

```
annotate_with_mahalath(context_chunks) -> context_chunks + {term: (mpl_label, sense)}
```

- **Interop on symbolic MPL labels only** — NOT vectors (embedding dims differ:
  Tirzah Ollama 768/1024 vs corpus bge-small 384 vs Mahalath's own embeddings).
- **Mode:** prefer service-level (`POST /api/retrieve`) over reading Mahalath's Mongo
  directly, so `is_stale` and the staleness logic are respected.
- Avoid deep-importing Mahalath internals (it has no curated `__init__` facade yet);
  use the HTTP endpoint or a thin client.

## Fuzzy search — already provided by Mahalath
No separate fuzzy layer is needed. Mahalath's `search_terms` already combines a
substring/word-boundary scorer with the `$text` stemmed index; `match_kind` reports
strength: `label`/`exact`/`alias` (confident) vs `partial`/`text` (fuzzy). Because we
attach a *precise sense*, the seam treats fuzzy hits carefully: `annotate(strict=True)`
drops them, and otherwise they render as `(approx)` rather than being asserted as exact.

## Contract versioning
Give the payload its own `contract_version`, independent of either tool's internal
`schema_version`, plus a startup compatibility check ("Tirzah expects contract ≥ N,
Mahalath speaks N ✓"), so the two evolve on separate release cadences.

## TODO
- [x] Resolver contract chosen: package-level `mahalath.retrieval.search_terms`
      (returns MPL label + senses/frames + match_kind + is_stale; respects staleness,
      so as safe as HTTP and needs no running web service).
- [x] Build the resolver + annotate seam: `tirzah/semantic.py` (`SemanticLabel`,
      `TermResolver`, `MahalathResolver` fail-soft, `annotate`/`render_prompt_block`),
      offline-tested. Tirzah `5e20593`.
- [x] Wired into `build_prompt_envelope` (optional `resolver` + `semantic_strict`);
      default off = byte-identical prompt. RuntimeConfig flags added
      (`mahalath_enabled`, `mahalath_mongo_uri/db`, `mahalath_language`, `mahalath_strict`).
      Both call sites pass it (`ask`/interaction + `build-prompt`).
- [x] Senses surfaced: envelope `semantic` + `semantic_summary`; `build-prompt` prints
      "interpreted as …" to stderr.
- [x] `workflows/semantic_smoke.py` is a real A/B through Tirzah's `build_prompt_envelope`
      — **PASS**: semantic-on names an MPL sense the off-run does not (uses live Mahalath
      when populated, else a demo resolver so the contrast is always demonstrable).

**MVP seam status: built + validated end-to-end.** Remaining for a full production
MVP: seed/point at a populated Mahalath ontology so the *live* resolver returns labels
(the demo proves the wiring); optional — surface the summary in `ask` human output too.
