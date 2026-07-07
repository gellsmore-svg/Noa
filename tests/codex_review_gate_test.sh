#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/low.json" <<'JSON'
{
  "status": "completed",
  "summary": "Updated one documentation line.",
  "changed_files": ["README.md"],
  "verification": [{"command": "not run", "status": "not_run"}],
  "risk": "low",
  "review_required": false,
  "diff_summary": "Documentation-only change."
}
JSON

out="$("$ROOT/workflows/codex_review_gate.py" --repo "$tmp" --codex-result-file "$tmp/low.json" "doc update")"
printf '%s' "$out" | python3 -c 'import json,sys; data=json.load(sys.stdin); assert data["status"] == "accepted_without_review"'

cat > "$tmp/high.json" <<'JSON'
{
  "status": "completed",
  "summary": "Changed installer review wiring.",
  "changed_files": ["install/lib.sh"],
  "verification": [{"command": "bash tests/install_lib_test.sh", "status": "passed"}],
  "risk": "high",
  "review_required": true,
  "diff_summary": "Installer now approves an MCP review tool."
}
JSON

cat > "$tmp/review.json" <<'JSON'
{
  "terminal_reason": "max_iterations",
  "confidence": 0.42,
  "claims": ["The change wires the review path."],
  "objections": ["The approval may run an expensive review unexpectedly."],
  "evidence": ["Installer diff"]
}
JSON

if "$ROOT/workflows/codex_review_gate.py" --repo "$tmp" \
    --codex-result-file "$tmp/high.json" --review-result-file "$tmp/review.json" \
    "installer update" > "$tmp/blocked.out"; then
  echo "expected review objections to block by default" >&2
  exit 1
fi
printf '%s' "$(cat "$tmp/blocked.out")" \
  | python3 -c 'import json,sys; data=json.load(sys.stdin); assert data["status"] == "blocked_by_review"'

out="$("$ROOT/workflows/codex_review_gate.py" --repo "$tmp" --review-objections warn \
  --codex-result-file "$tmp/high.json" --review-result-file "$tmp/review.json" "installer update")"
printf '%s' "$out" | python3 -c 'import json,sys; data=json.load(sys.stdin); assert data["status"] == "accepted_with_review"'

cat > "$tmp/failed-test.json" <<'JSON'
{
  "status": "completed",
  "summary": "Changed code but tests failed.",
  "changed_files": ["src/app.py"],
  "verification": [{"command": "pytest", "status": "failed"}],
  "risk": "medium",
  "review_required": true,
  "diff_summary": "Code change."
}
JSON

if "$ROOT/workflows/codex_review_gate.py" --repo "$tmp" \
    --codex-result-file "$tmp/failed-test.json" --review-result-file "$tmp/review.json" \
    "code update" > "$tmp/failed.out"; then
  echo "expected failed verification to block before review" >&2
  exit 1
fi
printf '%s' "$(cat "$tmp/failed.out")" \
  | python3 -c 'import json,sys; data=json.load(sys.stdin); assert data["status"] == "blocked_by_verification"; assert data["review_report"] is None'

echo "codex_review_gate: pass"
