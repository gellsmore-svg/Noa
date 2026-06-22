#!/usr/bin/env python3
"""Seed a tiny demo ontology into Mahalath so the live resolver returns labels.

Inserts a few MPL entries (with polysemous senses/frames) into Mahalath's Mongo
via Mahalath's own models + repositories, so `mahalath.retrieval.search_terms`
(and therefore Tirzah's semantic seam) resolves real labels instead of falling back
to the smoke's demo resolver. Idempotent: re-running replaces the demo records.

Run inside the stack (where mahalath is installed). Honours MAHALATH_MONGO_URI /
MAHALATH_MONGO_DB (the same env Noa's .env sets).
"""

import sys

# Deterministic ids so re-runs are clean. MPL-9xx is a high range unlikely to
# collide with real entries.
CONTEXTS = [
    ("ctxdemo-structural", "structural", "the generic underlying structure or form"),
    ("ctxdemo-logical", "logical", "the form of an inference, independent of content"),
    ("ctxdemo-theological", "theological", "the grammar of creaturely existence"),
    ("ctxdemo-physical", "physical", "the configuration host for physical entities"),
]
# (mpl_label, canonical_term, aliases, [context_ids for the senses])
ENTRIES = [
    ("MPL-901", "form", ["shape"], ["ctxdemo-structural", "ctxdemo-logical"]),
    ("MPL-902", "substrate", ["medium"], ["ctxdemo-structural", "ctxdemo-theological", "ctxdemo-physical"]),
    ("MPL-903", "vorton", [], ["ctxdemo-physical"]),
]


def main() -> int:
    try:
        from mahalath.config import load_config
        from mahalath.db import ensure_indexes, get_database
        from mahalath.db.models import DefinitionContext, DefinitionVersion, OntologyEntry
        from mahalath.db.repositories import DefinitionContextRepository, OntologyEntryRepository
    except Exception as exc:  # pragma: no cover
        print(f"[seed] mahalath not importable ({exc}) — run inside the stack.")
        return 0

    db = get_database(load_config())
    ensure_indexes(db)
    ctx_repo = DefinitionContextRepository(db)
    entry_repo = OntologyEntryRepository(db)

    # Idempotent: drop the demo records first.
    db.definition_contexts.delete_many({"context_id": {"$in": [c[0] for c in CONTEXTS]}})
    db.ontology_entries.delete_many({"_id": {"$in": [e[0] for e in ENTRIES]}})

    for context_id, name, description in CONTEXTS:
        ctx_repo.insert(DefinitionContext(context_id=context_id, name=name, description=description))

    for mpl_label, term, aliases, context_ids in ENTRIES:
        definitions = [
            DefinitionVersion(text=f"{term} in the {cid.split('-')[-1]} sense.", context_id=cid)
            for cid in context_ids
        ]
        entry_repo.insert(OntologyEntry(
            mpl_label=mpl_label, canonical_term=term, aliases=aliases,
            definitions=definitions, confidence=8.0,
        ))

    # Verify the resolver path sees them.
    from mahalath.retrieval import Filters, search_terms
    matches = search_terms(db, ["form"], filters=Filters(language="en"), limit=3)
    print(f"[seed] inserted {len(CONTEXTS)} contexts + {len(ENTRIES)} entries into "
          f"{db.name}.ontology_entries")
    if matches:
        m = matches[0]
        print(f"[seed] verify: 'form' -> [{m.mpl_label}] {m.canonical_term} "
              f"senses={m.frames} kind={m.match_kind} stale={m.is_stale}")
        return 0
    print("[seed] WARNING: 'form' did not resolve — check the Mahalath store.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
