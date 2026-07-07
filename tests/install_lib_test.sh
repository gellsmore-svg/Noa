#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/install/lib.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export NOA_WHEELHOUSE="$tmp/wheelhouse"
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
if [ "$1" = inject ]; then
  echo "$@" >> "${MOCK_LOG:-/dev/null}"
  exit 0
fi
if [ "$1" = runpip ]; then
  printf 'Name: hoglah\nVersion: %s\n' "$MOCK_VERSION"
  exit 0
fi
if [ "$1" = list ]; then
  printf 'package hoglah\npackage keturah\npackage mahalath\npackage tirzah\npackage milcah\n'
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

# galeed also installs as an APP (the debugger CLI) with its cli+web extras.
: > "$tmp/install.log"
PATH="$tmp/bin:$PATH" VERSIONS_LOCK="$tmp/versions.lock" MOCK_VERSION=0.1.0 \
  MOCK_LOG="$tmp/install.log" install_galeed_app "$ROOT" >/dev/null 2>&1

grep -q -- "galeed\[cli,web\] @ file://$tmp/libsrc" "$tmp/install.log" \
  || { echo "expected galeed app install with cli,web extras" >&2; exit 1; }

mkdir -p "$tmp/stale-wheelhouse"
printf 'galeed==0.0.1\n' > "$tmp/stale-wheelhouse/family-constraints.txt"
: > "$tmp/stale-wheelhouse/galeed-0.0.1-py3-none-any.whl"
: > "$tmp/install.log"
( unset NOA_BUILT_WHEELHOUSE
  PATH="$tmp/bin:$PATH" NOA_WHEELHOUSE="$tmp/stale-wheelhouse" \
    VERSIONS_LOCK="$tmp/versions.lock" MOCK_VERSION=0.1.0 MOCK_LOG="$tmp/install.log" \
    install_galeed_app "$ROOT" >/dev/null 2>&1
)
if grep -q -- "--pip-args" "$tmp/install.log"; then
  echo "stale wheelhouse constraints must not be passed to pipx" >&2; exit 1
fi

echo "install_lib galeed app install: pass"

# keturah installs as an APP so the MCP stdio server is on PATH.
mkdir -p "$tmp/keturahsrc/src/keturah"
cat > "$tmp/keturahsrc/pyproject.toml" <<'TOML'
[build-system]
requires = ["setuptools>=68", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "keturah"
version = "0.2.0"

[project.scripts]
keturah-mcp = "keturah.mcp:main"

[tool.setuptools.packages.find]
where = ["src"]
TOML
touch "$tmp/keturahsrc/src/keturah/__init__.py"
cat > "$tmp/bin/keturah-mcp" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$tmp/bin/keturah-mcp"
printf 'hoglah 0.8.0 %s\ngaleed 0.1.0 %s\nketurah 0.2.0 %s\n' \
  "$tmp/source" "$tmp/libsrc" "$tmp/keturahsrc" > "$tmp/versions.lock"
: > "$tmp/install.log"
PATH="$tmp/bin:$PATH" VERSIONS_LOCK="$tmp/versions.lock" MOCK_VERSION=0.2.0 \
  MOCK_LOG="$tmp/install.log" install_keturah_app "$ROOT" >/dev/null 2>&1

grep -q -- "keturah @ file://$tmp/keturahsrc" "$tmp/install.log" \
  || { echo "expected keturah app install for keturah-mcp" >&2; exit 1; }

echo "install_lib keturah app install: pass"

# Keturah's MCP app venv also gets Tirzah injected, so real memory tools are
# importable to keturah-mcp instead of the demo-only fallback.
mkdir -p "$tmp/tirzahsrc/src/tirzah"
cat > "$tmp/tirzahsrc/pyproject.toml" <<'TOML'
[build-system]
requires = ["setuptools>=68", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "tirzah"
version = "1.11.0"

[tool.setuptools.packages.find]
where = ["src"]
TOML
touch "$tmp/tirzahsrc/src/tirzah/__init__.py"
printf 'hoglah 0.8.0 %s\ntirzah 1.11.0 %s\ngaleed 0.1.0 %s\nketurah 0.2.0 %s\n' \
  "$tmp/source" "$tmp/tirzahsrc" "$tmp/libsrc" "$tmp/keturahsrc" > "$tmp/versions.lock"
: > "$tmp/install.log"
unset NOA_BUILT_WHEELHOUSE
PATH="$tmp/bin:$PATH" VERSIONS_LOCK="$tmp/versions.lock" MOCK_LOG="$tmp/install.log" \
  inject_tirzah_into_keturah "$ROOT" >/dev/null 2>&1

grep -q -- "inject --force keturah .*tirzah @ file://$tmp/tirzahsrc" "$tmp/install.log" \
  || { echo "expected tirzah inject into keturah app venv" >&2; exit 1; }

echo "install_lib keturah tirzah injection: pass"

# Keturah's MCP app venv also gets Milcah injected, so the Tirzah review tool
# can import the provider path when tirzah.coherence_check is enabled.
mkdir -p "$tmp/milcahsrc/src/milcah"
cat > "$tmp/milcahsrc/pyproject.toml" <<'TOML'
[build-system]
requires = ["setuptools>=68", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "milcah"
version = "0.2.0"

[project.optional-dependencies]
hoglah = ["hoglah>=0.8.0"]
galeed = ["galeed>=0.1"]

[tool.setuptools.packages.find]
where = ["src"]
TOML
touch "$tmp/milcahsrc/src/milcah/__init__.py"
printf 'hoglah 0.8.0 %s\ntirzah 1.11.0 %s\ngaleed 0.1.0 %s\nketurah 0.2.0 %s\nmilcah 0.2.0 %s\n' \
  "$tmp/source" "$tmp/tirzahsrc" "$tmp/libsrc" "$tmp/keturahsrc" "$tmp/milcahsrc" > "$tmp/versions.lock"
: > "$tmp/install.log"
unset NOA_BUILT_WHEELHOUSE
PATH="$tmp/bin:$PATH" VERSIONS_LOCK="$tmp/versions.lock" MOCK_LOG="$tmp/install.log" \
  inject_milcah_into_keturah "$ROOT" >/dev/null 2>&1

grep -q -- "inject --force keturah .*milcah\\[hoglah,galeed\\] @ file://$tmp/milcahsrc" "$tmp/install.log" \
  || { echo "expected milcah inject into keturah app venv" >&2; exit 1; }

echo "install_lib keturah milcah injection: pass"

# cairn-lang also installs as an APP (the view composer) with its web extra, even
# though it is a family library injected into tool venvs elsewhere.
mkdir -p "$tmp/cairnsrc/src/cairn"
cat > "$tmp/cairnsrc/pyproject.toml" <<'TOML'
[build-system]
requires = ["setuptools>=68", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "cairn-lang"
version = "0.6.0"

[tool.setuptools.packages.find]
where = ["src"]
TOML
touch "$tmp/cairnsrc/src/cairn/__init__.py"
printf 'hoglah 0.8.0 %s\ngaleed 0.1.0 %s\ncairn-lang 0.6.0 %s\n' \
  "$tmp/source" "$tmp/libsrc" "$tmp/cairnsrc" > "$tmp/versions.lock"
: > "$tmp/install.log"
PATH="$tmp/bin:$PATH" VERSIONS_LOCK="$tmp/versions.lock" MOCK_VERSION=0.6.0 \
  MOCK_LOG="$tmp/install.log" install_cairn_app "$ROOT" >/dev/null 2>&1

grep -q -- "cairn-lang\[web\] @ file://$tmp/cairnsrc" "$tmp/install.log" \
  || { echo "expected cairn-lang app install with the web extra" >&2; exit 1; }

echo "install_lib cairn app install: pass"

bash -n "$ROOT/workflows/live_observer.sh"
echo "live_observer workflow syntax: pass"

# The Codex integration writes a real config.toml, preserves existing user
# settings, and remains idempotent across repeated install/upgrade runs.
cat > "$tmp/bin/galeed-codex-hook" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$tmp/bin/galeed-codex-hook"
mkdir -p "$tmp/home/.codex"
printf 'model = "gpt-5"\n' > "$tmp/home/.codex/config.toml"

( HOME="$tmp/home"; PATH="$tmp/bin:$PATH"; render_mcp_server_config >/dev/null )
( HOME="$tmp/home"; PATH="$tmp/bin:$PATH"; render_mcp_server_config >/dev/null )

grep -q -- 'model = "gpt-5"' "$tmp/home/.codex/config.toml" \
  || { echo "expected existing Codex config to be preserved" >&2; exit 1; }
grep -q -- '\[mcp_servers.keturah\]' "$tmp/home/.codex/config.toml" \
  || { echo "expected active keturah MCP server config" >&2; exit 1; }
grep -q -- "command = \"$tmp/bin/keturah-mcp\"" "$tmp/home/.codex/config.toml" \
  || { echo "expected resolved keturah-mcp command in active config" >&2; exit 1; }
grep -q -- '\[mcp_servers.keturah.tools."demo.list_tools"\]' "$tmp/home/.codex/config.toml" \
  || { echo "expected demo.list_tools approval in active config" >&2; exit 1; }
grep -q -- '\[mcp_servers.keturah.tools."demo.echo"\]' "$tmp/home/.codex/config.toml" \
  || { echo "expected demo.echo approval in active config" >&2; exit 1; }
grep -q -- '\[mcp_servers.keturah.tools."tirzah.search_memory"\]' "$tmp/home/.codex/config.toml" \
  || { echo "expected tirzah.search_memory approval in active config" >&2; exit 1; }
grep -q -- '\[mcp_servers.keturah.tools."tirzah.coherence_check"\]' "$tmp/home/.codex/config.toml" \
  || { echo "expected tirzah.coherence_check approval in active config" >&2; exit 1; }
grep -q -- '"TIRZAH_MONGO_DB" = "mnemosyne_dev"' "$tmp/home/.codex/config.toml" \
  || { echo "expected Tirzah MCP env in active config" >&2; exit 1; }
grep -q -- '"MILCAH_ENABLED" = "true"' "$tmp/home/.codex/config.toml" \
  || { echo "expected Milcah MCP env in active config" >&2; exit 1; }
grep -q -- '"HOGLAH_DB_PATH" = "' "$tmp/home/.codex/config.toml" \
  || { echo "expected Hoglah queue path env in active config" >&2; exit 1; }
grep -q -- '\[\[hooks.PostToolUse\]\]' "$tmp/home/.codex/config.toml" \
  || { echo "expected active Galeed hooks config" >&2; exit 1; }
grep -q -- 'command = ".*galeed-codex-hook PostToolUse"' "$tmp/home/.codex/config.toml" \
  || { echo "expected Galeed PostToolUse hook" >&2; exit 1; }
[ "$(grep -c '^# BEGIN Noa family Codex integration$' "$tmp/home/.codex/config.toml")" = "1" ] \
  || { echo "expected exactly one managed Codex integration block" >&2; exit 1; }
[ -f "$tmp/home/.codex/keturah-mcp.toml.example" ] \
  || { echo "expected example MCP config to be written" >&2; exit 1; }

echo "install_lib codex integration config: pass"
