#!/usr/bin/env bash
# Noa install — bring the local stack up from pinned versions, idempotently.
# Hybrid runtime (report §3): Mongo in Docker, Ollama on the host (by URL), tools
# via pipx. Re-running is safe: pipx --force reinstalls, mongo stays up.
#
# Usage:
#   ./install/install.sh                 # install + require healthcheck
#   ./install/install.sh --skip-health   # install only (dev / partial bootstrap)
#   ./install/install.sh --allow-partial # install; healthcheck warns but does not die
#   NOA_ALLOW_PARTIAL=1 ./install/install.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/install/lib.sh"

SKIP_HEALTH=0
ALLOW_PARTIAL=0
for arg in "$@"; do
  case "$arg" in
    --skip-health|--no-health) SKIP_HEALTH=1 ;;
    --allow-partial|--partial) ALLOW_PARTIAL=1 ;;
    -h|--help)
      cat <<'EOF'
Noa install — local stack bootstrap.

  --skip-health     Skip the post-install healthcheck entirely (dev / CI
                    where Ollama or the Hoglah worker may be down).
  --allow-partial   Run the healthcheck but do not exit non-zero on failure;
                    print a warn and finish so a partial stack is usable.
  NOA_ALLOW_PARTIAL=1   Same as --allow-partial (env form for automation).
EOF
      exit 0
      ;;
    *)
      die "Unknown argument: $arg (try --help)"
      ;;
  esac
done
# Env form for automation / documented partial bootstrap.
if [ "${NOA_ALLOW_PARTIAL:-0}" = "1" ] || [ "${NOA_ALLOW_PARTIAL:-}" = "true" ]; then
  ALLOW_PARTIAL=1
fi

# --- 0/4 preflight ---------------------------------------------------------
log "0/4  Preflight"
require_cmd docker "Install Docker (with the compose plugin)."
require_cmd pipx   "Install it: python -m pip install --user pipx && pipx ensurepath"
load_env "$ROOT"
OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://localhost:11434}"
if curl -fsS "$OLLAMA_BASE_URL/api/tags" >/dev/null 2>&1; then
  info "ollama reachable at $OLLAMA_BASE_URL"
else
  warn "ollama not reachable at $OLLAMA_BASE_URL — start it on the host (Noa does not manage it)."
fi

# --- 1/4 mongo -------------------------------------------------------------
log "1/4  MongoDB (docker compose)"
start_mongo "$ROOT"

# --- 2/4 tools -------------------------------------------------------------
log "2/4  Tools (pipx, from versions.lock)"
install_pinned_tools "$ROOT"

# --- 3/4 worker + adapters + active config ---------------------------------
log "3/4  Real adapters (Hoglah worker + Tirzah<-Mahalath seam + Galeed spine)"
inject_galeed "$ROOT"
install_galeed_app "$ROOT"
install_keturah_app "$ROOT"
inject_tirzah_into_keturah "$ROOT"
inject_milcah_into_keturah "$ROOT"
inject_hanani_into_keturah "$ROOT"
install_deborah_app "$ROOT"
install_huldah_app "$ROOT"
start_hoglah_worker
install_live_observer_timer
inject_mahalath_into_tirzah "$ROOT"
inject_hoglah_into_tirzah "$ROOT"
render_tirzah_config
install_tirzah_ui

# --- 4/4 health ------------------------------------------------------------
log "4/4  Health"
if [ "$SKIP_HEALTH" -eq 1 ]; then
  warn "Skipping healthcheck (--skip-health). Run ./health/healthcheck.sh when ready."
else
  if "$ROOT/health/healthcheck.sh"; then
    info "Healthcheck passed."
  else
    if [ "$ALLOW_PARTIAL" -eq 1 ]; then
      warn "Healthcheck reported problems — continuing (--allow-partial / NOA_ALLOW_PARTIAL)."
      warn "Install finished with a partial stack; fix Ollama/worker/mongo and re-run healthcheck."
    else
      die "Healthcheck reported problems — see above. Use --allow-partial or --skip-health for a partial bootstrap."
    fi
  fi
fi

# New (MCP / coding agent integration)
render_mcp_server_config || true

log "Done. Stack is up${ALLOW_PARTIAL:+ (partial bootstrap allowed)}."
info "Load the stack env in your shell so the tools see the config:"
info "    source $ROOT/.env        # (or add it to ~/.bashrc)"
info "Then try:  tirzah ask --query 'what does substrate mean here?'"
info "Debug LLM calls:  galeed trace --follow   (or 'galeed serve' + Mizpah for the browser)"
info "Compose process views:  deborah-serve (http://127.0.0.1:8795 — save views as templates)"
info "Observe a live trace:  ./workflows/live_observer.sh --trace <trace_id>"
info "Scheduled observer:  ./workflows/live_observer_scheduled.sh   (systemd timer on native Linux)"
info "Coding-agent bridge:  keturah-mcp + galeed-codex-hook  (configured in ~/.codex/config.toml)"
