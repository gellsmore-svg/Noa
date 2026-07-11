#!/usr/bin/env bash
# Exercise Noa's actual public pipx installation topology without services.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

python3 -m venv "$tmp/bootstrap"
"$tmp/bootstrap/bin/python" -m pip install --quiet --upgrade pip pipx

export HOME="$tmp/home"
export PIPX_HOME="$tmp/pipx"
export PIPX_BIN_DIR="$tmp/bin"
export PIPX_DEFAULT_PYTHON="$tmp/bootstrap/bin/python"
export PATH="$tmp/bootstrap/bin:$tmp/bin:/usr/local/bin:/usr/bin:/bin"
export VERSIONS_LOCK="$ROOT/versions.git.lock"
mkdir -p "$HOME" "$PIPX_HOME" "$PIPX_BIN_DIR"

. "$ROOT/install/lib.sh"
install_pinned_tools "$ROOT"
inject_galeed "$ROOT"
install_galeed_app "$ROOT"
install_keturah_app "$ROOT"
inject_tirzah_into_keturah "$ROOT"
inject_milcah_into_keturah "$ROOT"
inject_hanani_into_keturah "$ROOT"
install_cairn_app "$ROOT"
inject_mahalath_into_tirzah "$ROOT"
inject_hoglah_into_tirzah "$ROOT"

for tool in mahalath tirzah hoglah milcah hanani galeed cairn-galeed-observe cairn-agent-harness-plan keturah-mcp; do
  "$PIPX_BIN_DIR/$tool" --help >/dev/null
done

mcp_responses="$tmp/keturah-mcp.jsonl"
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
  '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"hanani.ingest_and_assess","arguments":{"text":"Insurance premiums rose after strikes on port infrastructure resumed last month. Grain transit volumes through the corridor fell fifteen percent in June.","source_id":"smoke","title":"Public MCP smoke","max_atoms":4}}}' \
  '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"hanani.map_relations","arguments":{}}}' \
  | "$PIPX_BIN_DIR/keturah-mcp" > "$mcp_responses"

"$tmp/bootstrap/bin/python" - "$mcp_responses" <<'PY'
import json
import sys

responses = {payload["id"]: payload for payload in map(json.loads, open(sys.argv[1]))}
tools = {tool["name"] for tool in responses[2]["result"]["tools"]}
expected = {
    "tirzah.search_memory",
    "tirzah.coherence_check",
    "hanani.ingest_and_assess",
    "hanani.analyze_gaps",
    "hanani.map_relations",
}
assert expected <= tools

def tool_result(request_id):
    return json.loads(responses[request_id]["result"]["content"][0]["text"])

assert tool_result(3)["atom_count"] >= 2
assert tool_result(4)["relation_count"] >= 1
PY

echo "public pipx installer smoke: pass"
