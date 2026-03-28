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
- `supabase/`: edge functions, migrations, and rollout notes for a self-hosted Supabase project
- `docs/`: architecture notes, UI validation notes, and screenshots

## Product Flow

1. User installs the npm package.
2. User runs `reportkit auth`.
3. CLI stores session metadata in local config and keeps the bearer tokens in a separate local-only session store.
4. User signs into the iOS app with the same account.
5. `reportkit send` reuses the local Supabase access token to publish Live Activity updates.

## Runtime Boundaries

- iOS keeps normal Supabase auth.
- CLI stores session metadata in `~/.config/reportkit-simple/config.json`.
- CLI stores access/refresh tokens in `~/.config/reportkit-simple/session-store.json` with `0600` permissions and mirrors them to macOS Keychain as best-effort backup.
- Token upload and live-activity send endpoints are implemented in the vendored `supabase/functions/` directory.
- No pairing API is required.

## Supabase Backend

This repo now includes the Supabase backend needed to stand up a fresh project:

- edge functions in [`supabase/functions/`](/Users/andreas/Desktop/reportkit-simple/supabase/functions)
- SQL migrations in [`supabase/migrations/`](/Users/andreas/Desktop/reportkit-simple/supabase/migrations)
- deployment notes in [`supabase/PRODUCTION_ROLLOUT.md`](/Users/andreas/Desktop/reportkit-simple/supabase/PRODUCTION_ROLLOUT.md)

That keeps the public repo self-contained: clients still expose only `REPORTKIT_SUPABASE_URL` and `REPORTKIT_SUPABASE_ANON_KEY`, while the edge functions use server-side secrets inside Supabase for APNs delivery.

## Commands

```bash
cd reportkit-simple/cli
npm install
npm run build

export REPORTKIT_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
export REPORTKIT_SUPABASE_ANON_KEY=YOUR_ANON_PUBLIC_KEY

reportkit auth --email you@example.com
# or for automation:
printf '%s\n' 'your-password' | reportkit auth --email you@example.com --password-stdin
reportkit status
reportkit send --event update --activity-id daily-report --title "Revenue watch" --summary "Down 8% vs yesterday" --status warning
reportkit logout
reportkit skill print --target codex
reportkit skill print --target claude
```

### Configuration

The CLI requires both `REPORTKIT_SUPABASE_URL` and `REPORTKIT_SUPABASE_ANON_KEY` for local operation.

- Resolution order is:
  1. process environment
  2. machine-global `~/.reportkit/.env`
- Placeholder values are rejected up front with a clear error.
- `~/.config/reportkit-simple/config.json` stores CLI session metadata only. It does not contain access or refresh tokens.
- `~/.config/reportkit-simple/session-store.json` stores the bearer tokens with local-only permissions and is mirrored to macOS Keychain as best-effort backup.

The iOS app reads the same keys from `Info.plist` (`REPORTKIT_SUPABASE_URL`, `REPORTKIT_SUPABASE_ANON_KEY`) and will precondition-fail at launch if unresolved.

## Public Repo Notes

This source checkout is intended to stay safe to open source.

The repo does not include:

- Supabase service-role keys
- APNs credentials
- Apple signing assets
- private release overrides
- future relay or push-service secrets

More detail lives in [`docs/open-source-security.md`](docs/open-source-security.md).

## Local Git Hook

To block obvious hardcoded credentials before commit:

```bash
./scripts/install-git-hooks.sh
```

That installs `.githooks/pre-commit` as the repo hook path and rejects staged:

- `.env` files and local session stores
- private keys and certificates
- high-signal token formats
- `reportkit auth ... --password ...` usage
- direct `REPORTKIT_PASSWORD=` assignments

### Skill

- `reportkit skill print --target codex` prints a copy-paste prompt for Codex.
- `reportkit skill print --target claude` prints the same guidance tailored for Claude Code.
- A source copy of the template also lives in `docs/reportkit-simple-skill.md`.

The CLI no longer includes cron management. Scheduling is expected to be handled by your Codex/Claude workflows.

## iOS App States

- signed out: email/password login
- signed in: token sync status, rescan disabled, sign out

On first launch, the sign-out flow now shows a short onboarding message and a single auth screen with **Sign In** and **Sign Up** mode toggle. Sign up is handled directly with email and password via Supabase. If email confirmation is required, the app shows a confirmation instruction and keeps you in the signed-out flow until you sign in.

## Notes

- The widget uses a new `ReportKitSimpleAttributes` contract and intentionally drops the v1 payload model.
- `ios/project.yml` is the XcodeGen source. If you regenerate the project, re-check the custom Info.plists.
