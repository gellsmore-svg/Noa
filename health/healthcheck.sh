#!/usr/bin/env bash
# Noa health check — is the stack actually live? Exit non-zero if any check fails.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$ROOT/.env" ] && set -a && . "$ROOT/.env" && set +a

OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://localhost:11434}"
MONGO_URI="${MONGO_URI:-mongodb://localhost:27017}"
HOGLAH_QUEUE_DIR="${HOGLAH_QUEUE_DIR:-$HOME/ai-stack/hoglah}"

fail=0
ok()   { printf '  ok   %s\n' "$1"; }
bad()  { printf '  FAIL %s\n' "$1"; fail=1; }

echo "Noa healthcheck"

# Ollama (host, HTTP)
if curl -fsS "$OLLAMA_BASE_URL/api/tags" >/dev/null 2>&1; then
  ok "ollama reachable at $OLLAMA_BASE_URL"
else
  bad "ollama not reachable at $OLLAMA_BASE_URL"
fi

# MongoDB
if command -v mongosh >/dev/null 2>&1; then
  mongosh "$MONGO_URI" --quiet --eval 'db.runCommand({ping:1}).ok' >/dev/null 2>&1 \
    && ok "mongo responds to ping" || bad "mongo not responding ($MONGO_URI)"
else
  printf '  skip mongosh not installed (cannot ping mongo)\n'
fi

# Hoglah shared queue dir writable
if mkdir -p "$HOGLAH_QUEUE_DIR" 2>/dev/null && [ -w "$HOGLAH_QUEUE_DIR" ]; then
  ok "hoglah queue dir writable ($HOGLAH_QUEUE_DIR)"
else
  bad "hoglah queue dir not writable ($HOGLAH_QUEUE_DIR)"
fi

# CLIs on PATH
for tool in mahalath tirzah hoglah; do
  if command -v "$tool" >/dev/null 2>&1; then
    ok "$tool: $("$tool" --version 2>/dev/null | head -1)"
  else
    bad "$tool not on PATH (pipx install pending?)"
  fi
done

exit "$fail"
