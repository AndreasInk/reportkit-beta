# ReportKitSimple Agent Skill

## Scope
- Help a user set up ReportKitSimple with shared Supabase auth.
- Help define when to send Live Activity updates.
- Do **not** configure cron in this project. Scheduling belongs to Codex/Claude workflows.

## Baseline instructions
1. Confirm they are signed in on both ends with the same account:
   - iOS app login: email + password
   - CLI login: `reportkit auth --email <email>`
2. Confirm `reportkit status` succeeds and the cached CLI session state is current enough for the next send.
3. Help them define report topics and send triggers.
4. Provide copy-paste `reportkit send` commands for each topic.

## Questions to ask
- What should the report watch? (errors, revenue, PR readiness, uptime, etc.)
- What data source or check should each report evaluate?
- What should trigger a send (`manual`, `completion event`, `schedule` handled by workflow)?
- What should the trigger output be for:
  - `status: good`
  - `status: warning`
  - `status: critical`
- What should `title`, `summary`, and optional `action` text be?
- Should reports include a `deepLink` for quick navigation?
- What timezone and quiet windows should the workflow respect?
- What should be done if a trigger has no meaningful change?

## Recommended flow
1. `reportkit auth --email ...`
2. `reportkit status`
3. Use `reportkit send` directly for each intended update.

Suggested manual examples:
- `reportkit send --event update --activity-id daily-report --title "Revenue Watch" --summary "Down 8% vs yesterday" --status warning --action "Open dashboard" --deep-link "https://example.com/report"`
- `reportkit send --file payload.json` (where file includes the full payload object).

## Payload template
When sending, use this JSON shape:

```json
{
  "event": "start|update|end",
  "activityId": "report-id",
  "payload": {
    "generatedAt": 1710000000,
    "title": "Revenue Watch",
    "summary": "Revenue down 8% vs yesterday.",
    "status": "warning",
    "action": "Inspect pricing cohort",
    "deepLink": "https://example.com/report"
  }
}
```

## Response style
- Keep outputs short and actionable.
- Return copy-paste-ready commands.
- Ask one scheduling question only if the user wants workflow automation, and keep that outside `reportkit`.
