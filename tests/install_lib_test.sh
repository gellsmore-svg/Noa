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
if [ "$1" = install ] && [ "${2:-}" = --help ]; then
  echo "--preinstall"   # capability probe: a modern pipx
  exit 0
fi
if [ "$1" = install ]; then
  # Record the full argv so the test can assert on --preinstall flags.
  echo "$@" >> "${MOCK_LOG:-/dev/null}"
  exit 0
fi
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

# Family libraries in the lock are built into a local wheelhouse and exposed to
# every app install via --find-links (they are not on PyPI; 'cairn' there is an
# unrelated project).
mkdir -p "$tmp/libsrc"
cat > "$tmp/libsrc/pyproject.toml" <<'TOML'
[build-system]
requires = ["setuptools>=68", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "galeed"
version = "0.1.0"

[tool.setuptools.packages.find]
where = ["src"]
TOML
mkdir -p "$tmp/libsrc/src/galeed"
touch "$tmp/libsrc/src/galeed/__init__.py"
printf 'hoglah 0.8.0 %s\ngaleed 0.1.0 %s\n' "$tmp/source" "$tmp/libsrc" > "$tmp/versions.lock"
: > "$tmp/install.log"
PATH="$tmp/bin:$PATH" VERSIONS_LOCK="$tmp/versions.lock" MOCK_VERSION=0.8.0 \
  MOCK_LOG="$tmp/install.log" install_pinned_tools "$ROOT" >/dev/null 2>&1

grep -q -- "--pip-args --find-links " "$tmp/install.log" \
  || { echo "expected --find-links wheelhouse on the hoglah install" >&2; exit 1; }
if grep -qE "install .*$tmp/libsrc\$" "$tmp/install.log"; then
  echo "family library must not be pipx-installed as an app" >&2; exit 1
fi

echo "install_lib family-library wheelhouse: pass"
