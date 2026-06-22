#!/usr/bin/env bash
# Integrated ingestion: Mahalath ingests + extracts the document's ontology terms
# FIRST, then Tirzah ingests the SAME document. Ordering matters — Tirzah retrieval
# resolves its context against Mahalath's MPL terms (the semantic seam), so the
# terms must exist before Tirzah's memory is queried.
#
# Usage: ./workflows/ingest_document.sh <file.md> [max_terms]
# Requires the stack installed (install.sh) with the Hoglah worker running, so
# Mahalath's term extraction has a real model to call.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$ROOT/.env" ] && { set -a; . "$ROOT/.env"; set +a; }

FILE="${1:-}"
MAX_TERMS="${2:-12}"
[ -n "$FILE" ] && [ -f "$FILE" ] || { echo "usage: ingest_document.sh <file.md> [max_terms]" >&2; exit 1; }

command -v mahalath >/dev/null || { echo "mahalath not on PATH — run install.sh first." >&2; exit 1; }
command -v tirzah   >/dev/null || { echo "tirzah not on PATH — run install.sh first." >&2; exit 1; }

echo "==> 1/2  Mahalath: ingest + extract ontology terms"
out="$(mahalath ingest-one "$FILE")"
echo "$out"
doc_id="$(printf '%s' "$out" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("document_id",""))')"
[ -n "$doc_id" ] || { echo "could not read document_id from mahalath ingest-one output" >&2; exit 1; }
echo "    document_id = $doc_id"
mahalath process-document "$doc_id" --max-terms "$MAX_TERMS"

echo "==> 2/2  Tirzah: ingest the SAME document"
tirzah ingest-one "$FILE"

echo "Done. Tirzah retrieval over this document now resolves Mahalath's extracted MPL terms."
echo "Try:  tirzah ask --query '<a question about the document>'"
