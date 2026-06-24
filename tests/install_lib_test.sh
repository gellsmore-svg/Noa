#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/install/lib.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/source"
printf 'hoglah 0.8.0 %s\n' "$tmp/source" > "$tmp/versions.lock"
cat > "$tmp/bin/pipx" <<'SH'
#!/usr/bin/env bash
if [ "$1" = install ]; then exit 0; fi
if [ "$1" = runpip ]; then
  printf 'Name: hoglah\nVersion: %s\n' "$MOCK_VERSION"
  exit 0
fi
exit 0
SH
chmod +x "$tmp/bin/pipx"

PATH="$tmp/bin:$PATH" VERSIONS_LOCK="$tmp/versions.lock" MOCK_VERSION=0.8.0 \
  install_pinned_tools "$ROOT" >/dev/null

if (PATH="$tmp/bin:$PATH" VERSIONS_LOCK="$tmp/versions.lock" MOCK_VERSION=0.7.0 \
    install_pinned_tools "$ROOT" >/dev/null 2>&1); then
  echo "expected version mismatch to fail" >&2
  exit 1
fi

echo "install_lib version enforcement: pass"
