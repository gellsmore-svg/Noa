#!/usr/bin/env bash
# Verify that the public lock resolves together on a clean machine.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK="$ROOT/versions.git.lock"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

python3 -m venv "$tmp/venv"
python="$tmp/venv/bin/python"
bin="$tmp/venv/bin"
"$python" -m pip install --quiet --upgrade pip

requirements=()
while read -r tool _version source; do
  extra=""
  case "$tool" in
    hoglah) extra="[cli]" ;;
    tirzah) extra="[web]" ;;
    milcah) extra="[mongo,web,hoglah,galeed]" ;;
  esac
  requirements+=("${tool}${extra} @ ${source}")
done < <(grep -vE '^\s*#|^\s*$' "$LOCK")

"$python" -m pip install --quiet "${requirements[@]}"
"$python" -c '
import cairn, galeed, hanani, hoglah, keturah, mahalath, milcah, tirzah
from hoglah import SessionPriorityQueue
from hoglah.manifest import build_manifest
print("public lock imports: pass")
'

for tool in mahalath tirzah hoglah milcah hanani galeed cairn-galeed-observe cairn-agent-harness-plan keturah-mcp; do
  "$bin/$tool" --help >/dev/null
done

echo "public lock CLI smoke: pass"
