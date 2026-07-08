#!/usr/bin/env bash
# Run the Noa live observer into a timestamped report directory.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/install/lib.sh"; normalize_home
[ -f "$ROOT/.env" ] && { set -a; . "$ROOT/.env"; set +a; }

run_id="${NOA_OBSERVER_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
base_dir="${NOA_OBSERVER_SCHEDULED_OUT_DIR:-${NOA_OBSERVER_OUT_DIR:-$ROOT/reports/live-observer}/scheduled}"
out_dir="${NOA_OBSERVER_RUN_DIR:-$base_dir/$run_id}"
title="${NOA_OBSERVER_TITLE:-Noa scheduled live observer $run_id}"
limit="${NOA_OBSERVER_LIMIT:-200}"

args=(--limit "$limit" --title "$title" --out-dir "$out_dir")
if [ -n "${NOA_OBSERVER_TRACE_ID:-}" ]; then
  args+=(--trace "$NOA_OBSERVER_TRACE_ID")
elif [ -n "${NOA_OBSERVER_SESSION_ID:-}" ]; then
  args+=(--session "$NOA_OBSERVER_SESSION_ID")
fi
case "${NOA_OBSERVER_ALLOW_EMPTY:-false}" in
  true|1|yes|on) args+=(--allow-empty) ;;
esac

exec "$ROOT/workflows/live_observer.sh" "${args[@]}"
