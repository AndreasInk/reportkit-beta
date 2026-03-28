# Open-Source Security Notes

## Public Repo Boundary

This repository is intended to be safe to publish in source form.

The public repo does not include:

- Supabase service-role keys
- APNs private keys or push credentials
- Apple signing certificates, provisioning profiles, or notarization assets
- production-only release overrides
- private relay, webhook, or future push-service secrets
- persisted user auth sessions

The public repo may include:

- `REPORTKIT_SUPABASE_URL`
- `REPORTKIT_SUPABASE_ANON_KEY`
- placeholder examples for local setup

`REPORTKIT_SUPABASE_ANON_KEY` is treated as public client configuration. It is not a privileged backend credential.

## CLI Session Storage

The CLI follows the Remodex bridge pattern:

- canonical session secrets live in `~/.config/reportkit-simple/session-store.json`
- the file is written with local-only permissions (`0600`)
- on macOS, the same serialized secret payload is mirrored to Keychain as a best-effort backup
- `~/.config/reportkit-simple/config.json` stores metadata only: user ID, email, and expiry

This means the config file is safe to inspect for status/debugging without exposing bearer tokens.

## iOS Local Storage

- Supabase auth remains managed by the app-side SDK/runtime
- non-sensitive UI state stays in `UserDefaults`
- APNs token values are currently cached in `UserDefaults` to support retrying uploads across launches

Current decision on APNs token persistence:

- these token values are transport identifiers, not reusable account credentials
- they are retained only to retry upload flows and to show current local token status in the UI
- future signing keys, trust records, or any long-lived privileged material must use secure storage, not `UserDefaults`

## Threat Model Summary

Protect first against:

- accidental credential commits
- bearer-token disclosure through CLI args, env vars, or logs
- insecure local session persistence
- over-privileged CI workflows

Current mitigations:

- `reportkit auth` no longer accepts `--password`
- `REPORTKIT_PASSWORD` is rejected
- non-interactive auth requires `--password-stdin`
- secret-bearing session data is kept out of `config.json`
- CI includes CodeQL, npm vulnerability scanning, and constrained workflow permissions

## Release Follow-Up

If this repo later publishes binaries or installers:

- add checksum generation and verification to release artifacts
- document install integrity steps in the README

If this repo later ships an App Store build:

- add app-specific privacy/legal documents that match the distributed product behavior
