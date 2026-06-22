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

# Install each tool pinned in versions.lock via pipx, from its source path.
# hoglah gets the [cli] extra (the `hoglah` command needs typer).
install_pinned_tools() {
  local root="$1" tool version path src spec
  require_cmd pipx "Install it: python -m pip install --user pipx && pipx ensurepath"
  while read -r tool version path; do
    [ -z "$tool" ] && continue
    case "$tool" in \#*) continue ;; esac
    src="${path/#\~/$HOME}"
    [ -e "$src" ] || { warn "$tool: source path '$src' missing — skipping."; continue; }
    spec="$src"; [ "$tool" = "hoglah" ] && spec="${src}[cli]"
    info "$tool $version  <-  $src"
    pipx install --force "$spec" >/dev/null || die "pipx install $tool failed."
  done < <(grep -vE '^\s*#|^\s*$' "$root/versions.lock")
}

# The semantic seam: Mahalath must be importable inside Tirzah's isolated pipx env.
inject_mahalath_into_tirzah() {
  local root="$1" src
  pipx list 2>/dev/null | grep -q "package tirzah" || return 0
  src="$(grep -E '^mahalath ' "$root/versions.lock" | awk '{print $3}')"
  src="${src/#\~/$HOME}"
  [ -e "$src" ] || { warn "mahalath path missing — skipping inject (set mahalath_enabled:false)."; return 0; }
  info "inject mahalath into tirzah (semantic precision seam)"
  pipx inject tirzah "$src" >/dev/null 2>&1 \
    || warn "mahalath inject failed — semantic precision will be a no-op until fixed."
}

# Best-effort schema migrations on tools that expose a `migrate` command.
run_migrations() {
  if command -v mahalath >/dev/null 2>&1 && mahalath --help 2>&1 | grep -q '\bmigrate\b'; then
    info "mahalath migrate"; mahalath migrate || warn "mahalath migrate reported an error."
  else
    info "no migrate command yet — skipping (see report §5)."
  fi
}
