#!/usr/bin/env python3
"""Publish Noa live-observer issue drafts through the GitHub CLI."""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path


DEFAULT_LABELS = ["cairn", "live-observer", "human-factors"]


def issue_title(markdown: str, fallback: str) -> str:
    for line in markdown.splitlines():
        if line.startswith("# "):
            return line[2:].strip()
    return fallback


def publish_draft(path: Path, repo: str | None, apply: bool) -> list[str]:
    body = path.read_text(encoding="utf-8")
    command = [
        "gh",
        "issue",
        "create",
        "--title",
        issue_title(body, path.stem),
        "--body-file",
        str(path),
    ]
    for label in DEFAULT_LABELS:
        command.extend(["--label", label])
    if repo:
        command.extend(["--repo", repo])

    if apply:
        subprocess.run(command, check=True)
    return command


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--draft-dir",
        default="reports/live-observer/scheduled/issue-drafts",
        help="Directory containing Markdown issue drafts.",
    )
    parser.add_argument("--repo", default=None, help="GitHub repo, e.g. owner/name.")
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Actually create GitHub issues. Default is dry-run.",
    )
    args = parser.parse_args(argv)

    draft_dir = Path(args.draft_dir)
    drafts = sorted(draft_dir.glob("*.md"))
    if not drafts:
        print(f"No issue drafts found in {draft_dir}")
        return 0

    for draft in drafts:
        command = publish_draft(draft, repo=args.repo, apply=args.apply)
        prefix = "Created" if args.apply else "Dry run"
        print(f"{prefix}: {' '.join(command)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
