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

## Contract versioning
Give the payload its own `contract_version`, independent of either tool's internal
`schema_version`, plus a startup compatibility check ("Tirzah expects contract ≥ N,
Mahalath speaks N ✓"), so the two evolve on separate release cadences.

## TODO
- [ ] Document the exact `/api/retrieve` request/response payload as the v1 contract.
- [ ] Add `annotate_with_mahalath()` + a call site in Tirzah retrieval.
- [ ] Surface resolved senses in Tirzah output ("interpreted as …").
- [ ] Wire `workflows/semantic_smoke.py` A/B assertion.
