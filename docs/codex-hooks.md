# Codex Hooks Example

This repo includes a repo-local Codex hooks example for Bash tool-use events:

- config: `.codex/hooks.json`
- handler: `scripts/reportkit_codex_tool_hook.py`

It follows the current Codex hooks docs at [Hooks – Codex](https://developers.openai.com/codex/hooks):

- hooks live in `<repo>/.codex/hooks.json`
- `PreToolUse` and `PostToolUse` currently match only the `Bash` tool
- hooks require `[features] codex_hooks = true`

## What the example does

The hook listens to Bash tool-use events and turns them into a ReportKit payload with:

- `visualStyle: "progress"`
- `title: "Codex Tool Activity"`
- `summary`: the command being run or the latest command output snippet
- `progressPercent`: `15` on `PreToolUse`, `100` on `PostToolUse`
- `completedSteps` / `totalSteps`: a simple `0/1` or `1/1` example

By default it is safe and local-only:

- it writes payload snapshots to `.codex/reportkit-hooks/`
- it appends lightweight event metadata to `.codex/reportkit-hooks/tool-events.jsonl`
- it does not send a Live Activity unless you opt in

## Enable the feature

Add this to your Codex config:

```toml
[features]
codex_hooks = true
```

Codex can load hooks from either:

- `~/.codex/hooks.json`
- `<repo>/.codex/hooks.json`

This repo uses the repo-local option.

## Optional live sending

To let the hook actually publish through the existing CLI, set:

```bash
export REPORTKIT_ENABLE_HOOK_SEND=1
```

You also need the normal ReportKit CLI prerequisites:

- `reportkit` on your `PATH`
- `REPORTKIT_SUPABASE_URL`
- `REPORTKIT_SUPABASE_ANON_KEY`
- an authenticated CLI session from `reportkit auth --email ...`

When `REPORTKIT_ENABLE_HOOK_SEND` is not set to `1`, the hook only writes local payload files for inspection.

## Example generated payload

```json
{
  "event": "update",
  "activityId": "codex-tool-use",
  "payload": {
    "generatedAt": 1774000000,
    "title": "Codex Tool Activity",
    "summary": "Running Bash command: git status --short",
    "status": "warning",
    "progressPercent": 15,
    "completedSteps": 0,
    "totalSteps": 1,
    "deepLink": "reportkitsimple://codex/hooks"
  },
  "visualStyle": "progress"
}
```

## Notes

- This is an example integration, not a full Codex-run state model.
- Current Codex hooks only expose Bash tool events, so this does not yet capture non-Bash tool calls.
- The example intentionally avoids blocking commands or mutating the Codex control flow.
