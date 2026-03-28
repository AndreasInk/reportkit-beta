# ReportKit Beta

![ReportKit README bento](docs/assets/reportkit-readme-bento.png)

ReportKit Beta puts important app and ops signals into an iPhone Live Activity.

It is a small system with three parts:
- an iOS app + widget
- a CLI called `reportkit`
- Supabase edge functions for auth, token upload, and push delivery

The goal is simple: sign in on your Mac and iPhone with the same account, then send Live Activity updates from the CLI or your own workflows.

## What It Does

- signs the CLI and iPhone app into the same Supabase account
- uploads Live Activity tokens from the phone
- sends simple Live Activity updates from the CLI
- leaves scheduling to Codex / Claude workflows instead of building cron into the CLI

## Quick Start

### 1. Set your Supabase keys

The CLI needs:
- `REPORTKIT_SUPABASE_URL`
- `REPORTKIT_SUPABASE_ANON_KEY`

```bash
export REPORTKIT_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
export REPORTKIT_SUPABASE_ANON_KEY=YOUR_ANON_PUBLIC_KEY
```

You can also place them in `~/.reportkit/.env`.

### 2. Install the CLI

```bash
npm install -g @andreasink/reportkit
```

### 3. Sign in on the CLI

```bash
reportkit auth --email you@example.com
reportkit status
```

For automation:

```bash
printf '%s\n' 'your-password' | reportkit auth --email you@example.com --password-stdin
```

### 4. Sign in on the iPhone app

The TestFlight link is on its way.

Open the iOS app and sign in with the same email/password.

The app will:
- request notification permission
- upload Live Activity tokens
- show current token sync state once signed in

### 5. Send a test Live Activity update

```bash
reportkit send \
  --event update \
  --activity-id daily-report \
  --title "Revenue watch" \
  --summary "Down 8% vs yesterday" \
  --status warning
```

## Typical Flow

1. Install the CLI.
2. Sign in with `reportkit auth`.
3. Sign in on the iPhone app with the same account.
4. Run `reportkit send` manually or from your own workflow.

## Useful Commands

```bash
reportkit status
reportkit logout
reportkit skill print --target codex
reportkit skill print --target claude
```

## Where Things Live

- [`ios/`](ios/): iOS app, widget, Xcode project, and platform-specific notes
- [`cli/`](cli/): TypeScript CLI package
- [`supabase/`](supabase/): edge functions, migrations, and rollout notes
- [`docs/`](docs/): architecture and security notes

## Important Notes

- The CLI stores session metadata in `~/.config/reportkit-simple/config.json`.
- The CLI stores access and refresh tokens in `~/.config/reportkit-simple/session-store.json` with local-only permissions and mirrors them to macOS Keychain as best-effort backup.
- The iOS app reads `REPORTKIT_SUPABASE_URL` and `REPORTKIT_SUPABASE_ANON_KEY` from `Info.plist`.
- The CLI does not manage cron. Scheduling should happen in your Codex / Claude workflow.

## Open Source Safety

This repo does not include:
- Supabase service-role keys
- APNs credentials
- Apple signing assets
- private release overrides
- future push-service secrets

See [`docs/open-source-security.md`](docs/open-source-security.md) for details.
