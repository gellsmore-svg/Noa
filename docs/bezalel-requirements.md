# Bezalel — a self-extending reasoning engine · Requirements

**Doc:** REQ-BEZALEL-001 · **Version:** 0.1 · **Status:** proposed (pre-scaffold)
**Companions:** [`dynamic-orchestration.md`] (the architecture), [`tirzah-coding-evaluation.md`] (why not rebuild a coding agent), [`codex-integration-plan.md`].

> **Bezalel** (Exodus 31) — *"filled with skill to make all manner of workmanship."*
> A local-first reasoning engine whose distinguishing feature is **self-extension**:
> it can author, test, gate, and register **new manifested capabilities** for
> itself and the family. It is a *maker*, not a general coding agent (that is
> Codex + the family surround, per the evaluation memo).

## Purpose & scope

Bezalel is the family's **L0 substrate grown a set of world-touching hands**, plus
a mechanism to grow more. It exposes a small set of side-effecting primitives
(files, execution, network, models) and a self-extension loop, driven by the
family's *existing* bounded orchestration (Cairn plans + validation + gates +
Galeed trace + the outcomes loop). It is **in scope** to build the hands and the
registrar; it is **out of scope** to write a new agent loop or a new sandbox from
scratch where the family/Codex already provide one.

## THE INVARIANT (INV-1) — inviolable

> A model's output only ever becomes a **proposed Cairn step**. Nothing touches
> the filesystem, network, or package/model state except by executing a step
> that has passed `cairn.validate_plan` + the step's `allowed_tools` constraint +
> its governance gate, **inside the sandbox**, with the call **traced in Galeed**.

Every requirement below is subordinate to INV-1. Any change that lets model text
execute without passing this path is a defect, regardless of convenience.

## Guiding principles

- **Propose, don't dispose.** LLMs gain *say*, never *hands*; the deterministic
  substrate owns all side effects (family principle, unchanged).
- **Blast-radius classification is the safety model.** Every primitive is
  classified; classification — not trust in the model — decides what is gated.
- **Self-extension is append-only and human-gated.** Bezalel proposes new
  *tools*; it cannot silently mutate its own reasoning core.
- **Everything is observable.** No primitive runs without a Galeed event.
- **Reuse the family head.** Reasoning is Tirzah's interpretive planner; do not
  reimplement it.
- **Local-first.** Models via **Hoglah** (Ollama); no mandatory external service.

---

## Functional requirements

### FR-PRIM — Primitive substrate

Each primitive **shall** be a plain Python callable, exposed as a Keturah
capability + handler, and carry a declared **blast-radius class** ∈ {`pure`,
`read`, `workspace-write`, `execute`, `network`, `model`, `env-mutate`}.

#### FR-PRIM-01 Write file
Bezalel **shall** provide `write_file(path, content)` writing text/bytes to a
path **inside the workspace root** (FR-SANDBOX-01). Overwrite **shall** require
the path to already be workspace-jailed. Class: `workspace-write`.
**Acceptance:** writes within root succeed; a path escaping root (`..`, absolute
outside, symlink) is rejected with a clear error; event `bezalel.write` emitted.
**Status:** Planned (Phase 1).

#### FR-PRIM-02 Read file
`read_file(path)` **shall** return file contents from within the workspace root,
or from an explicit **read-allowlist** of paths outside it. Class: `read`.
**Acceptance:** in-root reads succeed; out-of-root reads succeed only if
allowlisted; otherwise rejected. **Status:** Planned (Phase 1).

#### FR-PRIM-03 Edit file
`edit_file(path, old, new)` **shall** perform an exact-match replacement (or
structured patch) within a workspace file, failing if `old` is absent or
non-unique. Class: `workspace-write`.
**Acceptance:** unique-match edit applies; ambiguous/absent match fails without
writing; event emitted. **Status:** Planned (Phase 1).

#### FR-PRIM-04 Run
`run(command, *, timeout, network=False)` **shall** execute a shell command or
script **inside the sandbox** (FR-SANDBOX-02) with a mandatory timeout and
resource caps, network **off** unless the step is explicitly `network`-tagged and
gated. Class: `execute`.
**Acceptance:** command runs jailed to the workspace; exceeds-timeout is killed
and reported; stdout/stderr/exit captured; network access blocked unless granted;
`bezalel.run` event carries the command + outcome. **Status:** Planned (Phase 2).

#### FR-PRIM-05 Browse
`browse(url, *, method="GET")` **shall** fetch a URL only if its host is on the
**network allowlist**; it returns status, headers, and body. Class: `network`.
**Acceptance:** allowlisted host succeeds; non-allowlisted host rejected before
any request; redirects re-checked against the allowlist; event emitted.
**Status:** Planned (Phase 5).

#### FR-PRIM-06 Parse HTML
`parse_html(html, selector=None)` **shall** extract text/structure from an HTML
string (no network of its own). Class: `pure`.
**Acceptance:** returns extracted content for a selector; tolerant of malformed
HTML; deterministic. **Status:** Planned (Phase 1).

#### FR-PRIM-07 Call model
`call_model(model, prompt, **params)` **shall** run inference **through Hoglah**
(the family Hoglah-first policy), never a raw Ollama socket, so every model call
is queued, traced, and captured. Class: `model`.
**Acceptance:** submits a Hoglah job and returns the completion; a missing worker
yields a clean error, not a hang; the call appears in Galeed `llm_calls`.
**Status:** Planned (Phase 1).

#### FR-PRIM-08 Install library (stretch)
`pip_install(spec)` **shall** install a **version-pinned** package into the
sandbox venv only, behind a mandatory governance gate (FR-GATE-02). Class:
`env-mutate`.
**Acceptance:** unpinned spec rejected; install occurs only after gate approval;
target is the sandbox venv, never the host; event records the exact resolved
version. **Status:** Planned (Phase 5, gated).

#### FR-PRIM-09 Download model (stretch)
`ollama_pull(model)` **shall** pull an Ollama model behind a mandatory gate, with
a pre-flight disk-space check and a pinned tag/digest. Class: `env-mutate`.
**Acceptance:** gate required; disk pre-check enforced; pinned reference recorded;
event emitted. **Status:** Planned (Phase 5, gated).

### FR-SANDBOX — Blast-radius containment

#### FR-SANDBOX-01 Workspace jail
All file primitives **shall** be confined to a configured **workspace root**;
path traversal, absolute escape, and symlink escape **shall** be rejected before
any I/O. **Acceptance:** a fuzz set of escape attempts all fail closed.
**Status:** Planned (Phase 1).

#### FR-SANDBOX-02 Execution sandbox
`run`/`pip_install`/`ollama_pull` **shall** execute inside an OS-level sandbox
(reusing `bwrap`/`linux-sandbox` where available, else a documented degraded
mode) with: workspace bind-mount only, network off by default, and CPU/memory/
wall-clock limits. **Acceptance:** a command cannot read `$HOME` outside the
workspace, cannot reach the network unless granted, and is killed at the resource
cap. **Status:** Planned (Phase 2).

#### FR-SANDBOX-03 Network allowlist
Network access (`browse`, granted `run`) **shall** be constrained to a
configured host allowlist; default empty. **Acceptance:** egress to a
non-allowlisted host fails closed. **Status:** Planned (Phase 5).

#### FR-SANDBOX-04 Degraded-mode disclosure
When a stronger sandbox is unavailable, Bezalel **shall** refuse `execute`/
`env-mutate` primitives unless explicitly run with `--allow-unsandboxed`, and
**shall** record that flag in every affected event. **Acceptance:** without the
flag, execute primitives are unavailable and say why. **Status:** Planned.

### FR-PLAN — Reasoning (reuse, not rebuild)

#### FR-PLAN-01 Cairn-planned execution
Bezalel **shall** drive work as a **Cairn plan** whose steps are Bezalel
primitives, executed by the family interpretive planner with `allowed_tools`
restricted to Bezalel's registered tools. It **shall not** implement a bespoke
agent loop. **Acceptance:** a goal produces a validated plan; steps naming a tool
outside `allowed_tools` are rejected. **Status:** Planned (Phase 3).

#### FR-PLAN-02 Validation gate on every step
No step **shall** execute unless the plan passes `cairn.validate_plan` and the
step's construct/tool is permitted. **Acceptance:** an invalid or
disallowed-construct plan never reaches a primitive (INV-1). **Status:** Planned.

#### FR-PLAN-03 Outcomes loop armed by default
Orchestrated Bezalel runs **shall** arm the outcomes-validation loop
(re-anchor + drift gate + block-complete-until-met) by default, given the raised
drift surface of dynamic tool use. **Acceptance:** a run that drifts from its
declared outcome is re-anchored and cannot silently self-declare complete.
**Status:** Planned (Phase 3).

### FR-EXT — Self-extension

#### FR-EXT-01 Author a capability
Bezalel **shall** be able to author a new tool as a module exposing a handler +
a Keturah capability declaration, written via `write_file` into a `tools/`
directory. **Acceptance:** the module imports cleanly and declares a conformant
capability. **Status:** Planned (Phase 4).

#### FR-EXT-02 Test before registration
A newly authored tool **shall** carry an authored smoke test that is run in the
sandbox; registration **shall not** proceed on a failing or missing test.
**Acceptance:** a tool whose smoke test fails is not offered for registration.
**Status:** Planned (Phase 4).

#### FR-EXT-03 Human-gated registration
A new tool **shall** join the live registry/manifest only after a human gate
(diff + test result presented), reusing the family gate machinery.
**Acceptance:** without gate approval, the tool is absent from `tools/list`;
after approval it appears next planning cycle. **Status:** Planned (Phase 4).

#### FR-EXT-04 No core self-mutation
Self-extension **shall** be **append-only over the tool set**; Bezalel **shall
not** be able to rewrite its own reasoning core, sandbox, or gate logic through a
primitive. **Acceptance:** attempts to `write_file`/`edit_file` the engine's
protected paths are rejected. **Status:** Planned (Phase 4).

### FR-GATE — Governance

#### FR-GATE-01 Class-based gating policy
A declarative policy **shall** map blast-radius classes to gate requirements
(default: `execute`, `network`, `env-mutate` require a gate; `pure`/`read`/
`model`/`workspace-write` do not). Policy is human-authored (Process Management
surface). **Acceptance:** changing the policy changes which steps pause, with no
code change. **Status:** Planned (Phase 3).

#### FR-GATE-02 Irreversible actions always gated
`pip_install` and `ollama_pull` **shall** be gated regardless of policy overrides
(environment mutation is not delegable to the model). **Acceptance:** no policy
setting can auto-approve FR-PRIM-08/09. **Status:** Planned.

#### FR-GATE-03 Optional Milcah review of proposed tools
Before an FR-EXT gate, the proposed tool **may** be routed to Milcah for a
coherence/safety review whose verdict is shown to the human. **Acceptance:** when
enabled, the gate presentation includes Milcah objections/confidence.
**Status:** Planned (Phase 4, optional).

### FR-TRACE — Observability

#### FR-TRACE-01 Every primitive emits an event
Each primitive invocation **shall** emit a Galeed event (`bezalel.<primitive>`)
with inputs (redacted as needed), outcome, and sandbox flags; browsable in
Mizpah. **Acceptance:** a run's full primitive sequence is reconstructable from
the trace. **Status:** Planned (Phase 1).

#### FR-TRACE-02 Acknowledgment semantics
When a specialist output (e.g. a Milcah objection) is produced, the loop
**shall** emit `signal.received` / `signal.incorporated` / `signal.dropped
{reason}` so it is auditable whether it changed anything. **Acceptance:** a
dropped high-severity objection is visible in the trace. **Status:** Planned
(Phase 3; shared with the orchestration plan).

### FR-FAMILY — Integration

#### FR-FAMILY-01 Keturah federation
Bezalel **shall** ship a `build_manifest()` so its capabilities appear in
`family_registry()` and the Keturah MCP `tools/list` (guarded, fail-soft).
**Acceptance:** with Bezalel installed, its tools appear in `tools/list`.
**Status:** Planned (Phase 1).

#### FR-FAMILY-02 Hoglah for all inference
All model calls **shall** route through Hoglah (FR-PRIM-07); Bezalel **shall not**
open a raw model socket. **Acceptance:** no direct Ollama HTTP in the codebase.
**Status:** Planned.

#### FR-FAMILY-03 Tirzah memory (optional)
Bezalel **may** push run records/authored-tool provenance into Tirzah graph
memory via the existing ingest path, behind a `tirzah` extra. **Acceptance:**
with the extra, a run's provenance is searchable via `search_memory`.
**Status:** Planned (later).

---

## Non-functional requirements

- **NFR-SAFETY:** INV-1 holds under all code paths; a test suite **shall** assert
  that no primitive executes outside `validate_plan` + `allowed_tools` + gate.
- **NFR-COST:** dynamic tool use multiplies calls; steps **shall** carry a
  `cost_class`, and Hoglah's priority queue **shall** be the execution path so
  cost is schedulable. (Live evidence: multi-role LLM orchestration on local
  Ollama runs minutes-per-role — cost is a first-class constraint, not an
  afterthought.)
- **NFR-OBSERVABLE:** every side effect is a Galeed event (FR-TRACE-01).
- **NFR-DETERMINISTIC-SUBSTRATE:** the substrate (jail, gates, validation) is
  pure deterministic Python and unit-tested without any model.
- **NFR-PORTABLE:** degrades gracefully without a strong sandbox (FR-SANDBOX-04)
  and without the family extras (fail-soft), like the other siblings.
- **NFR-CI:** ruff + pytest gate from the first commit (family standard).

## Phasing (each phase ships green and proves something)

| Phase | Delivers | Proves |
|---|---|---|
| **1** | Primitives 1–3, 6, 7 + workspace jail + Galeed events + Keturah manifest. **No `run`, no network.** | The substrate shape, safely, additively. |
| **2** | `run` under bwrap/linux-sandbox + resource caps. | The autonomy gate — done deliberately. |
| **3** | Cairn-planned reasoning; class-based gate policy; outcomes loop armed; ack semantics. | Bounded dynamic orchestration over the hands. |
| **4** | Self-extension loop (author → test → gate → register); no-core-mutation guard; optional Milcah review. | Capability growth, append-only + gated. |
| **5** | `browse` (allowlisted); `pip_install` / `ollama_pull` (pinned, gated). | Reaching outside — behind hard gates. |

## Open decisions

1. **Name:** Bezalel (recommended) vs. another unused family name.
2. **Repo vs. Noa doc:** scaffold `~/domains/Bezalel` now, or hold at
   requirements until Phase 1 starts.
3. **Sandbox source:** reuse Codex's `linux-sandbox`/`bwrap` (recommended) vs. a
   dedicated dependency (e.g. firejail) vs. path-jail-only floor for Phase 1.
4. **Gate UX:** reuse Tirzah's Process gate surface, or a Bezalel-local prompt.

## Changelog

| Ver | Date | Change |
|---|---|---|
| 0.1 | 2026-07-11 | Initial requirements: INV-1, FR-PRIM-01–09, FR-SANDBOX, FR-PLAN, FR-EXT, FR-GATE, FR-TRACE, FR-FAMILY, NFRs, 5-phase plan. All Planned. |
