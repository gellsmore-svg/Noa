# Current-state addendum — 2026-06-26

This addendum updates the older Noa readiness/integration documents without
rewriting their historical record.

## Current verified changes since the earlier readiness report

- Hoglah is pinned at `0.8.0` in Noa and provides the current queue/runtime baseline.
- Tirzah is pinned at `1.3.0` in Noa and now includes recursive Cairn-style request planning.
- Galeed exists as the extracted cross-project trace/log spine. Tirzah currently serves the trace HTTP/SSE API consumed by Mahlah and Mizpah.
- Milcah includes bounded web research for counter-framework/coherence work, but remains outside the Noa minimum runtime lock until its persistence/runtime contract is ready.
- Tirzah and Mahalath now default `ollama_executable` to `Path("ollama")` with HTTP `OLLAMA_BASE_URL` support, rather than hardcoding a WSL-specific `ollama.exe`.
- Mahalath derives `__version__` from installed package metadata, so the older package/module version mismatch is no longer current.

## Current contract gaps

- Tirzah renders Cairn-style plans, but Cairn does not yet provide a shared runtime validator/conformance package.
- Galeed needs explicit event schema compatibility fixtures before all siblings emit directly.
- Mizpah and Mahlah consume Tirzah trace APIs today; a future Galeed collector/API is still an open design decision.
- Tirzah→Milcah specialist invocation is not yet formalized.
- Tirzah→Mahalath semantic integration should be documented as a current public contract rather than historical TODOs.

## Runtime implication

For the current Noa lock set, treat `hoglah>=0.8.0` as the family minimum for optional Hoglah integrations. Package metadata in Tirzah and Mahalath should match that operational constraint.
