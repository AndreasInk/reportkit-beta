# Supabase Production Rollout (Multi-User ReportKit)

This rollout hard-cuts ReportKit to authenticated Supabase Edge Functions and user-owned token rows.

## What Changed

1. Token uploads now require `Authorization: Bearer <supabase access token>`.
2. Token rows are owned by `user_id`.
3. APNs send now happens in `reportkit-send-live-activity`.
4. `reportkit-latest-token` is deprecated and returns `410`.
5. Live activity payload bodies are not stored; only payload hashes are stored.

## New / Updated Tables

1. `public.reportkit_live_activity_tokens`
2. `public.reportkit_device_tokens`
3. `public.reportkit_live_activity_events`
4. `public.reportkit_push_deliveries`

Migrations are under [`supabase/migrations/`](/Users/andreas/Desktop/reportkit-simple/supabase/migrations).

## Required Edge Function Secrets

Set these in Supabase before deploying/running `reportkit-send-live-activity`:

1. `REPORTKIT_APNS_KEY_ID`
2. `REPORTKIT_APNS_TEAM_ID`
3. `REPORTKIT_APNS_BUNDLE_ID`
4. `REPORTKIT_APNS_AUTH_KEY_P8` (full APNs private key content)
5. `REPORTKIT_APNS_TOPIC_SUFFIX` (optional, default `.push-type.liveactivity`)

## Deploy Steps

1. Link your Supabase project and apply migrations.

```bash
supabase link --project-ref <your-project-ref>
supabase db push
```

If you use `supabase-snr`, run the equivalent `link` + `db push` commands through that wrapper.

2. Set secrets.

```bash
supabase secrets set REPORTKIT_APNS_KEY_ID=... REPORTKIT_APNS_TEAM_ID=... REPORTKIT_APNS_BUNDLE_ID=...
supabase secrets set REPORTKIT_APNS_AUTH_KEY_P8="$(cat /path/to/AuthKey_XXXX.p8)"
# optional
supabase secrets set REPORTKIT_APNS_TOPIC_SUFFIX=.push-type.liveactivity
```

3. Deploy functions.

```bash
supabase functions deploy reportkit-token
supabase functions deploy reportkit-device-token
supabase functions deploy reportkit-send-live-activity
supabase functions deploy reportkit-latest-token
```

## API Contract

### `POST /functions/v1/reportkit-token`

Body:

```json
{
  "device_install_id": "<install-id>",
  "apns_env": "sandbox",
  "token_hex": "<hex>"
}
```

### `POST /functions/v1/reportkit-device-token`

Body:

```json
{
  "device_install_id": "<install-id>",
  "apns_env": "sandbox",
  "token_hex": "<hex>"
}
```

### `POST /functions/v1/reportkit-send-live-activity`

Body:

```json
{
  "event": "update",
  "payload": { "title": "Daily Pulse" },
  "apns_env": "sandbox",
  "idempotency_key": "run-2026-02-26T17:00:00Z",
  "workspace_id": "00000000-0000-0000-0000-000000000000",
  "device_install_id": "optional-install-id"
}
```

For `event: "start"`, include:

```json
{
  "attributes_type": "ReportKitWidgetsAttributes",
  "attributes": { "reportID": "daily-report-001" }
}
```

## Smoke Tests

Run these with a valid user access token (`$USER_JWT`) and project URL (`$SUPABASE_URL`):

1. Upload live activity token.

```bash
curl -sS "$SUPABASE_URL/functions/v1/reportkit-token" \
  -H "Authorization: Bearer $USER_JWT" \
  -H "Content-Type: application/json" \
  -d '{"device_install_id":"ios-install-1","apns_env":"sandbox","token_hex":"<hex>"}'
```

2. Upload device token.

```bash
curl -sS "$SUPABASE_URL/functions/v1/reportkit-device-token" \
  -H "Authorization: Bearer $USER_JWT" \
  -H "Content-Type: application/json" \
  -d '{"device_install_id":"ios-install-1","apns_env":"sandbox","token_hex":"<hex>"}'
```

3. Send single-target live activity update.

```bash
curl -sS "$SUPABASE_URL/functions/v1/reportkit-send-live-activity" \
  -H "Authorization: Bearer $USER_JWT" \
  -H "Content-Type: application/json" \
  -d '{"event":"update","payload":{"title":"Daily Pulse"},"apns_env":"sandbox","idempotency_key":"manual-test-1","device_install_id":"ios-install-1"}'
```

4. Send broadcast update (all active user tokens in env).

```bash
curl -sS "$SUPABASE_URL/functions/v1/reportkit-send-live-activity" \
  -H "Authorization: Bearer $USER_JWT" \
  -H "Content-Type: application/json" \
  -d '{"event":"update","payload":{"title":"Daily Pulse"},"apns_env":"sandbox","idempotency_key":"manual-test-2"}'
```

## Validation Queries

1. Tokens have `user_id` set.
2. One event row per idempotency key per user.
3. Delivery rows contain APNs status and no payload body.

```sql
select user_id, device_install_id, apns_env, updated_at
from public.reportkit_live_activity_tokens
order by updated_at desc;

select user_id, idempotency_key, status, target_count, success_count, failure_count
from public.reportkit_live_activity_events
order by created_at desc;

select event_id, apns_status, apns_id, error_code, created_at
from public.reportkit_push_deliveries
order by created_at desc;
```
