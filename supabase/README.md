# Supabase

This folder contains the backend pieces for ReportKit Beta: edge functions, SQL migrations, and rollout notes.

## What Lives Here

- `functions/`: token registration, latest-token lookup, Live Activity send handlers, and alarm send handlers
- `migrations/`: database schema for tokens, events, and push deliveries
- `PRODUCTION_ROLLOUT.md`: deployment and rollout notes

## Edge Functions

Current functions:

- `reportkit-token`
- `reportkit-device-token`
- `reportkit-latest-token`
- `reportkit-send-live-activity`
- `reportkit-send-alarm`

Shared auth and Supabase client helpers live under `functions/_shared/`.

## Auth Boundary

These functions are currently expected to be deployed with `--no-verify-jwt`.

That means auth is enforced inside the function code rather than by the Supabase gateway. Changes to `functions/_shared/supabase.ts` are security-critical.

## Operational Notes

- Do not trust caller-supplied identity headers.
- Do not add service-role keys or APNs secrets to this repo.
- Keep open-source safety constraints aligned with `docs/open-source-security.md`.
