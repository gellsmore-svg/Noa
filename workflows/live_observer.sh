#!/usr/bin/env bash
# Export Galeed trace events and turn them into a Cairn live-observation report.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/install/lib.sh"; normalize_home
[ -f "$ROOT/.env" ] && { set -a; . "$ROOT/.env"; set +a; }

TRACE_ID=""
SESSION_ID=""
LIMIT="${NOA_OBSERVER_LIMIT:-200}"
TITLE="Noa live observer"
OUT_DIR="${NOA_OBSERVER_OUT_DIR:-$ROOT/reports/live-observer}"

usage() {
  cat <<'EOF'
Usage: workflows/live_observer.sh [--trace TRACE_ID | --session SESSION_ID] [options]

Options:
  --trace ID       Export Galeed events for one trace.
  --session ID     Export Galeed events for one session.
  --limit N        Max events to export from Galeed. Default: 200.
  --title TEXT     Report title. Default: "Noa live observer".
  --out-dir DIR    Output directory. Default: reports/live-observer.
  -h, --help       Show this help.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --trace) TRACE_ID="${2:-}"; shift 2 ;;
    --session) SESSION_ID="${2:-}"; shift 2 ;;
    --limit) LIMIT="${2:-}"; shift 2 ;;
    --title) TITLE="${2:-}"; shift 2 ;;
    --out-dir) OUT_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -n "$TRACE_ID" ] && [ -n "$SESSION_ID" ]; then
  echo "choose either --trace or --session, not both" >&2
  exit 2
fi

command -v galeed >/dev/null || { echo "galeed not on PATH - run install/install.sh first." >&2; exit 1; }
command -v cairn-galeed-observe >/dev/null \
  || { echo "cairn-galeed-observe not on PATH - run install/install.sh first." >&2; exit 1; }

MONGO_URI="${HOGLAH_GALEED_MONGO_URI:-${TIRZAH_MONGO_URI:-${MONGO_URI:-mongodb://localhost:27017}}}"
MONGO_DB="${HOGLAH_GALEED_MONGO_DB:-${TIRZAH_MONGO_DB:-mnemosyne_dev}}"
mkdir -p "$OUT_DIR"

label="latest"
filter_args=()
if [ -n "$TRACE_ID" ]; then
  label="trace-$TRACE_ID"
  filter_args=(--trace "$TRACE_ID")
elif [ -n "$SESSION_ID" ]; then
  label="session-$SESSION_ID"
  filter_args=(--session "$SESSION_ID")
fi

safe_label="$(printf '%s' "$label" | tr -c 'A-Za-z0-9_.-' '_')"
events_json="$OUT_DIR/${safe_label}-galeed-events.json"
observations_jsonl="$OUT_DIR/${safe_label}-cairn-observations.jsonl"
report_md="$OUT_DIR/${safe_label}-cairn-report.md"

echo "==> 1/2  Export Galeed events from $MONGO_DB"
galeed events "${filter_args[@]}" --limit "$LIMIT" --json \
  --mongo-uri "$MONGO_URI" --mongo-db "$MONGO_DB" > "$events_json"

echo "==> 2/2  Analyse with Cairn"
cairn-galeed-observe "$events_json" \
  --title "$TITLE" \
  --observations-output "$observations_jsonl" \
  --output "$report_md"

echo "Galeed export:       $events_json"
echo "Cairn observations:  $observations_jsonl"
echo "Cairn report:        $report_md"
