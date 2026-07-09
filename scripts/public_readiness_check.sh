#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
  echo "public_readiness_check: $*" >&2
  exit 1
}

echo "public_readiness_check: checking license"
test -f LICENSE || fail "LICENSE is missing"
grep -q "Apache License" LICENSE || fail "LICENSE does not look like Apache License 2.0"

echo "public_readiness_check: checking tracked generated/private files"
tracked_bad="$(git ls-files | grep -E '(^|/)__pycache__|\.pyc$|^reports/|(^|/)\.env$|(^|/)backups/' || true)"
if [ -n "$tracked_bad" ]; then
  printf '%s\n' "$tracked_bad" >&2
  fail "generated or private files are tracked"
fi

echo "public_readiness_check: checking personal path markers"
personal_markers="$(git grep -n -E '/home/cello|/mnt/c/Users/cello|C:\\Users\\cello' -- . || true)"
if [ -n "$personal_markers" ]; then
  printf '%s\n' "$personal_markers" >&2
  fail "personal machine paths remain in tracked files"
fi

echo "public_readiness_check: checking stale private wording"
private_markers="$(git grep -n -E 'Noa itself is private|it is private|private repo|private repository' -- . || true)"
if [ -n "$private_markers" ]; then
  printf '%s\n' "$private_markers" >&2
  fail "stale private-repo wording remains in tracked files"
fi

if [ "${NOA_PUBLIC_CHECK_NETWORK:-0}" = "1" ]; then
  echo "public_readiness_check: checking versions.git.lock refs"
  while read -r name _version source; do
    case "${name:-}" in
      ""|\#*) continue ;;
    esac
    url="${source%@*}"
    ref="${source##*@}"
    url="${url#git+}"
    refs="$(git ls-remote "$url")" || fail "unreachable repository for $name: $url"
    if [[ "$ref" =~ ^[0-9a-f]{7,40}$ ]]; then
      printf '%s\n' "$refs" | grep -q "^$ref" \
        || fail "commit pin is not advertised for $name: $source"
    else
      printf '%s\n' "$refs" | awk '{print $2}' | grep -qx "refs/tags/$ref\|refs/heads/$ref\|$ref" \
        || fail "named ref is not advertised for $name: $source"
    fi
  done < versions.git.lock
else
  echo "public_readiness_check: skipping network ref checks; set NOA_PUBLIC_CHECK_NETWORK=1 to enable"
fi

echo "public_readiness_check: pass"
