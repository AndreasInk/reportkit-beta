# ReportKit CLI

ReportKit Beta puts important app and ops signals into an iPhone Live Activity from the command line.

Minimal ReportKit CLI for:

- signing the CLI into Supabase
- sharing the same account as the iPhone app
- sending Live Activity updates from the terminal or external workflows

## Install

```bash
npm install -g @andreasink/reportkit
```

Then set:

```bash
export REPORTKIT_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
export REPORTKIT_SUPABASE_ANON_KEY=YOUR_ANON_PUBLIC_KEY
```

You can also place them in `~/.reportkit/.env`.

## Commands

```bash
reportkit auth --email you@example.com
reportkit status
reportkit send --event update --activity-id daily-report --title "Revenue watch" --summary "Down 8% vs yesterday" --status warning
reportkit send --file agent-progress.json
reportkit logout
reportkit skill print --target codex
reportkit skill print --target claude
```

Example `agent-progress.json`:

```json
{
  "event": "update",
  "activityId": "codex-agent",
  "payload": {
    "generatedAt": 1774000000,
    "title": "Ship Agent Progress Template",
    "summary": "Updated the widget payload schema and now wiring the Dynamic Island progress bar.",
    "status": "warning",
    "progressPercent": 68,
    "completedSteps": 17,
    "totalSteps": 25
  },
  "visualStyle": "progress"
}
```

For local development, see the repo root README.
