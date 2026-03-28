# ReportKit Beta Architecture

## Intent

ReportKit Beta is a minimal parallel implementation focused only on:

- Supabase email/password login on both CLI and iOS.
- Device token upload via existing `reportkit-token` and `reportkit-device-token` endpoints.
- Minimal Live Activity payload and delivery through `reportkit-send-live-activity`.
- Minimal CLI-driven send path with no internal cron surface.

## System Shape

### iOS app

- Launches in three simple auth states: launching, signed out, signed in.
- Signed out: email/password sign-in form.
- Signed in: refresh and display token sync status; no pairing step.
- Requests notification permissions and uploads both push-to-start token and APNs device token.
- Requests are always made with the active Supabase session.

### CLI

- Auths once with Supabase: `reportkit auth --email ...`.
- Reads the password either from a hidden interactive prompt or `--password-stdin`.
- Persists session metadata to `~/.config/reportkit-simple/config.json`.
- Persists access/refresh tokens separately in `~/.config/reportkit-simple/session-store.json` with `0600` permissions and mirrors them to macOS Keychain as best-effort backup.
- Sends with `reportkit send` using that stored session.

### Supabase additions

- No new pairing tables/functions beyond the vendored backend in `supabase/`.
- No CLI-session tables.
- Authentication + token + live-activity routes are part of this repo and can be deployed into a fresh Supabase project.

## Runtime Boundaries

- CLI and app both use normal Supabase auth.
- Authorization for token upload and send routes is via the same Supabase bearer token header.
- CLI secrets are intentionally kept out of `config.json` and out of process arguments.
- `reportkit-send-live-activity` receives the v2 attributes payload and start-event attribute contract:
 - `generatedAt`
 - `title`
 - `summary`
 - `status`
 - `action`
 - `deepLink`

Scheduling for sending is handled in Codex/Claude workflows.  
The CLI stays focused on explicit `reportkit send` operations.

## Progress Live Activity payload

The shared Live Activity payload now also supports agent-progress fields:

- `progressPercent`
- `completedSteps`
- `totalSteps`

Use `visualStyle: "progress"` for agent visibility templates where:

- `title` is the high-level task
- `summary` is the latest operation
- `progressPercent` is the preferred fill source
- `completedSteps` and `totalSteps` are optional supporting metadata
