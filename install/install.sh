#!/usr/bin/env bash
# Noa install — bring the local stack up from pinned versions.
# Hybrid runtime (report §3): Mongo in Docker, Ollama on host, tools via pipx.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [ ! -f .env ]; then
  echo "No .env found — copy .env.example to .env and edit it first." >&2
  exit 1
fi
set -a && . ./.env && set +a

echo "==> 1/3  MongoDB (docker compose)"
docker compose up -d mongo

echo "==> 2/3  Tools (pipx, from versions.lock)"
command -v pipx >/dev/null 2>&1 || { echo "pipx not installed: python -m pip install --user pipx" >&2; exit 1; }
# Today: install from the local repos named in versions.lock. Switch to
# `git+https://github.com/gellsmore-svg/<repo>@v<version>` or PyPI once published.
grep -vE '^\s*#|^\s*$' versions.lock | while read -r tool version path; do
  repo="${path/#\~/$HOME}"
  echo "    $tool $version  <-  $repo"
  pipx install --force "$repo" >/dev/null
done

echo "==> 3/3  Health"
"$ROOT/health/healthcheck.sh" || {
  echo "Healthcheck reported problems — see above." >&2; exit 1; }

echo "Done. Stack is up."
