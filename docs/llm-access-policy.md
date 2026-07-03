# LLM access policy — Hoglah is the family's inference path

**The rule (2026-07-03):** when the family runs as a stack, products submit LLM
inference (generation, chat, embeddings-as-jobs) **through Hoglah**. Direct
Ollama adapters (`ollama_cli`, `ollama_http`) remain supported as
**standalone/dev fallbacks only** — no new feature work should grow the direct
paths, and drift between them is accepted as their cost.

## Why one path

Hoglah exists to be the serialized, observable LLM queue (its README, sentence
one). Before this policy, three independent implementations of "talk to
Ollama" lived in the family — Tirzah's adapters, Mahalath's adapters, and
Hoglah itself — each with its own retries, timeouts, and model discovery.
Every product keeping a private side door undermines the queue's purpose:
serialization (one GPU, one line), unified retry/timeout behaviour, queue
visibility (`hoglah monitor` / `hoglah serve`), and — since Galeed emission
landed in Hoglah — job-lifecycle events on the family trace spine.

## How each product complies

- **Mahalath** — already live: `MAHALATH_MODEL_ADAPTER=hoglah` (or
  `runtime.model_adapter: hoglah` in config). The Noa stack sets this.
- **Tirzah** — route answer generation through the Hoglah runtime adapter
  (`tirzah/adapters/hoglah_runtime.py`). Direct `ollama_cli`/`ollama_http`
  answer adapters are the fallback for standalone use.
- **Milcah** — already compliant: LLM extraction/orchestration goes through
  `hoglah_extractor` (the `hoglah` extra); the `rule` extractor is
  deterministic and needs no LLM.
- **Mahlah / Mizpah** — front ends; they talk HTTP to Tirzah, never to Ollama.

## Scope notes

- **Tirzah's memory-profile policy is unchanged.** Tirzah deliberately blocks
  HTTP-backed adapters for ingestion/retrieval *profile* operations
  (`embedding_adapter_policy: ingestion_and_retrieval_no_http`); that is a
  stricter, Tirzah-internal rule about memory integrity, not an exception to
  this routing policy.
- **Model discovery** (listing installed models for UI dropdowns) may still
  query Ollama directly; it is metadata, not inference.
- Per the hard rule in the README, Noa documents and configures this policy;
  the code lives in the siblings.
