# Current-state addendum — 2026-06-26

This addendum updates the older Noa readiness/integration documents without
rewriting their historical record.

## Current verified changes since the earlier readiness report

- Hoglah is pinned at `0.9.0` in Noa and provides the current queue/runtime baseline.
- Tirzah is pinned at `1.12.0` in Noa and includes recursive Cairn-style request planning plus MCP-facing memory/coherence surfaces.
- Galeed exists as the extracted cross-project trace/log spine. Tirzah currently serves the trace HTTP/SSE API consumed by Mahlah and Mizpah.
- Milcah is pinned in Noa for the coherence/review seam, while its deeper persistence/runtime contract remains an area for later hardening.
- Tirzah and Mahalath now default `ollama_executable` to `Path("ollama")` with HTTP `OLLAMA_BASE_URL` support, rather than hardcoding a WSL-specific `ollama.exe`.
- Mahalath derives `__version__` from installed package metadata, so the older package/module version mismatch is no longer current.

## Current contract gaps

- Tirzah renders Cairn-style plans, but Cairn does not yet provide a shared runtime validator/conformance package.
- Galeed needs explicit event schema compatibility fixtures before all siblings emit directly.
- Mizpah and Mahlah consume Tirzah trace APIs today; a future Galeed collector/API is still an open design decision.
- Tirzah→Milcah specialist invocation is available through the current MCP/coherence-check seam, with deeper runtime persistence still later work.
- Tirzah→Mahalath semantic integration is documented as the current public
  contract in [integration.md](integration.md), while richer extraction and an
  HTTP resolver remain optional future work.

## Runtime implication

For the current Noa lock set, treat `hoglah>=0.9.0` as the family minimum for optional Hoglah integrations. Package metadata in Tirzah and Mahalath should match that operational constraint.
