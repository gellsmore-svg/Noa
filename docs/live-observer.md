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

See `docs/examples/hoglah-live-observer-sample.md` for a real local Hoglah
session report that surfaced queue vigilance load and long queue lifecycles.
See `docs/live-observer-production-readiness.md` for the current verified
production-readiness snapshot.

If the Galeed export contains no events, the workflow fails by default. Use
`--allow-empty` only for smoke tests or deliberate empty-baseline reports.

## Scheduled Runs

For timestamped operator reports, run:

```bash
./workflows/live_observer_scheduled.sh
```

The scheduled wrapper reads `.env` and writes to:

```text
${NOA_OBSERVER_OUT_DIR:-reports/live-observer}/scheduled/<UTC run id>/
```

After each scheduled run it refreshes:

- `index.md` - operator-readable rollup of reports, event totals, risk, and repeated findings.
- `index.json` - machine-readable report summaries for future dashboards or issue creation.

Set these `.env` keys to tune it:

- `NOA_OBSERVER_ON_CALENDAR` - systemd timer schedule, default `hourly`.
- `NOA_OBSERVER_RANDOMIZED_DELAY_SEC` - timer jitter, default `5m`.
- `NOA_OBSERVER_LIMIT` - event export limit, default `200`.
- `NOA_OBSERVER_TRACE_ID` or `NOA_OBSERVER_SESSION_ID` - optional filter.
- `NOA_OBSERVER_ALLOW_EMPTY` - set `true` only for deliberate empty baselines.

On native Linux, `install/install.sh` renders and enables:

- `~/.config/systemd/user/noa-live-observer.service`
- `~/.config/systemd/user/noa-live-observer.timer`

On WSL or other no-systemd environments, run the scheduled wrapper manually or
from cron.

To rebuild the index without running a new observation:

```bash
./workflows/live_observer_index.py --root reports/live-observer/scheduled
```

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
