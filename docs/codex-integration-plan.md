# Integrating the Codex CLI with the family suite — plan

**Date:** 2026-07-06 · **Status:** planned, not yet started · **Companion to:**
[`tirzah-coding-evaluation.md`](tirzah-coding-evaluation.md) (which concluded:
don't turn Tirzah into a coding agent — orchestrate an existing engine and let
the family supply process, review, trace, and memory).

## Status (2026-07-06)

**Done & verified live on the dev box:**

- **Keturah stdio MCP server** — `keturah/mcp.py` `run_stdio_server` + `keturah-mcp`
  console script (JSON-RPC `initialize` / `tools/list` via
  `registry.to_mcp(namespaced=True)` / `tools/call` dispatch). Keturah 0.3.0.
- **Family-tool handlers wired** — `keturah.mcp` `main()` registers Tirzah's
  handlers (`tirzah.mcp_handlers.build_handlers`) alongside grok's semantic one.
  Tirzah 1.12.0 exposes **`tirzah.search_memory`** (graph-memory search) and
  **`tirzah.coherence_check`** (Milcah pressure-test), both declared in
  `tirzah.manifest` so they appear in `tools/list` *and* dispatch on `tools/call`.
  Confirmed end-to-end over stdio on the dev box.
- **Noa install scaffolding** — `render_mcp_server_config` writes
  `~/.codex/keturah-mcp.toml.example` (grok `ac0de89`).

Pins: tirzah 1.12.0, keturah 0.3.0 (Noa `versions.lock`).

## Next tasks — ready for pickup (codex)

Two concrete, self-contained pieces remain; the example config grok renders
already names both of their interfaces.

### Task A — `galeed-codex-hook` (the trace bridge) · repo: **Galeed**
- **Goal:** a console script that turns a Codex lifecycle hook into a Galeed
  event, so a coding run is browsable in Mizpah.
- **Interface (already referenced in the example config):**
  `galeed-codex-hook <EventName>` — event name in argv (`SessionStart`,
  `PreToolUse`, `PostToolUse`, `Stop`, …), the hook payload as JSON on **stdin**.
- **Do:** add `galeed-codex-hook = "galeed.codex_hook:main"` to Galeed's
  `[project.scripts]`; `main()` reads argv[1] + stdin JSON and emits via the
  existing spine: `Tracer(trace_id=<session/rollout id>, session_id="codex",
  source="codex").emit(f"codex.{event}", summary=…, **fields)`. Best-effort,
  never non-zero-exit into Codex.
- **Acceptance:** `echo '{"tool":"apply_patch"}' | galeed-codex-hook PostToolUse`
  creates a `codex.PostToolUse` Galeed event; a real `codex exec` run then shows
  as a trace in Mizpah.

### Task B — install `keturah-mcp` + activate the config · repo: **Noa**
- **Goal:** after `install.sh`, `keturah-mcp` is on PATH and Codex loads it (and,
  once Task A lands, the Galeed hooks).
- **Do:** (1) add an `install_keturah_app` in `install/lib.sh` mirroring
  `install_cairn_app`/`install_galeed_app` (pipx-install `keturah` so `keturah-mcp`
  is on PATH; wheelhouse resolves it), called from install.sh/upgrade.sh; (2)
  extend `render_mcp_server_config` to write/merge a real `~/.codex/config.toml`
  `[mcp_servers.keturah]` (not just `.example`), and uncomment the `[hooks]`
  block once `galeed-codex-hook` exists.
- **Acceptance:** on a fresh `install.sh`, `command -v keturah-mcp` succeeds and
  `codex exec "search family memory for X"` can call `tirzah.search_memory`;
  hook events reach Galeed.

### Task C — Phase 0 proof (after A+B)
Drive `codex exec --json` on one real change in a family repo; confirm the run
traces to Mizpah and the agent can pull memory / request a coherence check.
This closes Phase 0–2 of the plan.

## Locked decisions

1. **Direction — Codex drives.** Codex CLI is the coding execution engine (its
   mature edit→run→observe loop, sandbox, `apply_patch`). The family supplies
   the *surround*: **memory (Tirzah)**, **review (Milcah)**, **trace (Galeed →
   Mizpah)**, and **process (Cairn + AGENTS.md)**. An "our-orchestrator-drives-
   Codex-as-a-tool" inversion is possible later for tighter gate enforcement,
   but is out of scope for the MVP.
2. **The family MCP server lives in Keturah.** Keturah already owns the
   capability→MCP mapping (`registry.to_mcp`, `manifest.to_mcp_tool`); it becomes
   the one place that also *serves* those tools over MCP.

## Why this shape

Codex's cleanest extension points are **MCP** (it is an MCP client) and
**lifecycle hooks**. We already describe our capabilities in MCP shape but do not
serve them. So the integration is mostly *connective tissue*, not a new agent.

## Architecture

```
      AGENTS.md (project rules) + Cairn process (right-sized gates)
                        │ drives
  orchestrator ── codex exec --json --output-schema ──► edits/tests in workspace sandbox
       │                    │  ▲ calls (Codex = MCP client)
       │ review gate        │  └── Keturah MCP server ──► Tirzah (memory), Milcah (review), …
       ▼                    │ hooks (SessionStart/Pre/PostToolUse/Stop/…)
   Milcah                Galeed hook bridge ──► Galeed spine ──► Mizpah (browse the run)
```

Four seams:

- **Memory in** — Codex calls **Tirzah** via MCP ("what did we decide about X?",
  "how was this handled before?"), using the family's richer project memory
  rather than only Codex's own session store.
- **Review gate** — a Cairn process step calls **Milcah** to pressure-test a
  diff/design before it is accepted.
- **Trace out** — Codex **hooks** post events to **Galeed**; the whole run is
  browsable in **Mizpah**.
- **Instruction** — **AGENTS.md** carries project rules; a **Cairn** workflow
  supplies right-sized gates (the "process, not prompts" idea, cf. the
  third-party AI-development-team framework).

## Codex surfaces we rely on (grounded in `~/domains/codex`)

| Surface | Where | Use |
|---|---|---|
| `codex exec --json` | `codex-rs/exec/src/cli.rs` | headless run + streaming event JSON |
| `--output-schema FILE` | same | schema-constrained structured result to parse |
| `--sandbox workspace-write`, `--skip-git-repo-check`, `--commit/--base` | same | sandboxed edits + git integration |
| `mcp_servers` (stdio `command/args/env` **or** http `url`+`bearer_token_env_var`) | `config/src/mcp_edit.rs`, `mcp_types.rs` | register the Keturah MCP server so Codex can call family tools |
| lifecycle hooks: `SessionStart`, `PreToolUse`, `PostToolUse`, `PermissionRequest`, `PreCompact`/`PostCompact`, `UserPromptSubmit`, `SubagentStart/Stop`, `Stop` | `config/src/hook_config.rs` | run a handler per event → Galeed |
| `mcp-server` crate | `codex-rs/mcp-server` | (later) drive Codex *as* an MCP tool from our plans |
| `model_providers`/`base_url` | config | (optional, low priority) route Codex's model via a gateway |

## What we have vs. build

**Have:** Keturah manifests (`to_mcp`), Tirzah retrieval + `ingest_source_path`,
Milcah review, Galeed spine + Mizpah, Cairn engine, Hoglah queue.

**Build:**

1. **Keturah MCP server (the linchpin).** A stdio MCP server that serves
   Keturah-registered capabilities and executes them against the backing tool.
   Reusable beyond Codex (Claude Code, Cursor also consume MCP). First tools:
   Tirzah `search`/`retrieve`; then Milcah `review`. Keep the manifest as the
   single source of truth for tool schemas.
2. **Galeed hook bridge.** A small handler (`codex` hook → stdin JSON → Galeed
   event). Maps `SessionStart`/`Stop` to run boundaries and `Pre/PostToolUse` +
   `PermissionRequest` to tool spans.
3. **Thin orchestrator.** Runs a Cairn process whose CALL steps invoke
   `codex exec` (parsing `--output-schema`) and route a review step to Milcah.
   Lives as a new sibling or inside Hoglah; MVP can be a small runner.
4. **Noa wiring.** Install renders `~/.codex/config.toml` (mcp_servers → Keturah
   server; hooks → Galeed bridge) and drops an `AGENTS.md` template.

## Phased plan (each phase ends with a concrete proof)

- **Phase 0 — trace spike (small).** Run `codex exec --json` on one real change
  in a family repo; wire a single `PostToolUse` hook → Galeed. **Done when** the
  run shows as a trace in Mizpah.
- **Phase 1 — memory (the MCP seam).** Build the Keturah MCP server exposing
  Tirzah `search`/`retrieve` (stdio); register it in Codex config. **Done when**
  Codex pulls family memory mid-task and it appears in the trace.
- **Phase 2 — review gate.** Add Milcah `review` as an MCP tool and a Cairn
  "review gate" the orchestrator enforces around `codex exec` via
  `--output-schema`. **Done when** a diff is blocked/annotated by Milcah before
  acceptance.
- **Phase 3 — package.** Wrap as a sibling + Noa install wiring (config, hooks,
  AGENTS.md). **Done when** a fresh `install.sh` yields a Codex that already
  knows the family tools and traces to Mizpah.

## Risks / open questions

- **MCP server is the reusable asset** — build it well (Keturah-driven, schema
  from manifests); it also unlocks Claude Code / Cursor. Do not special-case it
  to Codex.
- **Codex is OpenAI-model-centric.** Routing its model through Hoglah/Ollama is
  a nice-to-have, not MVP; the family value is memory/review/trace/process, not
  the model.
- **Sandbox/approval.** Use Codex's `workspace-write` sandbox for routine edits;
  reserve Cairn gates for higher-risk steps to avoid gate fatigue.
- **Memory overlap.** Codex has its own `memories`/`agent-graph-store`; we expose
  Tirzah as *project* memory it queries, not a replacement for session memory.
- **Auth/secrets.** MCP HTTP transport supports `bearer_token_env_var`; prefer
  stdio locally to avoid managing tokens for the MVP.

## Not doing (now)

- Turning Tirzah into the agent (see the companion memo).
- Driving Codex as an MCP tool from our plans (revisit in a later phase).
- A bespoke sandbox — Codex's is sufficient.
