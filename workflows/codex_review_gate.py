#!/usr/bin/env python3
"""Run Codex behind the Noa/Cairn review gate.

Live mode:
    codex_review_gate.py --repo ~/domains/Tirzah "make the requested change"

Offline/test mode:
    codex_review_gate.py --codex-result-file run.json --review-result-file review.json "request"

The runner keeps Codex as the executor and makes acceptance a separate process
decision. It can call Milcah through the configured Keturah MCP server when the
Codex run summary or local policy marks the change as review-worthy.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import tomllib
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from uuid import uuid4

BLOCKED_EXIT = 2

OUTPUT_SCHEMA: dict[str, Any] = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "status": {"type": "string", "enum": ["completed", "blocked", "failed"]},
        "summary": {"type": "string"},
        "changed_files": {"type": "array", "items": {"type": "string"}},
        "verification": {
            "type": "array",
            "items": {
                "type": "object",
                "additionalProperties": False,
                "properties": {
                    "command": {"type": "string"},
                    "status": {"type": "string", "enum": ["passed", "failed", "not_run"]},
                    "notes": {"type": "string"},
                },
                "required": ["command", "status", "notes"],
            },
        },
        "risk": {"type": "string", "enum": ["low", "medium", "high"]},
        "review_required": {"type": "boolean"},
        "diff_summary": {"type": "string"},
    },
    "required": [
        "status",
        "summary",
        "changed_files",
        "verification",
        "risk",
        "review_required",
        "diff_summary",
    ],
}

RISKY_PATH_PATTERNS = (
    re.compile(r"(^|/)install/"),
    re.compile(r"(^|/)services/"),
    re.compile(r"(^|/)\.github/workflows/"),
    re.compile(r"(^|/)pyproject\.toml$"),
    re.compile(r"(^|/)versions(\.git)?\.lock$"),
    re.compile(r"(^|/)config(\.|/|$)"),
    re.compile(r"(^|/)migrations?/"),
    re.compile(r"(^|/)(auth|security|permissions?)(\.|/|$)", re.IGNORECASE),
)


@dataclass
class CodexRun:
    summary: dict[str, Any] | None
    events: list[dict[str, Any]]
    errors: list[str]
    returncode: int


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def normalize_list(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def normalize_summary(data: dict[str, Any]) -> dict[str, Any]:
    changed_files = [str(path) for path in normalize_list(data.get("changed_files"))]
    verification = []
    for item in normalize_list(data.get("verification")):
        if not isinstance(item, dict):
            continue
        status = str(item.get("status") or "not_run")
        if status not in {"passed", "failed", "not_run"}:
            status = "not_run"
        verification.append(
            {
                "command": str(item.get("command") or ""),
                "status": status,
                **({"notes": str(item.get("notes"))} if item.get("notes") is not None else {}),
            }
        )
    risk = str(data.get("risk") or classify_path_risk(changed_files)).lower()
    if risk not in {"low", "medium", "high"}:
        risk = classify_path_risk(changed_files)
    review_required = bool(data.get("review_required")) or risk in {"medium", "high"}
    status = str(data.get("status") or "failed").lower()
    if status not in {"completed", "blocked", "failed"}:
        status = "failed"
    return {
        "status": status,
        "summary": str(data.get("summary") or ""),
        "changed_files": changed_files,
        "verification": verification,
        "risk": risk,
        "review_required": review_required,
        "diff_summary": str(data.get("diff_summary") or ""),
    }


def classify_path_risk(paths: list[str]) -> str:
    if any(pattern.search(path) for path in paths for pattern in RISKY_PATH_PATTERNS):
        return "high"
    if len(paths) > 5:
        return "medium"
    return "low"


def extract_json_object(text: str) -> dict[str, Any] | None:
    stripped = text.strip()
    try:
        value = json.loads(stripped)
        return value if isinstance(value, dict) else None
    except json.JSONDecodeError:
        pass

    fenced = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", stripped, re.DOTALL)
    if fenced:
        try:
            value = json.loads(fenced.group(1))
            return value if isinstance(value, dict) else None
        except json.JSONDecodeError:
            pass

    decoder = json.JSONDecoder()
    for match in re.finditer(r"\{", stripped):
        try:
            value, _end = decoder.raw_decode(stripped[match.start():])
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            return value
    return None


def parse_codex_json_stream(stdout: str, returncode: int) -> CodexRun:
    events: list[dict[str, Any]] = []
    errors: list[str] = []
    agent_messages: list[str] = []
    for raw_line in stdout.splitlines():
        try:
            event = json.loads(raw_line)
        except json.JSONDecodeError:
            continue
        if not isinstance(event, dict):
            continue
        events.append(event)
        event_type = event.get("type")
        if event_type == "error" and event.get("message"):
            errors.append(str(event["message"]))
        if event_type == "turn.failed":
            error = event.get("error")
            errors.append(str(error.get("message") if isinstance(error, dict) else error))
        if event_type == "item.completed":
            item = event.get("item")
            if isinstance(item, dict) and item.get("type") == "agent_message":
                agent_messages.append(str(item.get("text") or ""))
        if event_type == "agent_message":
            agent_messages.append(str(event.get("text") or event.get("message") or ""))

    summary = None
    for text in reversed(agent_messages):
        summary = extract_json_object(text)
        if summary is not None:
            break
    return CodexRun(summary=summary, events=events, errors=errors, returncode=returncode)


def codex_stderr_errors(stderr: str) -> list[str]:
    benign = {"Reading additional input from stdin..."}
    return [line for line in (part.strip() for part in stderr.splitlines()) if line and line not in benign]


def build_codex_prompt(request: str) -> str:
    return (
        "You are running under Noa's Cairn review gate. Complete the requested "
        "coding task in the current repository, verify what you can, and return "
        "only the structured JSON required by the output schema. Include changed "
        "files, verification commands, risk, whether review is required, and a "
        f"brief diff summary.\n\nRequest:\n{request}"
    )


def run_codex(args: argparse.Namespace, schema_path: Path) -> CodexRun:
    command = [
        args.codex_bin,
        "exec",
        "--json",
        "--output-schema",
        str(schema_path),
        build_codex_prompt(args.request),
    ]
    try:
        completed = subprocess.run(
            command,
            cwd=args.repo,
            capture_output=True,
            text=True,
            timeout=args.codex_timeout,
            check=False,
        )
    except subprocess.TimeoutExpired as error:
        return CodexRun(summary=None, events=[], errors=[f"codex timed out after {error.timeout}s"], returncode=124)
    except OSError as error:
        return CodexRun(summary=None, events=[], errors=[str(error)], returncode=127)
    parsed = parse_codex_json_stream(completed.stdout, completed.returncode)
    parsed.errors.extend(codex_stderr_errors(completed.stderr))
    return parsed


def load_codex_summary(args: argparse.Namespace, schema_path: Path) -> CodexRun:
    if args.codex_result_file:
        data = load_json(Path(args.codex_result_file))
        return CodexRun(summary=data if isinstance(data, dict) else None, events=[], errors=[], returncode=0)
    return run_codex(args, schema_path)


def verification_failed(summary: dict[str, Any]) -> bool:
    return any(item.get("status") == "failed" for item in summary.get("verification", []))


def review_required(summary: dict[str, Any], mode: str) -> bool:
    if mode == "off":
        return False
    if mode == "required":
        return True
    return bool(summary.get("review_required")) or summary.get("risk") in {"medium", "high"}


def call_keturah_mcp(tool_name: str, arguments: dict[str, Any], timeout: int, config_path: Path) -> dict[str, Any]:
    try:
        config = tomllib.loads(config_path.read_text(encoding="utf-8"))
        server = config["mcp_servers"]["keturah"]
        command = [server["command"], *server.get("args", [])]
        env = os.environ.copy()
        env.update(server.get("env", {}))
    except Exception as error:
        return {"terminal_reason": "blocked", "error": f"could not load Keturah MCP config: {error}"}

    messages = [
        {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}},
        {"jsonrpc": "2.0", "method": "notifications/initialized"},
        {"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": tool_name, "arguments": arguments}},
    ]
    payload = "".join(json.dumps(message) + "\n" for message in messages)
    try:
        completed = subprocess.run(
            command,
            input=payload,
            capture_output=True,
            text=True,
            env=env,
            timeout=timeout,
            check=False,
        )
    except subprocess.TimeoutExpired:
        return {"terminal_reason": "blocked", "error": f"{tool_name} timed out after {timeout}s"}
    except OSError as error:
        return {"terminal_reason": "blocked", "error": str(error)}

    for raw_line in completed.stdout.splitlines():
        try:
            message = json.loads(raw_line)
        except json.JSONDecodeError:
            continue
        if message.get("id") != 2:
            continue
        if "error" in message:
            return {"terminal_reason": "blocked", "error": message["error"]}
        content = (message.get("result") or {}).get("content") or []
        text = content[0].get("text") if content and isinstance(content[0], dict) else ""
        value = extract_json_object(str(text))
        return value or {"terminal_reason": "blocked", "error": str(text)}
    return {"terminal_reason": "blocked", "error": "Keturah MCP returned no tool result"}


def review_context(request: str, summary: dict[str, Any]) -> str:
    return json.dumps(
        {
            "request": request,
            "summary": summary.get("summary", ""),
            "changed_files": summary.get("changed_files", []),
            "verification": summary.get("verification", []),
            "risk": summary.get("risk", ""),
            "diff_summary": summary.get("diff_summary", ""),
        },
        indent=2,
        sort_keys=True,
    )


def run_review(args: argparse.Namespace, summary: dict[str, Any]) -> dict[str, Any]:
    if args.review_result_file:
        data = load_json(Path(args.review_result_file))
        return data if isinstance(data, dict) else {"terminal_reason": "blocked", "error": "review result is not an object"}
    return call_keturah_mcp(
        "tirzah.coherence_check",
        {
            "query": f"Pressure-test this coding change before acceptance: {args.request}",
            "context": review_context(args.request, summary),
            "mode": "coherence",
        },
        timeout=args.review_timeout,
        config_path=Path(args.codex_config),
    )


def review_blocks(report: dict[str, Any], objections_policy: str) -> bool:
    terminal = str(report.get("terminal_reason") or "")
    if terminal in {"blocked", "insufficient_evidence"}:
        return True
    objections = report.get("objections") or []
    return objections_policy == "block" and bool(objections)


def gate(args: argparse.Namespace, codex_run: CodexRun) -> tuple[int, dict[str, Any]]:
    if codex_run.summary is None:
        result = {
            "status": "failed",
            "reason": "codex_summary_unavailable",
            "errors": codex_run.errors,
            "codex_returncode": codex_run.returncode,
        }
        return (BLOCKED_EXIT, result)

    summary = normalize_summary(codex_run.summary)
    result: dict[str, Any] = {
        "status": "pending",
        "codex": summary,
        "errors": codex_run.errors,
        "review_required": review_required(summary, args.review_mode),
        "review_report": None,
    }
    if codex_run.returncode != 0 or codex_run.errors:
        result["status"] = "failed"
        result["reason"] = "codex_failed"
        result["codex_returncode"] = codex_run.returncode
        return (BLOCKED_EXIT, result)
    if summary["status"] != "completed":
        result["status"] = "blocked"
        result["reason"] = f"codex_status_{summary['status']}"
        return (BLOCKED_EXIT, result)
    if verification_failed(summary):
        result["status"] = "blocked_by_verification"
        result["reason"] = "verification_failed"
        return (BLOCKED_EXIT, result)
    if not result["review_required"]:
        result["status"] = "accepted_without_review"
        return (0, result)

    review_report = run_review(args, summary)
    result["review_report"] = review_report
    if review_blocks(review_report, args.review_objections):
        result["status"] = "blocked_by_review"
        result["reason"] = "review_objections_or_terminal_reason"
        return (BLOCKED_EXIT, result)
    result["status"] = "accepted_with_review"
    return (0, result)


def new_run_id() -> str:
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return f"codex-gate-{timestamp}-{uuid4().hex[:8]}"


def artifact_dir(args: argparse.Namespace) -> Path | None:
    if args.no_artifact:
        return None
    configured = args.artifact_dir or os.environ.get("NOA_CODEX_GATE_ARTIFACT_DIR")
    return Path(configured).expanduser() if configured else Path.home() / ".noa" / "codex-review-runs"


def write_artifact(
    args: argparse.Namespace,
    *,
    run_id: str,
    codex_run: CodexRun,
    result: dict[str, Any],
    exit_code: int,
) -> None:
    directory = artifact_dir(args)
    if directory is None:
        return
    payload = {
        "run_id": run_id,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "request": args.request,
        "repo": str(Path(args.repo).expanduser()),
        "review_mode": args.review_mode,
        "review_objections": args.review_objections,
        "exit_code": exit_code,
        "codex_returncode": codex_run.returncode,
        "codex_events": codex_run.events,
        "result": result,
    }
    try:
        directory.mkdir(parents=True, exist_ok=True)
        path = directory / f"{run_id}.json"
        path.write_text(json.dumps(payload, indent=2, sort_keys=True, default=str), encoding="utf-8")
        result["artifact_path"] = str(path)
    except OSError as error:
        result["artifact_error"] = str(error)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run Codex behind the Noa/Cairn review gate.")
    parser.add_argument("request", help="Coding request to pass to Codex or record with offline results.")
    parser.add_argument("--repo", default=os.getcwd(), help="Repository/workspace where Codex runs.")
    parser.add_argument("--codex-bin", default="codex", help="Codex CLI executable.")
    parser.add_argument("--codex-timeout", type=int, default=3600, help="Seconds to wait for codex exec.")
    parser.add_argument("--review-timeout", type=int, default=300, help="Seconds to wait for Milcah review.")
    parser.add_argument("--review-mode", choices=["auto", "required", "off"], default="auto")
    parser.add_argument("--review-objections", choices=["block", "warn"], default="block")
    parser.add_argument("--codex-config", default=str(Path.home() / ".codex" / "config.toml"))
    parser.add_argument("--codex-result-file", help="Offline summary JSON; skips codex exec.")
    parser.add_argument("--review-result-file", help="Offline Milcah result JSON; skips MCP review.")
    parser.add_argument("--artifact-dir", help="Directory for gate audit JSON artifacts.")
    parser.add_argument("--no-artifact", action="store_true", help="Do not write a gate audit artifact.")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    with tempfile.NamedTemporaryFile("w", suffix=".schema.json", encoding="utf-8", delete=False) as handle:
        json.dump(OUTPUT_SCHEMA, handle)
        schema_path = Path(handle.name)
    try:
        codex_run = load_codex_summary(args, schema_path)
        exit_code, result = gate(args, codex_run)
    finally:
        try:
            schema_path.unlink()
        except OSError:
            pass
    run_id = new_run_id()
    result["run_id"] = run_id
    write_artifact(args, run_id=run_id, codex_run=codex_run, result=result, exit_code=exit_code)
    print(json.dumps(result, indent=2, sort_keys=True))
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
