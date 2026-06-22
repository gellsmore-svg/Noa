#!/usr/bin/env python3
"""Noa MVP end-to-end proof — STUB (needs the Stage 4 Tirzah->Mahalath seam).

The acceptance test for the minimum viable stack (report §6): prove semantic
precision is *used*, not merely stored. Runs the workflow twice and diffs:

    1. Ingest a passage with an ambiguous key term into Tirzah.
    2. Tirzah stores it, retrieves context for a query.
    3. Tirzah -> Mahalath: resolve key terms to MPL label + definition-context.
    4. Hoglah serialises the answer call, conditioned on the resolved sense.
    5. Output = answer + the MPL sense(s) used.

Acceptance (A/B): with `--semantic on` the answer must visibly disambiguate and
name the MPL sense that the `--semantic off` run misses. Identical output = the
MVP is NOT met (precision was only stored).

BLOCKED ON: `annotate_with_mahalath()` on Tirzah's retrieval path (Stage 4). Until
that exists this script only prints what it will assert.
"""

import argparse
import sys


def main() -> int:
    ap = argparse.ArgumentParser(description="Noa semantic A/B smoke (stub)")
    ap.add_argument("--semantic", choices=["on", "off"], default="on")
    args = ap.parse_args()

    print(f"[semantic_smoke] mode=--semantic {args.semantic}")
    print("[semantic_smoke] STUB: the Tirzah->Mahalath seam (Stage 4) is not built yet.")
    print("[semantic_smoke] When it is: assert the --semantic on run names an MPL sense")
    print("[semantic_smoke] the --semantic off run does not. See docs/STACK-READINESS-REPORT.md §6.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
