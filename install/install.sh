#!/usr/bin/env bash
# Noa install — bring the local stack up from pinned versions, idempotently.
# Hybrid runtime (report §3): Mongo in Docker, Ollama on the host (by URL), tools
# via pipx. Re-running is safe: pipx --force reinstalls, mongo stays up.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/install/lib.sh"

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
install_cairn_app "$ROOT"
start_hoglah_worker
inject_mahalath_into_tirzah "$ROOT"
inject_hoglah_into_tirzah "$ROOT"
render_tirzah_config
install_tirzah_ui

# --- 4/4 health ------------------------------------------------------------
log "4/4  Health"
"$ROOT/health/healthcheck.sh" || die "Healthcheck reported problems — see above."

log "Done. Stack is up."
info "Load the stack env in your shell so the tools see the config:"
info "    source $ROOT/.env        # (or add it to ~/.bashrc)"
info "Then try:  tirzah ask --query 'what does substrate mean here?'"
info "Debug LLM calls:  galeed trace --follow   (or 'galeed serve' + Mizpah for the browser)"
info "Compose process views:  cairn-serve   (http://127.0.0.1:8795 — save views as templates)"
