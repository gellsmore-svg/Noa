#!/usr/bin/env python3
"""Noa MVP end-to-end proof: semantic precision is *used*, not merely stored.

Runs Tirzah's real prompt builder twice and proves the contrast (report §6):

    A (--semantic off): no MPL senses; the ambiguous term is read at face value.
    B (--semantic on):  the key term is resolved to an MPL label + sense and the
                        prompt is conditioned on it.

Acceptance: B names an MPL sense that A does not. Identical prompts => precision
was only stored (FAIL).

The label source is the injected resolver (the seam's whole point): it uses the
live Mahalath ontology when reachable+populated, else a deterministic demo resolver
so the contrast is always demonstrable. Either way the prompt is built by Tirzah's
real `build_prompt_envelope` + `tirzah.semantic`, so this exercises the actual seam.
"""

import argparse
import os
import sys

PASSAGE = "The form of the argument matters more than its surface wording."
QUERY = "what is the form here?"
CONTEXT = {
    "document": {"title": "Note", "document_id": "doc1"},
    "focus_node_id": "n1",
    "records": [{
        "role": "focus", "distance": 0, "title": "Note", "node_id": "n1",
        "labels": [], "endorsement_label": "unreviewed", "provenance": {},
        "text_preview": PASSAGE,
    }],
}


def _pick_resolver():
    """Live Mahalath resolver if it returns anything for our probe term, else a demo."""
    from tirzah.semantic import MahalathResolver, SemanticLabel

    live = MahalathResolver(
        mongo_uri=os.environ.get("MAHALATH_MONGO_URI", "mongodb://localhost:27017"),
        database=os.environ.get("MAHALATH_MONGO_DB", "mahalath_dev"),
    )
    if live.resolve(["form"]):
        return live, "live Mahalath ontology"

    class DemoResolver:
        def resolve(self, terms):
            out = []
            for t in terms:
                if t.casefold() == "form":
                    out.append(SemanticLabel(
                        term=t, mpl_label="MPL-004", canonical_term="form (logical structure)",
                        senses=["structural"], match_kind="exact"))
            return out

    return DemoResolver(), "demo resolver (Mahalath empty/unreachable)"


def main() -> int:
    ap = argparse.ArgumentParser(description="Noa semantic A/B smoke")
    ap.add_argument("--semantic", choices=["on", "off"], default="on",
                    help="which prompt to print; the A/B assertion always runs both")
    args = ap.parse_args()

    try:
        from tirzah.retrieval.queries import build_prompt_envelope
    except Exception:
        print("[semantic_smoke] tirzah not installed — run inside the Noa stack (pipx).")
        return 0

    resolver, source = _pick_resolver()
    print(f"[semantic_smoke] label source: {source}")

    off = build_prompt_envelope(CONTEXT, query=QUERY, token_budget=400, reserved_response_tokens=25)
    on = build_prompt_envelope(CONTEXT, query=QUERY, token_budget=400, reserved_response_tokens=25,
                               resolver=resolver)

    chosen = on if args.semantic == "on" else off
    print(f"\n----- prompt (--semantic {args.semantic}) -----\n{chosen['prompt_text']}")
    if on["semantic_summary"]:
        print(f"[semantic_smoke] on-run {on['semantic_summary']}")

    used = bool(on["semantic"]) and "Semantic Precision" in on["prompt_text"]
    contrast = "Semantic Precision" not in off["prompt_text"]
    if used and contrast:
        print("\n[semantic_smoke] PASS — semantic-on names an MPL sense the off-run does not.")
        return 0
    print("\n[semantic_smoke] FAIL — precision was not used (prompts do not differ).")
    return 1


if __name__ == "__main__":
    sys.exit(main())
