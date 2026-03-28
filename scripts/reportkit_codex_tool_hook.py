#!/usr/bin/env python3
"""Example Codex hook that turns Bash tool-use events into ReportKit payloads.

This example is intentionally safe by default:
- it always writes a payload snapshot and jsonl log under .codex/reportkit-hooks/
- it only sends a Live Activity when REPORTKIT_ENABLE_HOOK_SEND=1
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


def read_stdin_json() -> dict[str, Any]:
    raw = sys.stdin.read()
    if not raw.strip():
        return {}
    return json.loads(raw)


def repo_root() -> Path:
    root = os.environ.get("PWD")
    if root:
        return Path(root)
    return Path.cwd()


def output_dir(root: Path) -> Path:
    path = root / ".codex" / "reportkit-hooks"
    path.mkdir(parents=True, exist_ok=True)
    return path


def sanitize_command(command: str) -> str:
    command = " ".join(command.split())
    if len(command) <= 96:
        return command
    return command[:93].rstrip() + "..."


def extract_command(input_payload: dict[str, Any]) -> str:
    tool_input = input_payload.get("tool_input")
    if isinstance(tool_input, dict):
        command = tool_input.get("command")
        if isinstance(command, str):
            return command
    return ""


def decode_tool_response(input_payload: dict[str, Any]) -> str | None:
    tool_response = input_payload.get("tool_response")
    if tool_response is None:
        return None

    if isinstance(tool_response, str):
        return tool_response

    try:
        return json.dumps(tool_response, sort_keys=True)
    except TypeError:
        return str(tool_response)


def detect_status(stage: str, response_text: str | None) -> str:
    if stage == "pre":
        return "warning"

    if not response_text:
        return "good"

    lowered = response_text.lower()
    if re.search(r"\b(error|failed|exception|traceback|permission denied|not found)\b", lowered):
        return "critical"
    if re.search(r"\b(warn|warning|deprecated)\b", lowered):
        return "warning"
    return "good"


def build_summary(stage: str, command: str, response_text: str | None) -> str:
    if stage == "pre":
        return f"Running Bash command: {sanitize_command(command)}"

    if not response_text:
        return f"Finished Bash command: {sanitize_command(command)}"

    compact = " ".join(response_text.split())
    if not compact:
        return f"Finished Bash command: {sanitize_command(command)}"
    if len(compact) > 140:
        compact = compact[:137].rstrip() + "..."
    return compact


def build_progress_payload(stage: str, hook_input: dict[str, Any]) -> dict[str, Any]:
    command = extract_command(hook_input)
    response_text = decode_tool_response(hook_input)
    now = int(time.time())

    if stage == "pre":
        progress_percent = 15
        completed_steps = 0
        total_steps = 1
        title = "Codex Tool Activity"
    else:
        progress_percent = 100
        completed_steps = 1
        total_steps = 1
        title = "Codex Tool Activity"

    status = detect_status(stage, response_text)
    summary = build_summary(stage, command, response_text)

    payload = {
        "event": "update",
        "activityId": "codex-tool-use",
        "payload": {
            "generatedAt": now,
            "title": title,
            "summary": summary,
            "status": status,
            "progressPercent": progress_percent,
            "completedSteps": completed_steps,
            "totalSteps": total_steps,
            "deepLink": "reportkitsimple://codex/hooks"
        },
        "visualStyle": "progress"
    }
    return payload


def append_log(log_path: Path, record: dict[str, Any]) -> None:
    with log_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, sort_keys=True) + "\n")


def maybe_send_payload(root: Path, payload_path: Path) -> None:
    if os.environ.get("REPORTKIT_ENABLE_HOOK_SEND") != "1":
        return

    env = os.environ.copy()
    command = ["reportkit", "send", "--file", str(payload_path)]
    subprocess.run(command, cwd=root, env=env, check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main() -> int:
    stage = sys.argv[1] if len(sys.argv) > 1 else "post"
    if stage not in {"pre", "post"}:
        print(f"Unsupported hook stage: {stage}", file=sys.stderr)
        return 1

    hook_input = read_stdin_json()
    root = repo_root()
    out_dir = output_dir(root)
    payload = build_progress_payload(stage, hook_input)

    payload_path = out_dir / f"last-{stage}-tool-payload.json"
    payload_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    append_log(
        out_dir / "tool-events.jsonl",
        {
            "stage": stage,
            "createdAt": int(time.time()),
            "hookEvent": hook_input.get("hook_event_name"),
            "toolName": hook_input.get("tool_name"),
            "toolUseId": hook_input.get("tool_use_id"),
            "turnId": hook_input.get("turn_id"),
            "command": extract_command(hook_input),
            "payloadPath": str(payload_path),
        },
    )

    maybe_send_payload(root, payload_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
