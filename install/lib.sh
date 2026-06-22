#!/usr/bin/env bash
# Shared helpers for Noa's install/upgrade scripts. Sourced, not run.

log()  { printf '\033[1m==>\033[0m %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[33m    warn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31mError:\033[0m %s\n' "$*" >&2; exit 1; }

# Resolve the repo root (one level up from install/).
noa_root() { cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd; }

# Require .env, then export every variable in it.
load_env() {
  local root="$1"
  [ -f "$root/.env" ] || die "No .env found — copy .env.example to .env and edit it first."
  set -a; . "$root/.env"; set +a
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "$1 not found. $2"
}

# Bring Mongo up and wait until it answers ping (default 60s).
start_mongo() {
  local root="$1" timeout="${2:-60}" waited=0
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
    *) [ -e "$src" ] && printf '%s%s' "$src" "$extra" || return 1 ;;
  esac
}

# Install each tool pinned in the lock file via pipx (local path OR git tag).
# hoglah gets the [cli] extra (the `hoglah` command needs typer).
install_pinned_tools() {
  local root="$1" lock tool version src extra spec
  require_cmd pipx "Install it: python -m pip install --user pipx && pipx ensurepath"
  lock="$(versions_lock "$root")"
  while read -r tool version src; do
    [ -z "$tool" ] && continue
    case "$tool" in \#*) continue ;; esac
    extra=""; [ "$tool" = "hoglah" ] && extra="[cli]"
    spec="$(pip_spec "$tool" "$extra" "$src")" \
      || { warn "$tool: source '$src' missing — skipping."; continue; }
    info "$tool $version  <-  $src"
    pipx install --force "$spec" >/dev/null || die "pipx install $tool failed."
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
  pipx inject tirzah "$spec" >/dev/null 2>&1 \
    || warn "mahalath inject failed — semantic precision will be a no-op until fixed."
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
  mahalath_enabled: ${MAHALATH_ENABLED:-true}
  mahalath_mongo_uri: ${MAHALATH_MONGO_URI:-mongodb://localhost:27017}
  mahalath_mongo_db: ${MAHALATH_MONGO_DB:-mahalath_dev}
  mahalath_strict: ${MAHALATH_STRICT:-true}
YAML
  info "wrote active tirzah config -> $cfg"
}

# Best-effort schema migrations on tools that expose a `migrate` command.
run_migrations() {
  if command -v mahalath >/dev/null 2>&1 && mahalath --help 2>&1 | grep -q '\bmigrate\b'; then
    info "mahalath migrate"; mahalath migrate || warn "mahalath migrate reported an error."
  else
    info "no migrate command yet — skipping (see report §5)."
  fi
}
