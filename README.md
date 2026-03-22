# ReportKit Simple v2

Minimal parallel implementation of ReportKit focused on one job:

- authenticate both CLI and iPhone with the same Supabase account
- upload Live Activity tokens
- send simple Live Activity updates
- schedule reports through your Codex/Claude workflow

This lives beside the existing ReportKit implementation. It does not replace the current root yet.

## Structure

- `ios/`: `ReportKitSimple.xcodeproj` and the minimal iOS app + widget
- `cli/`: TypeScript npm package exposed as `reportkit`
- `docs/`: architecture notes, UI validation notes, and screenshots

## Product Flow

1. User installs the npm package.
2. User runs `reportkit auth`.
3. CLI stores an email/password-based Supabase session in local config.
4. User signs into the iOS app with the same account.
5. `reportkit send` reuses the local Supabase access token to publish Live Activity updates.

## Runtime Boundaries

- iOS keeps normal Supabase auth.
- CLI stores the Supabase access/refresh tokens in the user config directory.
- Existing token upload and live-activity send endpoints are reused.
- No pairing API is required.

## Commands

```bash
cd reportkit-simple/cli
npm install
npm run build

export REPORTKIT_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
export REPORTKIT_SUPABASE_ANON_KEY=YOUR_ANON_PUBLIC_KEY

reportkit auth
reportkit status
reportkit send --event update --activity-id daily-report --title "Revenue watch" --summary "Down 8% vs yesterday" --status warning
reportkit logout
reportkit skill print --target codex
reportkit skill print --target claude
```

### Configuration

The CLI requires both `REPORTKIT_SUPABASE_URL` and `REPORTKIT_SUPABASE_ANON_KEY` for local operation.

- Prefer exporting them as environment variables before running CLI commands.
- `defaultConfig` does not include fallback values; if missing, commands fail with a clear error.

The iOS app reads the same keys from `Info.plist` (`REPORTKIT_SUPABASE_URL`, `REPORTKIT_SUPABASE_ANON_KEY`) and will precondition-fail at launch if unresolved.

### Skill

- `reportkit skill print --target codex` prints a copy-paste prompt for Codex.
- `reportkit skill print --target claude` prints the same guidance tailored for Claude Code.
- A source copy of the template also lives in `docs/reportkit-simple-skill.md`.

The CLI no longer includes cron management. Scheduling is expected to be handled by your Codex/Claude workflows.

## iOS App States

- signed out: email/password login
- signed in: token sync status, rescan disabled, sign out

## Notes

- The widget uses a new `ReportKitSimpleAttributes` contract and intentionally drops the v1 payload model.
- `ios/project.yml` is the XcodeGen source. If you regenerate the project, re-check the custom Info.plists.
