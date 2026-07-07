# Noa Live Observer

Noa is the runtime host for the family observer loop. It should not own the
analysis language or the log spine:

- Cairn owns the observation language and human/agent/system analysis.
- Galeed owns the durable trace/log spine and correlation ids.
- Noa wires the running stack together and gives operators a workflow.

## Workflow

After the stack has produced Galeed events, run:

```bash
./workflows/live_observer.sh --trace trace_123 \
  --title "Noa trace trace_123"
```

or for a whole session:

```bash
./workflows/live_observer.sh --session sess_123 \
  --title "Noa session sess_123"
```

The workflow writes three files under `reports/live-observer/`:

- the raw Galeed event export,
- the Cairn observation JSONL,
- the Cairn live-observation Markdown report.

This lets a running stack answer the practical questions:

- where did the system wait, fail, retry, or ask the user to repair context?
- did agent output carry evidence and authority cues?
- what human systems were plausibly loaded: trust calibration, uncertainty
  management, accountability, recall, language, audit reasoning?
- which repeated findings should become product or process improvements?

## Producer Contract

Products that already use Galeed can emit Cairn-readable observations with:

```python
from galeed import emit_cairn_observation

emit_cairn_observation(
    tracer,
    kind="agent_output",
    message="Generated recommendation without authority citation.",
    tags=["missing_evidence"],
    human_systems=["trust calibration", "uncertainty management"],
    duration_ms=4200,
)
```

Noa's role is to make sure the relevant CLIs are installed, the Galeed database
settings are shared, and this workflow is available to operators and future
automation.
