# Should Tirzah support software coding? — a decision memo

**Date:** 2026-07-06 · **Status:** recommendation, not yet acted on · **Scope:**
whether to expand Tirzah to support software-coding work, clone it, or build a
separate product.

## Question

Can Tirzah be usefully expanded to support software coding, or would a clone or
a different product work better?

## What Tirzah actually is (architecturally)

Tirzah is a **graph-memory and retrieval engine with an interpretive planner** —
not an execution agent. Three facts from the code decide this question:

1. **The planner proposes; it does not execute.** `planning/recursive.py`: *"The
   planner proposes and revises process state. Python validates structure, owns
   [side effects]."* The LLM only shapes a Cairn plan; a fixed Python registry
   runs it.
2. **The executor's whole tool surface is knowledge-oriented.** Every handler in
   `planning/executor.py` is read-over-memory or answer: `answer_adapter`,
   `search_nodes`, `compile_context`, `web_search`/`web_fetch`,
   `get_node_context`, `get_graph_edges`, `expand_proximity`,
   `expand_graph_paths`, `semantic_candidates`, `list/get_document(_tree)`,
   `tirzah_retrieval`, and Milcah specialists. There is **no** file-edit, shell,
   patch-apply, or test-run capability anywhere in `src/tirzah` (the only
   `subprocess` use is the LLM adapter shelling out to Ollama/Hoglah).
3. **Its ontology is conversational knowledge, not code.** Nodes/edges/documents/
   semantic labels and `source_root`/`source_section`/`source_chunk` chunks
   (`ingest_source_path`). The "side effects" the executor owns are *writing to
   its own graph memory and emitting an answer* — nothing outside itself.

So Tirzah's model is: **ingest knowledge → retrieve over a graph → reason → answer**,
with a deliberately side-effect-free planner.

## What "coding support" actually requires

A coding agent needs an execution surface Tirzah does not have and was designed
not to have:

- **Repository mutation** — read/edit/create files, apply diffs/patches.
- **Command execution in a sandbox** — run builds, tests, linters; capture and
  react to output; iterate (the edit→run→observe loop).
- **A code-aware memory model** — files, symbols, ASTs, call graphs, blame/diff
  history — not conversational nodes.
- **Safety machinery** — sandboxing, approval gates, rollback, because side
  effects are now destructive and outward-facing.

Grafting these onto Tirzah would invert its core contract (planner *executes*
side effects), replace its ontology, and duplicate mature tools. It would dilute
what Tirzah is good at.

## The landscape (already on this machine)

- **`~/domains/codex`** — OpenAI **Codex CLI**: a mature local coding agent
  (Rust core, `apply_patch`, sandboxed shell). A ready execution engine.
- **`~/domains/AI-development-team`** (olehsvyrydov) — a portable **agent-team +
  enforced-workflow** framework for editors ("process, not prompts": roles,
  gates, `workflow.yaml`). Demonstrates the process layer over a coding agent —
  and overlaps heavily with what a family coding product would otherwise build.
- **Our family primitives** — Cairn (process/plan language + enforcement),
  Hoglah (LLM execution queue), Milcah (multi-LLM review/pressure-test), Galeed
  + Mizpah (trace spine + browser), Keturah (capability manifests), and
  **Tirzah (graph memory)**.

Coding agents are a crowded, fast-moving space with strong local options. We
have little edge in re-building the *agent*; we have real assets in *process*,
*review*, *trace*, and *memory*.

## Options

| Option | Verdict |
|---|---|
| **Expand Tirzah into a coding agent** | ✗ Inverts its planner contract, replaces its ontology, duplicates mature tools. Rejected. |
| **Clone Tirzah and mutate the clone** | ✗ A clone still starts from a knowledge-retrieval ontology + side-effect-free executor — wrong foundation for code mutation. Rejected. |
| **A thin new sibling that orchestrates an existing engine** | ✓ Reuses the family's real strengths; treats the coding *agent* as a swappable engine. Recommended. |

## Recommendation

**Do not expand or clone Tirzah. Build a thin new sibling** (a coding-workflow
orchestrator) that:

- **Delegates execution** to an existing coding engine (Codex CLI is already
  local; Claude Code is another target) rather than re-implementing edit/run/
  sandbox.
- **Wraps it in family process + review + trace**: Cairn authors and enforces
  the coding process (right-sized gates — cf. AI-development-team's presets),
  Milcah pressure-tests designs and reviews diffs, Galeed/Mizpah trace every
  step.
- **Uses Tirzah as the project-memory backend** — this is Tirzah's genuine,
  reusable role in coding. Its `ingest_source_path` + graph retrieval already
  turn a repo's docs, decisions, ADRs, and past fixes into queryable memory the
  coding engine consults ("what did we decide about X?", "how was this handled
  before?"). That is expansion *of Tirzah's memory reach into code artifacts* —
  not turning Tirzah into the agent.

In one line: **Tirzah becomes the memory the coding agent asks; it does not
become the coding agent.**

## If pursued — concrete first steps

1. **Spike**: drive Codex CLI from a Cairn process for one real change, tracing
   through Galeed; confirm the seam.
2. **Tirzah code-memory path**: a thin "ingest a repo's knowledge (docs/ADRs/
   decisions) → retrieve" surface, reusing `ingest_source_path`; measure whether
   graph retrieval beats plain grep for "prior decisions/fixes".
3. **Milcah-as-reviewer**: feed a diff + intent to Milcah for a coherence/review
   pass; see if it adds signal over a single-model review.
4. Only then decide whether the orchestrator is worth standing up as a named
   sibling.

## Bottom line

Expanding Tirzah is the wrong move; a clone is the same wrong foundation. The
right shape is a **thin orchestrator over an existing coding engine**, with the
family supplying **process (Cairn), review (Milcah), trace (Galeed), and memory
(Tirzah)** — where Tirzah's contribution is *memory*, kept true to what it is.
