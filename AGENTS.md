# ReportKit Beta Agent Notes

## Repo Intent

This repo contains the current beta implementation of ReportKit.

It focuses on one narrow flow:
- authenticate the CLI and iPhone app against the same Supabase account
- upload Live Activity tokens from iOS
- send simple Live Activity updates from the CLI
- leave scheduling to external Codex / Claude workflows

This repo does not replace the older root implementation yet.

## Repo Layout

- `ios/`: iOS app, widget, Xcode project, and shared Live Activity types
- `cli/`: TypeScript CLI package exposed as `reportkit`
- `supabase/`: edge functions, migrations, and rollout notes
- `docs/`: architecture and security notes

## Core Flow

1. Install and build the CLI from `cli/`.
2. Set `REPORTKIT_SUPABASE_URL` and `REPORTKIT_SUPABASE_ANON_KEY`.
3. Run `reportkit auth --email ...` on the Mac.
4. Sign into the iOS app with the same email/password.
5. Let the app upload Live Activity tokens.
6. Use `reportkit send` to publish Live Activity updates.

## Runtime Boundaries

- iOS uses normal Supabase auth.
- CLI uses normal Supabase auth.
- No pairing API is required.
- Token upload and live-activity send routes live in `supabase/functions/`.
- Scheduling is intentionally out of scope for the CLI.
- The authenticated edge functions are currently deployed with `--no-verify-jwt`, so auth is enforced inside the function code rather than by the Supabase gateway.

## Important Paths

- CLI session metadata: `~/.config/reportkit-simple/config.json`
- CLI bearer token store: `~/.config/reportkit-simple/session-store.json`
- Optional machine-global env file: `~/.reportkit/.env`
- iOS config source: `Info.plist` keys `REPORTKIT_SUPABASE_URL` and `REPORTKIT_SUPABASE_ANON_KEY`

## Environment Rules

Required for local CLI operation:
- `REPORTKIT_SUPABASE_URL`
- `REPORTKIT_SUPABASE_ANON_KEY`

Resolution order:
1. process environment
2. `~/.reportkit/.env`

Placeholder values should be treated as invalid.

## CLI Commands

```bash
cd reportkit-simple/cli
npm install
npm run build

reportkit auth --email you@example.com
reportkit status
reportkit send --event update --activity-id daily-report --title "Revenue watch" --summary "Down 8% vs yesterday" --status warning
reportkit logout
reportkit skill print --target codex
reportkit skill print --target claude
```

For automation:

```bash
printf '%s\n' 'your-password' | reportkit auth --email you@example.com --password-stdin
```

## iOS State Expectations

- Signed out: email/password auth UI
- Signed in: token sync status and sign-out controls
- On first launch, onboarding appears before the main auth flow

If email confirmation is enabled in Supabase, the app should remain in the signed-out flow until the user confirms and signs in.

## Security / Open Source Notes

This repo must stay safe to open source. It must not contain:
- Supabase service-role keys
- APNs credentials
- Apple signing assets
- private release overrides
- future relay or push-service secrets

More detail lives in `docs/open-source-security.md`.

## Edge Function Auth Note

The following functions are currently expected to be deployed with `--no-verify-jwt`:
- `reportkit-token`
- `reportkit-device-token`
- `reportkit-send-live-activity`

Reason:
- the project's legacy gateway JWT verification mode rejects valid modern Supabase access tokens
- function-level auth via `requireUser(...)` is currently the working enforcement point

Implication:
- do not trust caller-supplied identity headers
- changes to shared auth helpers in `supabase/functions/_shared/supabase.ts` are security-critical

## Git Hook

To block obvious secrets before commit:

```bash
./scripts/install-git-hooks.sh
```

The hook rejects staged `.env` files, session stores, private keys, obvious token formats, and unsafe password-in-command patterns.

## Agent Guidance

- Prefer the human README for onboarding and fast setup.
- Prefer this file for repo-specific operational details.
- Prefer `docs/architecture.md` for system shape and boundaries.
- Prefer `docs/open-source-security.md` for secret-handling constraints.
- Do not add cron or scheduler logic to the CLI unless the user explicitly changes scope.
