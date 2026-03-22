# ReportKit Simple v2 Architecture

## Intent

ReportKit Simple is a minimal parallel implementation focused only on:

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

- Auths once with Supabase: `reportkit auth --email ... --password ...`.
- Persists access token, refresh token, user email, and expiry to `~/.config/reportkit-simple/config.json`.
- Sends with `reportkit send` using that stored token.

### Supabase additions

- No new pairing tables/functions.
- No CLI-session tables.
- Existing authentication + token + live-activity routes are unchanged.

## Runtime Boundaries

- CLI and app both use normal Supabase auth.
- Authorization for token upload and send routes is via the same Supabase bearer token header.
- `reportkit-send-live-activity` receives the v2 attributes payload and start-event attribute contract:
 - `generatedAt`
 - `title`
 - `summary`
 - `status`
 - `action`
 - `deepLink`

Scheduling for sending is handled in Codex/Claude workflows.  
The CLI stays focused on explicit `reportkit send` operations.
