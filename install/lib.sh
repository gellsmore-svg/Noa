#!/usr/bin/env bash
# Shared helpers for Noa's install/upgrade scripts. Sourced, not run.

# Repo root, resolved from this file's location (so helpers can find services/).
NOA_LIB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log()  { printf '\033[1m==>\033[0m %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[33m    warn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31mError:\033[0m %s\n' "$*" >&2; exit 1; }

# Resolve the repo root (one level up from install/).
noa_root() { cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd; }

# runuser/su (especially with a login shell) can drop or reset HOME, so `${HOME}`
# inside .env then expands to a bad path at source time. Re-derive the invoking
# user's real home from the passwd database before anything reads HOME.
normalize_home() {
  local realhome
  realhome="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f6)"
  [ -n "$realhome" ] && [ -d "$realhome" ] || return 0
  if [ "${HOME:-}" != "$realhome" ]; then
    [ -n "${HOME:-}" ] && warn "HOME='${HOME}' != passwd home '$realhome' — using '$realhome' (runuser/su can reset HOME)."
    export HOME="$realhome"
  fi
}

# Require .env, then export every variable in it (with HOME normalised first so
# ${HOME}/... values resolve correctly).
load_env() {
  local root="$1"
  normalize_home
  [ -f "$root/.env" ] || die "No .env found — copy .env.example to .env and edit it first."
  set -a; . "$root/.env"; set +a
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "$1 not found. $2"
}

# Bring Mongo up and wait until it answers ping (default 60s).
start_mongo() {
  local root="$1" timeout="${2:-60}" waited=0
  local uri="${MONGO_URI:-mongodb://localhost:${MONGO_PORT:-27017}}"
  if command -v mongosh >/dev/null 2>&1 \
      && mongosh "$uri" --quiet --eval 'db.runCommand({ping:1}).ok' >/dev/null 2>&1; then
    info "mongo already responds at $uri"
    return 0
  fi
  ( cd "$root" && docker compose up -d mongo ) || die "docker compose up mongo failed."
  printf '    waiting for mongo'
  until ( cd "$root" && docker compose exec -T mongo mongosh --quiet \
            --eval 'db.runCommand({ping:1}).ok' ) >/dev/null 2>&1; do
    [ "$waited" -ge "$timeout" ] && { echo; die "mongo did not become ready in ${timeout}s."; }
    printf '.'; sleep 2; waited=$((waited + 2))
  done
  echo " ready"
}

# The lock file to install from. Defaults to versions.lock (local source paths);
# override with VERSIONS_LOCK=versions.git.lock for a fresh machine (public git tags).
versions_lock() {
  echo "${VERSIONS_LOCK:-$1/versions.lock}"
}

# Build a pip/pipx install spec from a versions.lock source, which may be a local
# path or a remote git/URL. `name` and optional `extra` are used for the PEP 508
# "<name>[extra] @ <url>" form that remote sources need. Echoes nothing for a
# missing local path (the caller skips).
pip_spec() {
  local name="$1" extra="$2" src="$3"
  src="${src/#\~/$HOME}"
  case "$src" in
    git+*|http://*|https://*) printf '%s%s @ %s' "$name" "$extra" "$src" ;;
    *)
      [ -e "$src" ] || return 1
      local abs
      if [ -d "$src" ]; then
        abs="$(cd "$src" && pwd -P)"
      else
        abs="$(cd "$(dirname "$src")" && pwd -P)/$(basename "$src")"
      fi
      printf '%s%s @ file://%s' "$name" "$extra" "$abs"
      ;;
  esac
}

# Family libraries: tool dependencies with no console apps that are NOT on
# PyPI (and 'cairn' on PyPI is an unrelated project). They are --preinstall-ed
# into each tool's venv from the lock, which both lets pip resolve them and
# pins the right package instead of a PyPI name-collision.
FAMILY_LIBS="galeed keturah cairn-lang"

_is_family_lib() { case " $FAMILY_LIBS " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# Build local wheels for unpublished family libraries. Pip can then satisfy
# dependencies like `galeed>=0.1` or `keturah>=0.1` without consulting PyPI.
build_family_wheelhouse() {
  local root="$1" lock wheelhouse tool version src spec
  lock="$(versions_lock "$root")"
  wheelhouse="${NOA_WHEELHOUSE:-$HOME/.cache/noa/wheelhouse}"
  NOA_BUILT_WHEELHOUSE="$wheelhouse"
  rm -rf "$wheelhouse"
  mkdir -p "$wheelhouse"

  : > "$wheelhouse/family-constraints.txt"
  while read -r tool version src; do
    _is_family_lib "$tool" || continue
    spec="$(pip_spec "$tool" "" "$src")" \
      || { warn "$tool: source '$src' missing — tools depending on it may not resolve."; continue; }
    info "wheel $tool $version  <-  $src"
    python3 -m pip wheel --no-deps --wheel-dir "$wheelhouse" "$spec" >/dev/null \
      || die "building wheel for $tool failed."
    # Exact pin: 'cairn' on PyPI is an unrelated project whose versions can
    # outrank ours in a find-links + index resolve (it shipped the WRONG
    # package once) — constraints force the family version, which only the
    # wheelhouse can satisfy.
    printf '%s==%s\n' "$tool" "$version" >> "$wheelhouse/family-constraints.txt"
  done < <(grep -vE '^\s*#|^\s*$' "$lock")

  find "$wheelhouse" -maxdepth 1 -name '*.whl' -print -quit | grep -q . \
    || warn "no family library wheels built — fresh installs may fail to resolve galeed/keturah/cairn."
}

# Install each tool pinned in the lock file via pipx (local path OR git tag).
# hoglah gets the [cli] extra (the `hoglah` command needs typer). Family
# libraries from the lock are built into a local wheelhouse so unpublished
# dependencies resolve deterministically during pipx install.
install_pinned_tools() {
  local root="$1" lock tool version src extra spec installed
  local wheelhouse pip_args=()
  require_cmd pipx "Install it: python -m pip install --user pipx && pipx ensurepath"
  lock="$(versions_lock "$root")"
  build_family_wheelhouse "$root"
  wheelhouse="$NOA_BUILT_WHEELHOUSE"
  if find "$wheelhouse" -maxdepth 1 -name '*.whl' -print -quit | grep -q .; then
    pip_args=(--pip-args "--find-links $wheelhouse --constraint $wheelhouse/family-constraints.txt")
  fi

  # Pass 2: install the app tools.
  while read -r tool version src; do
    _is_family_lib "$tool" && continue
    extra=""
    case "$tool" in
      hoglah) extra="[cli]" ;;
      tirzah) extra="[web]" ;;
      milcah) extra="[mongo,web,hoglah,galeed]" ;;
    esac
    spec="$(pip_spec "$tool" "$extra" "$src")" \
      || { warn "$tool: source '$src' missing — skipping."; continue; }
    info "$tool $version  <-  $src"
    pipx install --force "${pip_args[@]}" "$spec" >/dev/null \
      || die "pipx install $tool failed."
    installed="$(pipx runpip "$tool" show "$tool" 2>/dev/null | awk -F ": " '$1 == "Version" && !seen { print $2; seen=1 }')"
    [ "$installed" = "$version" ] \
      || die "$tool version mismatch: lock requires $version, installed ${installed:-unknown}."
  done < <(grep -vE '^\s*#|^\s*$' "$lock")
}

# The semantic seam: Mahalath must be importable inside Tirzah's isolated pipx env.
inject_mahalath_into_tirzah() {
  local root="$1" lock raw spec
  pipx list 2>/dev/null | grep -q "package tirzah" || return 0
  lock="$(versions_lock "$root")"
  raw="$(grep -E '^mahalath ' "$lock" | awk '{print $3}')"
  spec="$(pip_spec "mahalath" "" "$raw")" \
    || { warn "mahalath source missing — skipping inject (set mahalath_enabled:false)."; return 0; }
  info "inject mahalath into tirzah (semantic precision seam)"
  pipx inject --force tirzah "$spec" >/dev/null 2>&1 \
    || warn "mahalath inject failed — semantic precision will be a no-op until fixed."
}

# The Hoglah-first LLM policy: Tirzah's hoglah answer/planner adapter needs the
# hoglah LIBRARY importable inside Tirzah's isolated pipx env (found live: the
# missing inject made every planner call fail silently into fallback plans).
inject_hoglah_into_tirzah() {
  local root="$1" lock raw spec
  pipx list 2>/dev/null | grep -q "package tirzah" || return 0
  lock="$(versions_lock "$root")"
  raw="$(grep -E '^hoglah ' "$lock" | awk '{print $3}')"
  spec="$(pip_spec "hoglah" "" "$raw")" \
    || { warn "hoglah source missing — tirzah's hoglah adapter will be unavailable."; return 0; }
  info "inject hoglah into tirzah (Hoglah-first LLM routing)"
  pipx inject --force tirzah "$spec" >/dev/null 2>&1 \
    || warn "hoglah inject into tirzah failed — its hoglah adapter will error."
}

# The trace spine: galeed is a library (not on PyPI, no console app), so it is
# injected into each tool's isolated pipx env from the lock source. Hoglah also
# gets pymongo (its core is Mongo-free) so job events persist rather than being
# bus-only. Emission itself is toggled by the *_GALEED_ENABLED flags in .env.
inject_galeed() {
  local root="$1" lock raw spec tool
  lock="$(versions_lock "$root")"
  raw="$(grep -E '^galeed ' "$lock" | awk '{print $3}')"
  spec="$(pip_spec "galeed" "" "$raw")" \
    || { warn "galeed source missing — trace-spine emission stays a no-op."; return 0; }
  for tool in hoglah mahalath tirzah; do
    pipx list 2>/dev/null | grep -q "package $tool" || continue
    info "inject galeed into $tool (family trace spine)"
    pipx inject --force "$tool" "$spec" >/dev/null 2>&1 \
      || warn "galeed inject into $tool failed — its spine emission will no-op."
  done
  if pipx list 2>/dev/null | grep -q "package hoglah"; then
    pipx inject hoglah "pymongo>=4.6" >/dev/null 2>&1 \
      || warn "pymongo inject into hoglah failed — job events will be bus-only."
  fi
}

# The family LLM debugger: galeed doubles as an APP now (`galeed trace` /
# `galeed serve` console script), so stack machines get the debugging CLI and
# trace API out of the box, installed with its cli+web extras. The wheelhouse
# find-links resolves the local galeed wheel; the extras (rich, pymongo,
# fastapi, uvicorn) come from PyPI.
install_galeed_app() {
  local root="$1" lock raw version spec wheelhouse
  local pip_args=()
  lock="$(versions_lock "$root")"
  raw="$(grep -E '^galeed ' "$lock" | awk '{print $3}')"
  version="$(grep -E '^galeed ' "$lock" | awk '{print $2}')"
  spec="$(pip_spec "galeed" "[cli,web]" "$raw")" \
    || { warn "galeed source missing — the galeed debugger CLI will not be installed."; return 0; }
  wheelhouse="${NOA_BUILT_WHEELHOUSE:-${NOA_WHEELHOUSE:-$HOME/.cache/noa/wheelhouse}}"
  if find "$wheelhouse" -maxdepth 1 -name '*.whl' -print -quit 2>/dev/null | grep -q .; then
    pip_args=(--pip-args "--find-links $wheelhouse --constraint $wheelhouse/family-constraints.txt")
  fi
  info "galeed $version [cli,web]  <-  $raw"
  pipx install --force ${pip_args[@]+"${pip_args[@]}"} "$spec" >/dev/null \
    || { warn "pipx install galeed failed — debugger CLI unavailable (tools still emit)."; return 0; }
}

# Serve the Mahlah UI from the installed Tirzah: build the front end (when the
# repo and npm are available) and copy the dist into the pipx venv's static
# dir. The tirzah wheel ships no built UI, so this must re-run after every
# tirzah (re)install. Failure is a warn — the API still serves a fallback page.
install_tirzah_ui() {
  local ui_src="${MAHLAH_DIR:-$HOME/domains/Mahlah}" webdir
  pipx list 2>/dev/null | grep -q "package tirzah" || return 0
  [ -f "$ui_src/package.json" ] \
    || { info "mahlah repo not found ($ui_src) — tirzah serves the API-only fallback page."; return 0; }
  command -v npm >/dev/null 2>&1 \
    || { warn "npm not found — cannot build the Mahlah UI."; return 0; }
  info "build Mahlah UI -> installed tirzah"
  ( cd "$ui_src" && npm install --silent >/dev/null 2>&1 && npm run build >/dev/null 2>&1 ) \
    || { warn "Mahlah UI build failed — tirzah serves the API-only fallback page."; return 0; }
  webdir="$(ls -d "$HOME"/.local/share/pipx/venvs/tirzah/lib/python3*/site-packages/tirzah/web 2>/dev/null | head -1)"
  [ -n "$webdir" ] || { warn "installed tirzah web dir not found — UI not installed."; return 0; }
  mkdir -p "$webdir/static"
  rm -rf "$webdir/static/assets"
  cp -r "$ui_src"/dist/. "$webdir/static/" || { warn "UI copy failed."; return 0; }
  info "Mahlah UI installed into tirzah"
}

# Render the active Tirzah config from .env so the semantic seam is on by default
# (feedback: a missing TIRZAH_CONFIG file silently disabled it). Won't clobber a
# file the user has already edited.
render_tirzah_config() {
  local cfg="${TIRZAH_CONFIG:-}"
  [ -n "$cfg" ] || return 0
  if [ -f "$cfg" ]; then info "tirzah config exists ($cfg) — leaving as-is"; return 0; fi
  mkdir -p "$(dirname "$cfg")"
  cat > "$cfg" <<YAML
# Rendered by Noa install from .env. Edit freely; install won't overwrite it.
runtime:
  # Real LLM + embeddings through the Hoglah worker daemon (Noa default).
  model_adapter: hoglah
  answer_adapter: hoglah
  embedding_adapter: hoglah
  embedding_model: ${EMBEDDING_MODEL:-bge-m3:latest}
  embedding_dimensions: ${EMBEDDING_DIMENSIONS:-1024}
  hoglah_db_path: ${HOGLAH_DB_PATH:-$HOME/.hoglah/hoglah.db}
  hoglah_output_dir: ${HOGLAH_OUTPUT_DIR:-$HOME/.hoglah/outbox}
  hoglah_ollama_host: ${HOGLAH_OLLAMA_HOST:-http://localhost:11434}
  # Semantic precision seam (Tirzah -> Mahalath).
  mahalath_enabled: ${MAHALATH_ENABLED:-true}
  mahalath_mongo_uri: ${MAHALATH_MONGO_URI:-mongodb://localhost:27017}
  mahalath_mongo_db: ${MAHALATH_MONGO_DB:-mahalath_dev}
  mahalath_strict: ${MAHALATH_STRICT:-true}
YAML
  info "wrote active tirzah config -> $cfg"
}

# Is a usable systemd USER instance available (native Linux), vs not (WSL, no systemd)?
_systemd_user_available() {
  command -v systemctl >/dev/null 2>&1 || return 1
  systemctl --user show-environment >/dev/null 2>&1
}

# Render the worker env file the unit reads (HOGLAH_* from .env, with defaults).
_render_worker_envfile() {
  local qdir="$1" envfile="$1/worker.env"
  cat > "$envfile" <<EOF
HOGLAH_DB_PATH=${HOGLAH_DB_PATH:-$qdir/hoglah.db}
HOGLAH_OUTPUT_DIR=${HOGLAH_OUTPUT_DIR:-$qdir/outbox}
HOGLAH_OLLAMA_HOST=${HOGLAH_OLLAMA_HOST:-http://localhost:11434}
HOGLAH_CONCURRENCY=${HOGLAH_CONCURRENCY:-1}
HOGLAH_GALEED_ENABLED=${HOGLAH_GALEED_ENABLED:-true}
HOGLAH_GALEED_MONGO_URI=${HOGLAH_GALEED_MONGO_URI:-mongodb://localhost:27017}
HOGLAH_GALEED_MONGO_DB=${HOGLAH_GALEED_MONGO_DB:-mnemosyne_dev}
EOF
  echo "$envfile"
}

# Native Linux: run the worker as a systemd user service (durable, auto-restart,
# survives logout with linger). Returns non-zero so the caller can fall back.
_start_worker_systemd() {
  local qdir="$1" template="$NOA_LIB_ROOT/services/hoglah-worker.service"
  local unitdir="$HOME/.config/systemd/user" envfile hoglah_bin
  [ -f "$template" ] || return 1
  hoglah_bin="$(command -v hoglah)" || return 1
  mkdir -p "$unitdir"
  envfile="$(_render_worker_envfile "$qdir")"
  sed -e "s#@ENVFILE@#$envfile#" -e "s#@HOGLAH@#$hoglah_bin#" "$template" \
    > "$unitdir/hoglah-worker.service" || return 1
  systemctl --user daemon-reload || return 1
  systemctl --user enable --now hoglah-worker.service >/dev/null 2>&1 || return 1
  loginctl enable-linger "$(id -un)" >/dev/null 2>&1 \
    || warn "could not enable linger — worker won't survive logout. Run: loginctl enable-linger $(id -un)"
  info "hoglah worker running as a systemd user service (systemctl --user status hoglah-worker)"
}

# Fallback (WSL / no systemd): a backgrounded process with a PID file + log.
_start_worker_setsid() {
  local qdir="$1" pidfile="$1/worker.pid" logfile="$1/worker.log"
  if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile" 2>/dev/null)" 2>/dev/null; then
    info "hoglah worker already running (pid $(cat "$pidfile"))"; return 0
  fi
  info "starting hoglah worker -> $logfile"
  HOGLAH_DB_PATH="${HOGLAH_DB_PATH:-$qdir/hoglah.db}" \
  HOGLAH_OUTPUT_DIR="${HOGLAH_OUTPUT_DIR:-$qdir/outbox}" \
  HOGLAH_OLLAMA_HOST="${HOGLAH_OLLAMA_HOST:-http://localhost:11434}" \
  HOGLAH_CONCURRENCY="${HOGLAH_CONCURRENCY:-1}" \
  HOGLAH_GALEED_ENABLED="${HOGLAH_GALEED_ENABLED:-true}" \
  HOGLAH_GALEED_MONGO_URI="${HOGLAH_GALEED_MONGO_URI:-mongodb://localhost:27017}" \
  HOGLAH_GALEED_MONGO_DB="${HOGLAH_GALEED_MONGO_DB:-mnemosyne_dev}" \
    setsid hoglah run --real >"$logfile" 2>&1 &
  echo $! > "$pidfile"
  sleep 2
  kill -0 "$(cat "$pidfile")" 2>/dev/null \
    && info "hoglah worker up (pid $(cat "$pidfile"))" \
    || warn "hoglah worker exited immediately — see $logfile"
}

# Start the Hoglah worker (the executor behind the hoglah adapters). Prefers a
# systemd user service on native Linux; falls back to a background process on
# WSL / no-systemd. Idempotent.
start_hoglah_worker() {
  local qdir="${HOGLAH_QUEUE_DIR:-$HOME/.hoglah}"
  command -v hoglah >/dev/null 2>&1 || { warn "hoglah CLI not on PATH — cannot start the worker."; return 0; }
  mkdir -p "$qdir"
  if _systemd_user_available && _start_worker_systemd "$qdir"; then
    return 0
  fi
  _systemd_user_available && warn "systemd user setup failed — using a background process."
  _start_worker_setsid "$qdir"
}

# Restart the worker to pick up upgraded code (systemd service or setsid process).
restart_hoglah_worker() {
  local qdir="${HOGLAH_QUEUE_DIR:-$HOME/.hoglah}" pidfile
  if _systemd_user_available && systemctl --user cat hoglah-worker.service >/dev/null 2>&1; then
    mkdir -p "$qdir"
    _render_worker_envfile "$qdir" >/dev/null   # pick up new/changed env keys
    systemctl --user restart hoglah-worker.service && { info "restarted hoglah worker (systemd)"; return 0; }
  fi
  pidfile="$qdir/worker.pid"
  [ -f "$pidfile" ] && kill "$(cat "$pidfile" 2>/dev/null)" 2>/dev/null && rm -f "$pidfile"
  start_hoglah_worker
}

# Best-effort schema migrations on tools that expose a `migrate` command.
run_migrations() {
  if command -v mahalath >/dev/null 2>&1 && mahalath --help 2>&1 | grep -q '\bmigrate\b'; then
    info "mahalath migrate"; mahalath migrate || warn "mahalath migrate reported an error."
  else
    info "no migrate command yet — skipping (see report §5)."
  fi
}
