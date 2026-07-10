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

mcp_tools="$(printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
  | "$PIPX_BIN_DIR/keturah-mcp")"
for tool in tirzah.search_memory tirzah.coherence_check hanani.ingest_and_assess hanani.analyze_gaps hanani.map_relations; do
  grep -Fq "\"name\": \"$tool\"" <<< "$mcp_tools"
done

echo "public pipx installer smoke: pass"
