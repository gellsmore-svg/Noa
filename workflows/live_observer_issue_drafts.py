#!/usr/bin/env python3
"""Draft GitHub issues from repeated Noa live-observer findings."""

from __future__ import annotations

import argparse
import json
import re
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path


SLUG_RE = re.compile(r"[^a-z0-9]+")
RISK_ORDER = {"not observed": 0, "low": 1, "moderate": 2, "high": 3, "critical": 4}


@dataclass(frozen=True)
class FindingEvidence:
    report_path: str
    title: str
    events: int
    risk: str


def risk_level(risk: str) -> str:
    return risk.split(" ", 1)[0].strip().lower() or "not observed"


def risk_rank(risk: str) -> int:
    return RISK_ORDER.get(risk_level(risk), 0)


def slugify(value: str) -> str:
    slug = SLUG_RE.sub("-", value.lower()).strip("-")
    return slug[:80] or "live-observer-finding"


def load_index(path: Path) -> list[dict]:
    if not path.exists():
        raise FileNotFoundError(f"live observer index not found: {path}")
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise ValueError("live observer index JSON must contain a list")
    return data


def group_findings(reports: list[dict]) -> dict[str, list[FindingEvidence]]:
    grouped: dict[str, list[FindingEvidence]] = defaultdict(list)
    for report in reports:
        for finding in report.get("findings", []):
            grouped[str(finding)].append(
                FindingEvidence(
                    report_path=str(report.get("path", "")),
                    title=str(report.get("title", "")),
                    events=int(report.get("events", 0) or 0),
                    risk=str(report.get("risk", "not observed")),
                )
            )
    return grouped


def render_issue(finding: str, evidence: list[FindingEvidence]) -> str:
    total_events = sum(item.events for item in evidence)
    highest = max(evidence, key=lambda item: risk_rank(item.risk)).risk
    lines = [
        f"# Live observer: {finding}",
        "",
        "## Why This Matters",
        "",
        (
            f"Cairn has observed `{finding}` across {len(evidence)} live-observer "
            f"report(s), covering {total_events} event(s). Highest observed risk: {highest}."
        ),
        "",
        "## Evidence",
        "",
    ]
    for item in evidence:
        lines.append(f"- `{item.report_path}` - {item.events} event(s), risk {item.risk}")
        if item.title:
            lines.append(f"  Title: {item.title}")

    lines.extend(
        [
            "",
            "## Suggested Next Step",
            "",
            "Review the linked reports, confirm whether the repeated finding is still valid, and decide whether the mitigation belongs in product behavior, operator workflow, or documentation.",
            "",
            "## Labels",
            "",
            "`cairn`, `live-observer`, `human-factors`",
            "",
        ]
    )
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--index",
        default="reports/live-observer/scheduled/index.json",
        help="Live observer index JSON path.",
    )
    parser.add_argument(
        "--out-dir",
        default=None,
        help="Directory for Markdown drafts. Default: <index parent>/issue-drafts.",
    )
    parser.add_argument(
        "--min-count",
        type=int,
        default=2,
        help="Minimum report count before a finding gets an issue draft.",
    )
    parser.add_argument(
        "--min-risk",
        default="moderate",
        choices=sorted(RISK_ORDER),
        help="Minimum highest observed risk before a finding gets an issue draft.",
    )
    args = parser.parse_args(argv)

    index_path = Path(args.index)
    out_dir = Path(args.out_dir) if args.out_dir else index_path.parent / "issue-drafts"
    min_risk_rank = RISK_ORDER[args.min_risk]
    grouped = group_findings(load_index(index_path))

    out_dir.mkdir(parents=True, exist_ok=True)
    drafted = 0
    for finding, evidence in sorted(grouped.items()):
        if len(evidence) < args.min_count:
            continue
        if max(risk_rank(item.risk) for item in evidence) < min_risk_rank:
            continue
        draft = out_dir / f"{slugify(finding)}.md"
        draft.write_text(render_issue(finding, evidence), encoding="utf-8")
        drafted += 1
        print(f"Issue draft: {draft}")

    print(f"Issue drafts written: {drafted}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
