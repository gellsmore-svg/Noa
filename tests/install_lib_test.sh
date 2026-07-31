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
  printf 'package hoglah\npackage keturah\npackage mahalath\npackage tirzah\npackage milcah\npackage hanani\n'
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
# every app install via --find-links (they are not on PyPI; a same-named PyPI project is an
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

# Hanani installs as an APP and is injected into Keturah's MCP venv so its
# reasoning-slice handlers are visible to coding agents.
mkdir -p "$tmp/hananisrc/src/hanani"
cat > "$tmp/hananisrc/pyproject.toml" <<'TOML'
[build-system]
requires = ["setuptools>=68", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "hanani"
version = "0.4.0"
dependencies = ["keturah>=0.1"]

[project.scripts]
hanani = "hanani.cli:main"

[tool.setuptools.packages.find]
where = ["src"]
TOML
touch "$tmp/hananisrc/src/hanani/__init__.py"
printf 'keturah 0.2.0 %s\nhanani 0.4.0 %s\n' \
  "$tmp/keturahsrc" "$tmp/hananisrc" > "$tmp/versions.lock"
: > "$tmp/install.log"
PATH="$tmp/bin:$PATH" VERSIONS_LOCK="$tmp/versions.lock" MOCK_VERSION=0.4.0 \
  MOCK_LOG="$tmp/install.log" install_pinned_tools "$ROOT" >/dev/null 2>&1
grep -q -- "install --force --pip-args .*hanani @ file://$tmp/hananisrc" "$tmp/install.log" \
  || { echo "expected hanani app install" >&2; exit 1; }

: > "$tmp/install.log"
unset NOA_BUILT_WHEELHOUSE
PATH="$tmp/bin:$PATH" VERSIONS_LOCK="$tmp/versions.lock" MOCK_LOG="$tmp/install.log" \
  inject_hanani_into_keturah "$ROOT" >/dev/null 2>&1
grep -q -- "inject --force keturah .*hanani @ file://$tmp/hananisrc" "$tmp/install.log" \
  || { echo "expected hanani inject into keturah app venv" >&2; exit 1; }

echo "install_lib hanani app and keturah injection: pass"

# deborah also installs as an APP (the view composer) with its web extra, even
# though it is a family library injected into tool venvs elsewhere.
mkdir -p "$tmp/deborahsrc/src/deborah"
cat > "$tmp/deborahsrc/pyproject.toml" <<'TOML'
[build-system]
requires = ["setuptools>=68", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "deborah"
version = "0.6.0"

[tool.setuptools.packages.find]
where = ["src"]
TOML
touch "$tmp/deborahsrc/src/deborah/__init__.py"
printf 'hoglah 0.8.0 %s\ngaleed 0.1.0 %s\ndeborah 0.9.0 %s\n' \
  "$tmp/source" "$tmp/libsrc" "$tmp/deborahsrc" > "$tmp/versions.lock"
: > "$tmp/install.log"
PATH="$tmp/bin:$PATH" VERSIONS_LOCK="$tmp/versions.lock" MOCK_VERSION=0.6.0 \
  MOCK_LOG="$tmp/install.log" install_deborah_app "$ROOT" >/dev/null 2>&1

grep -q -- "deborah\[web\] @ file://$tmp/deborahsrc" "$tmp/install.log" \
  || { echo "expected deborah app install with the web extra" >&2; exit 1; }

echo "install_lib deborah app install: pass"

bash -n "$ROOT/workflows/live_observer.sh"
echo "live_observer workflow syntax: pass"

cat > "$tmp/bin/galeed" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$MOCK_GALEED_ARGS"
if [ "${MOCK_GALEED_EMPTY:-}" = "1" ]; then
  echo "[]"
  exit 0
fi
cat <<'JSON'
[{"trace_id":"trace_demo","session_id":"sess_demo","type":"llm.call.completed","summary":"demo","metadata":{"missing_evidence":true}}]
JSON
SH
chmod +x "$tmp/bin/galeed"
cat > "$tmp/bin/huldah-galeed-observe" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$MOCK_HULDAH_ARGS"
input="$1"
shift
while [ "$#" -gt 0 ]; do
  case "$1" in
    --observations-output) observations="$2"; shift 2 ;;
    --output) report="$2"; shift 2 ;;
    --title) title="$2"; shift 2 ;;
    *) shift ;;
  esac
done
test -s "$input"
printf '{"kind":"agent_output"}\n' > "$observations"
printf '# %s\n' "$title" > "$report"
SH
chmod +x "$tmp/bin/huldah-galeed-observe"
cat > "$tmp/bin/huldah-agent-harness-plan" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$MOCK_HARNESS_ARGS"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --output) output="$2"; shift 2 ;;
    --title) title="$2"; shift 2 ;;
    *) shift ;;
  esac
done
printf '# %s\n\n## Consuming Agent Prompts\n- Use Huldah deterministic tools.\n' "$title" > "$output"
SH
chmod +x "$tmp/bin/huldah-agent-harness-plan"

observer_out="$tmp/observer"
PATH="$tmp/bin:$PATH" MOCK_GALEED_ARGS="$tmp/galeed.args" MOCK_HULDAH_ARGS="$tmp/huldah.args" \
  MOCK_HARNESS_ARGS="$tmp/harness.args" \
  "$ROOT/workflows/live_observer.sh" --trace trace_demo --limit 5 --title "Observer Test" \
  --out-dir "$observer_out" >/dev/null

grep -q -- "events --trace trace_demo --limit 5 --json" "$tmp/galeed.args" \
  || { echo "expected galeed trace export args" >&2; exit 1; }
grep -q -- "--title Observer Test" "$tmp/huldah.args" \
  || { echo "expected Huldah observer title" >&2; exit 1; }
grep -q -- "--title Observer Test agent harness" "$tmp/harness.args" \
  || { echo "expected agent harness title" >&2; exit 1; }
test -s "$observer_out/trace-trace_demo-galeed-events.json" \
  || { echo "expected Galeed export file" >&2; exit 1; }
test -s "$observer_out/trace-trace_demo-cairn-observations.jsonl" \
  || { echo "expected Huldah observations file" >&2; exit 1; }
test -s "$observer_out/trace-trace_demo-cairn-report.md" \
  || { echo "expected Huldah report file" >&2; exit 1; }
test -s "$observer_out/trace-trace_demo-cairn-agent-harness.md" \
  || { echo "expected Huldah agent harness file" >&2; exit 1; }

echo "live_observer workflow command chain: pass"

scheduled_out="$tmp/scheduled-observer"
PATH="$tmp/bin:$PATH" MOCK_GALEED_ARGS="$tmp/galeed.args" MOCK_HULDAH_ARGS="$tmp/huldah.args" \
  MOCK_HARNESS_ARGS="$tmp/harness.args" \
  NOA_OBSERVER_RUN_ID=20260708T120000Z \
  NOA_OBSERVER_SCHEDULED_OUT_DIR="$scheduled_out" \
  NOA_OBSERVER_SESSION_ID=sess_demo \
  NOA_OBSERVER_LIMIT=7 \
  NOA_OBSERVER_TITLE="Scheduled Observer Test" \
  "$ROOT/workflows/live_observer_scheduled.sh" >/dev/null

grep -q -- "events --session sess_demo --limit 7 --json" "$tmp/galeed.args" \
  || { echo "expected scheduled observer session export args" >&2; exit 1; }
grep -q -- "--title Scheduled Observer Test" "$tmp/huldah.args" \
  || { echo "expected scheduled observer title" >&2; exit 1; }
test -s "$scheduled_out/20260708T120000Z/session-sess_demo-cairn-report.md" \
  || { echo "expected scheduled observer timestamped report" >&2; exit 1; }
test -s "$scheduled_out/20260708T120000Z/session-sess_demo-cairn-agent-harness.md" \
  || { echo "expected scheduled observer timestamped harness guidance" >&2; exit 1; }
test -s "$scheduled_out/index.md" \
  || { echo "expected scheduled observer index" >&2; exit 1; }

echo "live_observer scheduled workflow: pass"

index_root="$tmp/index-root"
mkdir -p "$index_root/run-a" "$index_root/run-b"
cat > "$index_root/run-a/trace-a-cairn-report.md" <<'MD'
# Trace A

Events: 3

## Findings
- **human_load: queue vigilance load** - Observed waiting.

## Risk
moderate (probability: medium; impact: medium; confidence: medium)
MD
cat > "$index_root/run-a/trace-a-cairn-agent-harness.md" <<'MD'
# Trace A Agent Harness

## Consuming Agent Prompts
- Use deterministic Cairn tools.
MD
cat > "$index_root/run-b/trace-b-cairn-report.md" <<'MD'
# Trace B

Events: 5

## Findings
- **human_load: queue vigilance load** - Observed waiting.
- **system_reliability: long queue lifecycle** - Observed delay.

## Risk
high (probability: high; impact: medium; confidence: medium)
MD
"$ROOT/workflows/live_observer_index.py" --root "$index_root" >/dev/null
grep -q "Reports: 2" "$index_root/index.md" \
  || { echo "expected observer index report count" >&2; exit 1; }
grep -q "Events: 8" "$index_root/index.md" \
  || { echo "expected observer index event total" >&2; exit 1; }
grep -q "human_load: queue vigilance load: 2" "$index_root/index.md" \
  || { echo "expected repeated finding count" >&2; exit 1; }
grep -q 'Agent harness: `run-a/trace-a-cairn-agent-harness.md`' "$index_root/index.md" \
  || { echo "expected observer index to link harness guidance" >&2; exit 1; }
grep -q '"title": "Trace A"' "$index_root/index.json" \
  || { echo "expected observer index JSON" >&2; exit 1; }
grep -q '"harness_path": "run-a/trace-a-cairn-agent-harness.md"' "$index_root/index.json" \
  || { echo "expected observer index JSON harness path" >&2; exit 1; }

echo "live_observer index workflow: pass"

"$ROOT/workflows/live_observer_issue_drafts.py" \
  --index "$index_root/index.json" \
  --min-count 2 \
  --min-risk moderate >/dev/null
test -s "$index_root/issue-drafts/human-load-queue-vigilance-load.md" \
  || { echo "expected repeated finding issue draft" >&2; exit 1; }
grep -q "Highest observed risk: high" "$index_root/issue-drafts/human-load-queue-vigilance-load.md" \
  || { echo "expected highest risk in issue draft" >&2; exit 1; }
grep -q 'Agent harness: `run-a/trace-a-cairn-agent-harness.md`' "$index_root/issue-drafts/human-load-queue-vigilance-load.md" \
  || { echo "expected harness guidance link in issue draft" >&2; exit 1; }
test ! -e "$index_root/issue-drafts/system-reliability-long-queue-lifecycle.md" \
  || { echo "single-observation finding should not get an issue draft" >&2; exit 1; }

echo "live_observer issue draft workflow: pass"

"$ROOT/workflows/live_observer_publish_issues.py" \
  --draft-dir "$index_root/issue-drafts" \
  --repo gellsmore-svg/Noa > "$tmp/publish-dry-run.out"
grep -q "Dry run: gh issue create" "$tmp/publish-dry-run.out" \
  || { echo "expected dry-run GitHub issue command" >&2; exit 1; }
grep -q -- "--repo gellsmore-svg/Noa" "$tmp/publish-dry-run.out" \
  || { echo "expected repo in dry-run command" >&2; exit 1; }

cat > "$tmp/bin/gh" <<'SH'
#!/usr/bin/env bash
echo "$@" >> "${MOCK_GH_LOG:-/dev/null}"
exit 0
SH
chmod +x "$tmp/bin/gh"
: > "$tmp/gh.log"
PATH="$tmp/bin:$PATH" MOCK_GH_LOG="$tmp/gh.log" \
  "$ROOT/workflows/live_observer_publish_issues.py" \
  --draft-dir "$index_root/issue-drafts" \
  --repo gellsmore-svg/Noa \
  --apply >/dev/null
grep -q "issue create --title Live observer: human_load: queue vigilance load" "$tmp/gh.log" \
  || { echo "expected gh issue create invocation" >&2; exit 1; }
grep -q -- "--label cairn" "$tmp/gh.log" \
  || { echo "expected issue labels" >&2; exit 1; }

echo "live_observer issue publish workflow: pass"

rm -f "$tmp/bin/huldah-galeed-observe" "$tmp/huldah.args"
PATH="$tmp/bin:$PATH" MOCK_GALEED_ARGS="$tmp/galeed.args" MOCK_HULDAH_ARGS="$tmp/huldah.args" \
  HULDAH_GALEED_OBSERVE="$tmp/bin/missing-huldah-observe" \
  "$ROOT/workflows/live_observer.sh" --session sess_demo --out-dir "$observer_out/override" >/dev/null 2>&1 \
  && { echo "expected invalid HULDAH_GALEED_OBSERVE override to fail" >&2; exit 1; }

# The legacy CAIRN_* name is still honoured for one deprecation cycle, so an
# operator's existing .env keeps working across the Deborah/Huldah split.
PATH="$tmp/bin:$PATH" MOCK_GALEED_ARGS="$tmp/galeed.args" MOCK_HULDAH_ARGS="$tmp/huldah.args" \
  CAIRN_GALEED_OBSERVE="$tmp/bin/missing-cairn-observe" \
  "$ROOT/workflows/live_observer.sh" --session sess_demo --out-dir "$observer_out/override" >/dev/null 2>&1 \
  && { echo "expected legacy CAIRN_GALEED_OBSERVE override to still be honoured" >&2; exit 1; }

echo "live_observer workflow invalid override: pass"

cat > "$tmp/bin/huldah-galeed-observe" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$MOCK_HULDAH_ARGS"
input="$1"
shift
while [ "$#" -gt 0 ]; do
  case "$1" in
    --observations-output) observations="$2"; shift 2 ;;
    --output) report="$2"; shift 2 ;;
    --title) title="$2"; shift 2 ;;
    *) shift ;;
  esac
done
test -s "$input"
printf '{"kind":"agent_output"}\n' > "$observations"
printf '# %s\n' "$title" > "$report"
SH
chmod +x "$tmp/bin/huldah-galeed-observe"

if PATH="$tmp/bin:$PATH" MOCK_GALEED_ARGS="$tmp/galeed.args" MOCK_HULDAH_ARGS="$tmp/huldah.args" \
  MOCK_HARNESS_ARGS="$tmp/harness.args" \
  MOCK_GALEED_EMPTY=1 "$ROOT/workflows/live_observer.sh" --trace empty --out-dir "$observer_out/empty" \
  >/dev/null 2>"$tmp/empty.err"; then
  echo "expected empty Galeed export to fail without --allow-empty" >&2
  exit 1
fi
grep -q 'Galeed export contains no events' "$tmp/empty.err" \
  || { echo "expected empty export diagnostic" >&2; exit 1; }
PATH="$tmp/bin:$PATH" MOCK_GALEED_ARGS="$tmp/galeed.args" MOCK_HULDAH_ARGS="$tmp/huldah.args" \
  MOCK_HARNESS_ARGS="$tmp/harness.args" \
  MOCK_GALEED_EMPTY=1 "$ROOT/workflows/live_observer.sh" --trace empty --allow-empty \
  --out-dir "$observer_out/empty-allowed" >/dev/null

echo "live_observer workflow empty export guard: pass"

cat > "$tmp/bin/systemctl" <<'SH'
#!/usr/bin/env bash
echo "$@" >> "${MOCK_SYSTEMCTL_LOG:-/dev/null}"
if [ "$1" = "--user" ] && [ "$2" = "show-environment" ]; then
  exit 0
fi
if [ "$1" = "--user" ] && [ "$2" = "daemon-reload" ]; then
  exit 0
fi
if [ "$1" = "--user" ] && [ "$2" = "enable" ] && [ "$3" = "--now" ] && [ "$4" = "noa-live-observer.timer" ]; then
  exit 0
fi
exit 1
SH
chmod +x "$tmp/bin/systemctl"
mkdir -p "$tmp/home"
: > "$tmp/systemctl.log"
HOME="$tmp/home" PATH="$tmp/bin:$PATH" MOCK_SYSTEMCTL_LOG="$tmp/systemctl.log" \
  NOA_OBSERVER_ON_CALENDAR="*:0/15" NOA_OBSERVER_RANDOMIZED_DELAY_SEC=30s \
  install_live_observer_timer >/dev/null

grep -q -- "enable --now noa-live-observer.timer" "$tmp/systemctl.log" \
  || { echo "expected live observer timer to be enabled" >&2; exit 1; }
grep -q -- "OnCalendar=\\*:0/15" "$tmp/home/.config/systemd/user/noa-live-observer.timer" \
  || { echo "expected rendered observer timer schedule" >&2; exit 1; }
grep -q -- "ExecStart=$ROOT/workflows/live_observer_scheduled.sh" \
  "$tmp/home/.config/systemd/user/noa-live-observer.service" \
  || { echo "expected rendered observer service command" >&2; exit 1; }

echo "live_observer systemd timer install: pass"

cat > "$tmp/bin/curl" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat > "$tmp/bin/mongosh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat > "$tmp/bin/systemctl" <<'SH'
#!/usr/bin/env bash
[ "$1" = "--user" ] && [ "$2" = "is-active" ] && [ "$3" = "hoglah-worker.service" ] && exit 0
exit 1
SH
for tool in mahalath tirzah hoglah milcah galeed; do
  cat > "$tmp/bin/$tool" <<SH
#!/usr/bin/env bash
echo "$tool 0.test"
SH
done
cat > "$tmp/bin/hanani" <<'SH'
#!/usr/bin/env bash
echo "hanani 0.test"
SH
cat > "$tmp/bin/huldah-galeed-observe" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = "--help" ]; then
  echo "usage: huldah-galeed-observe"
  exit 0
fi
exit 2
SH
cat > "$tmp/bin/huldah-agent-harness-plan" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = "--help" ]; then
  echo "usage: huldah-agent-harness-plan"
  exit 0
fi
exit 2
SH
cat > "$tmp/bin/deborah-validate" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = "--help" ]; then
  echo "usage: deborah-validate"
  exit 0
fi
exit 2
SH
chmod +x "$tmp/bin"/curl "$tmp/bin"/mongosh "$tmp/bin"/systemctl \
  "$tmp/bin"/mahalath "$tmp/bin"/tirzah "$tmp/bin"/hoglah "$tmp/bin"/milcah \
  "$tmp/bin"/hanani "$tmp/bin"/galeed "$tmp/bin"/huldah-galeed-observe "$tmp/bin"/huldah-agent-harness-plan \
  "$tmp/bin"/deborah-validate

health_out="$(PATH="$tmp/bin:$PATH" "$ROOT/health/healthcheck.sh")"
printf '%s' "$health_out" | grep -q 'huldah-galeed-observe: usage: huldah-galeed-observe' \
  || { echo "expected healthcheck to fall back to --help for huldah-galeed-observe" >&2; exit 1; }
printf '%s' "$health_out" | grep -q 'huldah-agent-harness-plan: usage: huldah-agent-harness-plan' \
  || { echo "expected healthcheck to fall back to --help for huldah-agent-harness-plan" >&2; exit 1; }

echo "healthcheck CLI label fallback: pass"

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
