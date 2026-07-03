#!/usr/bin/env bash
# Noa upgrade — back up, reinstall the pinned tools (picking up new code), run
# migrations, and verify. The flow that keeps a working install safe while the
# tools change (report §5): backup -> install -> migrate -> health -> (rollback).
#
# Usage: ./install/upgrade.sh [--no-backup]
#   Bump versions.lock first, then run this.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/install/lib.sh"

NO_BACKUP=0
[ "${1:-}" = "--no-backup" ] && NO_BACKUP=1

require_cmd docker "Install Docker (with the compose plugin)."
require_cmd pipx   "Install it: python -m pip install --user pipx && pipx ensurepath"
load_env "$ROOT"

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$ROOT/backups/$STAMP"

# --- 1/4 backup ------------------------------------------------------------
log "1/4  Backup"
if [ "$NO_BACKUP" -eq 1 ]; then
  warn "--no-backup given — skipping the pre-upgrade backup."
else
  mkdir -p "$BACKUP_DIR"
  cp "$(versions_lock "$ROOT")" "$BACKUP_DIR/versions.lock"
  pipx list --short > "$BACKUP_DIR/pipx-versions.txt" 2>/dev/null || true
  # mongodump every DB into one gzipped archive (try the container, then the host).
  if ( cd "$ROOT" && docker compose exec -T mongo mongodump --archive --gzip ) \
        > "$BACKUP_DIR/mongo.archive.gz" 2>/dev/null && [ -s "$BACKUP_DIR/mongo.archive.gz" ]; then
    info "mongodump (container) -> $BACKUP_DIR/mongo.archive.gz"
  elif command -v mongodump >/dev/null 2>&1 \
        && mongodump --uri "${MONGO_URI:-mongodb://localhost:27017}" --archive --gzip \
             > "$BACKUP_DIR/mongo.archive.gz" 2>/dev/null && [ -s "$BACKUP_DIR/mongo.archive.gz" ]; then
    info "mongodump (host) -> $BACKUP_DIR/mongo.archive.gz"
  else
    rm -rf "$BACKUP_DIR"
    die "Could not back up Mongo (no mongodump in the container or on the host). Re-run with --no-backup to proceed without one."
  fi
  info "backup at $BACKUP_DIR"
fi

# --- 2/4 reinstall pinned tools -------------------------------------------
log "2/4  Reinstall pinned tools"
install_pinned_tools "$ROOT"
inject_galeed "$ROOT"   # pipx --force reinstall wipes injected packages
inject_mahalath_into_tirzah "$ROOT"
restart_hoglah_worker   # pick up the upgraded hoglah code

# --- 3/4 migrations --------------------------------------------------------
log "3/4  Migrations"
run_migrations

# --- 4/4 health ------------------------------------------------------------
log "4/4  Health"
if "$ROOT/health/healthcheck.sh"; then
  log "Upgrade complete."
  [ "$NO_BACKUP" -eq 0 ] && info "Backup kept at $BACKUP_DIR"
else
  warn "Healthcheck FAILED after upgrade."
  if [ "$NO_BACKUP" -eq 0 ]; then
    cat >&2 <<EOF

To roll back:
  1. git checkout the previous versions.lock, or:  cp "$BACKUP_DIR/versions.lock" "$ROOT/versions.lock"
  2. ./install/install.sh                          # reinstall the previous pins
  3. restore the data:
       docker compose exec -T mongo mongorestore --archive --gzip --drop < "$BACKUP_DIR/mongo.archive.gz"
EOF
  fi
  die "Upgrade left the stack unhealthy (see rollback steps above)."
fi
