# Hoglah Live Observer Example

This sample was generated from a local Galeed `hoglah` session using:

```bash
./workflows/live_observer.sh --session hoglah \
  --title "Noa Hoglah live observer sample"
```

It demonstrates the intended observer loop:

- Galeed records runtime queue events.
- Noa exports the session and runs the Cairn observer.
- Cairn turns queue traces into human-load and system-reliability findings.

## Report

Events: 24

### Sources

- hoglah: 24

### Kinds

- queue_event: 24

### Findings

- **human_load: queue vigilance load** - Observed 12 queue event(s) that keep work
  in a waiting or in-progress state.

  Mitigation: Expose queue position, expected completion, stalled state, and
  completion handoff so users do not have to monitor the process manually.

- **system_reliability: long queue lifecycle** - Observed 9 queue lifecycle(s) at
  or above 30000 ms; longest was about 81 seconds.

  Mitigation: Record queue/run duration explicitly and surface progress, expected
  completion, and timeout thresholds in the user-facing workflow.

- **operational_learning: repeated observation cluster** - Repeated observations
  from: hoglah.

  Mitigation: Treat repeated clusters as candidates for durable product changes,
  not one-off incidents.

## Product Implication

The queue is functioning, but the user-facing experience around waiting is not
yet explicit enough. If a product depends on Hoglah for agentic work, users need
clear state for:

- queued,
- running,
- stalled,
- expected completion,
- completed and handed back to the task.

This is exactly the kind of human/system evidence Cairn should surface: not just
"the job ran", but "what does the runtime make the human carry?"
