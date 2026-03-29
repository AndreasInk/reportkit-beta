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
import shutil
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


def thread_state_dir(out_dir: Path) -> Path:
    path = out_dir / "threads"
    path.mkdir(parents=True, exist_ok=True)
    return path


def sanitize_thread_id(raw: str) -> str:
    sanitized = re.sub(r"[^A-Za-z0-9_-]+", "-", raw).strip("-")
    if not sanitized:
        return "default"
    return sanitized[:64]


def activity_context(stage: str, hook_input: dict[str, Any], out_dir: Path) -> tuple[str, str]:
    thread_id = str(hook_input.get("turn_id") or "").strip()
    if not thread_id:
        return ("start" if stage == "pre" else "update", "codex-tool-use")

    sanitized_thread_id = sanitize_thread_id(thread_id)
    activity_id = f"codex-thread-{sanitized_thread_id}"
    state_path = thread_state_dir(out_dir) / f"{sanitized_thread_id}.json"

    if state_path.exists():
        return ("update", activity_id)

    if stage == "pre":
        state_path.write_text(
            json.dumps({"activityId": activity_id, "threadId": thread_id, "createdAt": int(time.time())}) + "\n",
            encoding="utf-8",
        )
        return ("start", activity_id)

    return ("update", activity_id)


def read_project_environment_file(root: Path) -> dict[str, str]:
    environment_path = root / ".codex" / "environments" / "environment.toml"
    if not environment_path.exists():
        return {}

    env: dict[str, str] = {}
    for line in environment_path.read_text(encoding="utf-8").splitlines():
        match = re.match(r'^\s*([A-Z0-9_]+)="(.*)"\s*$', line)
        if not match:
            continue
        key, value = match.groups()
        env[key] = value
    return env


def merge_reportkit_env(root: Path) -> dict[str, str]:
    env = os.environ.copy()
    fallback_env = read_project_environment_file(root)
    for key in ("REPORTKIT_SUPABASE_URL", "REPORTKIT_SUPABASE_ANON_KEY"):
        if env.get(key):
            continue
        if fallback_env.get(key):
            env[key] = fallback_env[key]
    return env


def reportkit_send_command(root: Path) -> list[str] | None:
    installed = shutil.which("reportkit")
    if installed:
        return [installed, "send"]

    local_cli = root / "cli" / "dist" / "src" / "index.js"
    if local_cli.exists() and shutil.which("node"):
        return ["node", str(local_cli), "send"]

    return None


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


def maybe_send_payload(root: Path, payload_path: Path, out_dir: Path) -> None:
    if os.environ.get("REPORTKIT_ENABLE_HOOK_SEND") == "0":
        append_log(
            out_dir / "send-results.jsonl",
            {
                "createdAt": int(time.time()),
                "payloadPath": str(payload_path),
                "sent": False,
                "reason": "REPORTKIT_ENABLE_HOOK_SEND explicitly disabled",
            },
        )
        return

    command = reportkit_send_command(root)
    if command is None:
        append_log(
            out_dir / "send-results.jsonl",
            {
                "createdAt": int(time.time()),
                "payloadPath": str(payload_path),
                "sent": False,
                "reason": "reportkit command unavailable",
            },
        )
        return

    env = merge_reportkit_env(root)
    command = [*command, "--file", str(payload_path)]
    result = subprocess.run(
        command,
        cwd=root,
        env=env,
        check=False,
        capture_output=True,
        text=True,
    )
    append_log(
        out_dir / "send-results.jsonl",
        {
            "createdAt": int(time.time()),
            "payloadPath": str(payload_path),
            "sent": result.returncode == 0,
            "returncode": result.returncode,
            "stdout": result.stdout.strip(),
            "stderr": result.stderr.strip(),
        },
    )


def main() -> int:
    stage = sys.argv[1] if len(sys.argv) > 1 else "post"
    if stage not in {"pre", "post"}:
        print(f"Unsupported hook stage: {stage}", file=sys.stderr)
        return 1

    hook_input = read_stdin_json()
    root = repo_root()
    out_dir = output_dir(root)
    payload = build_progress_payload(stage, hook_input)
    event, activity_id = activity_context(stage, hook_input, out_dir)
    payload["event"] = event
    payload["activityId"] = activity_id

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

    maybe_send_payload(root, payload_path, out_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
