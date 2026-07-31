#!/usr/bin/env python3
"""Build an operator index from Huldah live-observer Markdown reports.

The `*-cairn-report.md` suffix is unchanged: it names the observation
format (which kept the Cairn name through the Deborah/Huldah split), and
renaming it would orphan artifacts already published.
"""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from dataclasses import asdict, dataclass
from pathlib import Path


FINDING_RE = re.compile(r"^- \*\*(?P<category>[^:]+): (?P<name>[^*]+)\*\* - (?P<detail>.*)$")


@dataclass(frozen=True)
class ReportSummary:
    path: str
    harness_path: str | None
    title: str
    events: int
    risk: str
    findings: list[str]


def _relative(path: Path, root: Path) -> str:
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        return path.as_posix()


def _matching_harness_path(report_path: Path) -> Path:
    name = report_path.name
    if name.endswith("-cairn-report.md"):
        return report_path.with_name(name.removesuffix("-cairn-report.md") + "-cairn-agent-harness.md")
    return report_path.with_name(report_path.stem + "-agent-harness.md")


def parse_report(path: Path, root: Path) -> ReportSummary:
    title = path.stem
    events = 0
    risk = "not observed"
    findings: list[str] = []

    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("# "):
            title = line[2:].strip()
        elif line.startswith("Events:"):
            try:
                events = int(line.split(":", 1)[1].strip())
            except ValueError:
                events = 0
        elif line.startswith("- **"):
            match = FINDING_RE.match(line)
            if match:
                findings.append(f"{match.group('category')}: {match.group('name')}")
        elif line and not line.startswith("#") and "(probability:" in line:
            risk = line.strip()

    harness_path = _matching_harness_path(path)

    return ReportSummary(
        path=_relative(path, root),
        harness_path=_relative(harness_path, root) if harness_path.exists() else None,
        title=title,
        events=events,
        risk=risk,
        findings=findings,
    )


def load_reports(root: Path) -> list[ReportSummary]:
    reports = sorted(root.rglob("*-cairn-report.md"))
    return [parse_report(report, root) for report in reports]


def render_markdown(summaries: list[ReportSummary], root: Path) -> str:
    total_events = sum(item.events for item in summaries)
    finding_counts = Counter(finding for item in summaries for finding in item.findings)

    lines = [
        "# Noa Live Observer Index",
        "",
        f"Report root: `{root}`",
        f"Reports: {len(summaries)}",
        f"Events: {total_events}",
        "",
        "## Repeated Findings",
        "",
    ]
    if finding_counts:
        for finding, count in finding_counts.most_common():
            lines.append(f"- {finding}: {count}")
    else:
        lines.append("- none observed")

    lines.extend(["", "## Reports", ""])
    for item in summaries:
        findings = ", ".join(item.findings) if item.findings else "none observed"
        lines.append(f"- `{item.path}` - {item.events} event(s), risk {item.risk}")
        if item.harness_path:
            lines.append(f"  Agent harness: `{item.harness_path}`")
        lines.append(f"  Findings: {findings}")

    lines.append("")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        default="reports/live-observer",
        help="Directory containing live-observer reports.",
    )
    parser.add_argument(
        "--output",
        default=None,
        help="Markdown index path. Default: <root>/index.md.",
    )
    parser.add_argument(
        "--json-output",
        default=None,
        help="Optional JSON summary path. Default: <root>/index.json.",
    )
    args = parser.parse_args(argv)

    root = Path(args.root)
    output = Path(args.output) if args.output else root / "index.md"
    json_output = Path(args.json_output) if args.json_output else root / "index.json"

    summaries = load_reports(root)
    output.parent.mkdir(parents=True, exist_ok=True)
    json_output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(render_markdown(summaries, root), encoding="utf-8")
    json_output.write_text(
        json.dumps([asdict(item) for item in summaries], indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Live observer index: {output}")
    print(f"Live observer JSON:  {json_output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
