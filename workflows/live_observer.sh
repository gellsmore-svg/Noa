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
ALLOW_EMPTY=false

usage() {
  cat <<'EOF'
Usage: workflows/live_observer.sh [--trace TRACE_ID | --session SESSION_ID] [options]

Options:
  --trace ID       Export Galeed events for one trace.
  --session ID     Export Galeed events for one session.
  --limit N        Max events to export from Galeed. Default: 200.
  --title TEXT     Report title. Default: "Noa live observer".
  --out-dir DIR    Output directory. Default: reports/live-observer.
  --allow-empty    Produce an empty report when Galeed returns no events.
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
    --allow-empty) ALLOW_EMPTY=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -n "$TRACE_ID" ] && [ -n "$SESSION_ID" ]; then
  echo "choose either --trace or --session, not both" >&2
  exit 2
fi

command -v galeed >/dev/null || { echo "galeed not on PATH - run install/install.sh first." >&2; exit 1; }
CAIRN_GALEED_OBSERVE="${CAIRN_GALEED_OBSERVE:-}"
if [ -z "$CAIRN_GALEED_OBSERVE" ]; then
  if command -v cairn-galeed-observe >/dev/null; then
    CAIRN_GALEED_OBSERVE="$(command -v cairn-galeed-observe)"
  elif [ -x "$HOME/domains/Cairn/.venv/bin/cairn-galeed-observe" ]; then
    CAIRN_GALEED_OBSERVE="$HOME/domains/Cairn/.venv/bin/cairn-galeed-observe"
  else
    echo "cairn-galeed-observe not on PATH - run install/install.sh first." >&2
    exit 1
  fi
fi
CAIRN_AGENT_HARNESS_PLAN="${CAIRN_AGENT_HARNESS_PLAN:-}"
if [ -z "$CAIRN_AGENT_HARNESS_PLAN" ]; then
  if command -v cairn-agent-harness-plan >/dev/null; then
    CAIRN_AGENT_HARNESS_PLAN="$(command -v cairn-agent-harness-plan)"
  elif [ -x "$HOME/domains/Cairn/.venv/bin/cairn-agent-harness-plan" ]; then
    CAIRN_AGENT_HARNESS_PLAN="$HOME/domains/Cairn/.venv/bin/cairn-agent-harness-plan"
  fi
fi

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
harness_md="$OUT_DIR/${safe_label}-cairn-agent-harness.md"

echo "==> 1/3  Export Galeed events from $MONGO_DB"
galeed events "${filter_args[@]}" --limit "$LIMIT" --json \
  --mongo-uri "$MONGO_URI" --mongo-db "$MONGO_DB" > "$events_json"
event_count="$(python3 - "$events_json" <<'PY'
import json
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8").strip()
if not text:
    print(0)
    raise SystemExit
try:
    data = json.loads(text)
except json.JSONDecodeError:
    print(sum(1 for line in text.splitlines() if line.strip()))
else:
    print(len(data) if isinstance(data, list) else 1)
PY
)"
if [ "$event_count" -eq 0 ] && [ "$ALLOW_EMPTY" != "true" ]; then
  echo "Galeed export contains no events; use --allow-empty to produce an empty report." >&2
  exit 3
fi

echo "==> 2/3  Analyse with Cairn"
"$CAIRN_GALEED_OBSERVE" "$events_json" \
  --title "$TITLE" \
  --observations-output "$observations_jsonl" \
  --output "$report_md"

if [ -n "$CAIRN_AGENT_HARNESS_PLAN" ]; then
  echo "==> 3/3  Generate Cairn agent harness guidance"
  "$CAIRN_AGENT_HARNESS_PLAN" \
    --repo "$ROOT" \
    --title "$TITLE agent harness" \
    --output-dir "$OUT_DIR" \
    --format markdown \
    --output "$harness_md"
else
  echo "cairn-agent-harness-plan not on PATH; skipping harness guidance artifact." >&2
fi

echo "Galeed export:       $events_json"
echo "Cairn observations:  $observations_jsonl"
echo "Cairn report:        $report_md"
echo "Agent harness:       $harness_md"
