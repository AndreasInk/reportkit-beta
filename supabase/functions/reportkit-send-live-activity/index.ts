import {
  asObject,
  asOptionalInteger,
  json,
  normalizeOptionalInstallID,
  parseApnsEnv,
  parseLiveActivityEvent,
  readJsonBody,
  sha256Hex,
  stableJSONString,
} from "../_shared/common.ts";
import { createServiceClient, requireUser } from "../_shared/supabase.ts";
import { sendLiveActivityPush } from "../_shared/apns.ts";

type EventStatus = "queued" | "sent" | "partial" | "failed" | "no_targets";

type ExistingEventRow = {
  id: string;
  status: EventStatus;
  target_count: number;
  success_count: number;
  failure_count: number;
};

type TokenRow = {
  id: string;
  token_hex: string;
};

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const TERMINAL_TOKEN_ERRORS = new Set(["BadDeviceToken", "Unregistered"]);

function sanitizeExcerpt(text: string): string | null {
  const trimmed = text.trim();
  if (!trimmed) return null;
  return trimmed.slice(0, 400);
}

function resolveStatus(successCount: number, failureCount: number, targetCount: number): EventStatus {
  if (targetCount === 0) return "no_targets";
  if (successCount === 0) return "failed";
  if (failureCount === 0) return "sent";
  return "partial";
}

function parsePriority(value: unknown, event: string): "5" | "10" | null {
  const defaultPriority: "5" | "10" = event === "update" ? "5" : "10";
  if (value === undefined || value === null || String(value).trim() === "") {
    return defaultPriority;
  }
  const priority = String(value).trim();
  if (priority !== "5" && priority !== "10") {
    return null;
  }
  return priority;
}

async function updateEvent(
  supabase: ReturnType<typeof createServiceClient>,
  eventID: string,
  status: EventStatus,
  targetCount: number,
  successCount: number,
  failureCount: number,
): Promise<void> {
  await supabase
    .from("reportkit_live_activity_events")
    .update({
      status,
      target_count: targetCount,
      success_count: successCount,
      failure_count: failureCount,
      updated_at: new Date().toISOString(),
    })
    .eq("id", eventID);
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  let supabase;
  try {
    supabase = createServiceClient();
  } catch {
    return json({ error: "Server misconfiguration" }, 500);
  }

  const user = await requireUser(req, supabase);
  if (!user) {
    return json({ error: "Unauthorized" }, 401);
  }

  const body = await readJsonBody(req);
  if (!body) {
    return json({ error: "Bad JSON" }, 400);
  }

  const event = parseLiveActivityEvent(body.event);
  const apnsEnv = parseApnsEnv(body.apns_env);
  const payload = asObject(body.payload);
  const idempotencyKey = String(body.idempotency_key ?? "").trim();
  const deviceInstallID = normalizeOptionalInstallID(body.device_install_id);
  const workspaceIDRaw = String(body.workspace_id ?? "").trim();
  const workspaceID = workspaceIDRaw ? workspaceIDRaw : null;
  const priority = parsePriority(body.apns_priority, event ?? "update");

  const staleDate = asOptionalInteger(body.stale_date);
  const dismissalDate = asOptionalInteger(body.dismissal_date);
  const attributesTypeRaw = String(body.attributes_type ?? "").trim();
  const attributes = asObject(body.attributes);
  const alert = asObject(body.alert);

  if (!event) return json({ error: "Invalid event" }, 400);
  if (!apnsEnv) return json({ error: "Invalid apns_env" }, 400);
  if (!payload) return json({ error: "Invalid payload (must be an object)" }, 400);
  if (!idempotencyKey || idempotencyKey.length > 255) {
    return json({ error: "Invalid idempotency_key" }, 400);
  }
  if (!priority) {
    return json({ error: "Invalid apns_priority" }, 400);
  }
  if (workspaceID && !UUID_RE.test(workspaceID)) {
    return json({ error: "Invalid workspace_id" }, 400);
  }
  if ((body.device_install_id ?? null) && !deviceInstallID) {
    return json({ error: "Invalid device_install_id" }, 400);
  }

  const attributesType = attributesTypeRaw || null;

  if (event === "start") {
    if (!attributesType || !attributes) {
      return json({ error: "Start event requires attributes_type and attributes" }, 400);
    }
  }

  const payloadHash = await sha256Hex(stableJSONString(payload));
  const now = new Date().toISOString();

  const { data: insertedEvent, error: insertEventError } = await supabase
    .from("reportkit_live_activity_events")
    .insert({
      user_id: user.id,
      workspace_id: workspaceID,
      event,
      apns_env: apnsEnv,
      device_install_id: deviceInstallID,
      payload_hash: payloadHash,
      idempotency_key: idempotencyKey,
      status: "queued",
      target_count: 0,
      success_count: 0,
      failure_count: 0,
      created_at: now,
      updated_at: now,
    })
    .select("id,status,target_count,success_count,failure_count")
    .single();

  if (insertEventError) {
    if (insertEventError.code === "23505") {
      const { data: existingData } = await supabase
        .from("reportkit_live_activity_events")
        .select("id,status,target_count,success_count,failure_count")
        .eq("user_id", user.id)
        .eq("idempotency_key", idempotencyKey)
        .maybeSingle();
      const existing = existingData as ExistingEventRow | null;

      if (existing) {
        return json({
          ok: true,
          idempotent: true,
          event_id: existing.id,
          status: existing.status,
          target_count: existing.target_count,
          success_count: existing.success_count,
          failure_count: existing.failure_count,
        });
      }
    }
    return json({ ok: false, error: "event_insert_failed" }, 500);
  }

  if (!insertedEvent?.id) {
    return json({ ok: false, error: "event_insert_failed" }, 500);
  }
  const eventID = insertedEvent.id as string;

  let tokenQuery = supabase
    .from("reportkit_live_activity_tokens")
    .select("id,token_hex")
    .eq("user_id", user.id)
    .eq("apns_env", apnsEnv)
    .eq("is_active", true)
    .order("updated_at", { ascending: false });

  if (deviceInstallID) {
    tokenQuery = tokenQuery.eq("device_install_id", deviceInstallID);
  }

  const { data: tokenRows, error: tokenError } = await tokenQuery;
  if (tokenError) {
    await updateEvent(supabase, eventID, "failed", 0, 0, 0);
    return json({ ok: false, error: "token_lookup_failed", event_id: eventID }, 500);
  }

  const targets = (tokenRows ?? []) as TokenRow[];
  if (!targets.length) {
    await updateEvent(supabase, eventID, "no_targets", 0, 0, 0);
    return json({
      ok: true,
      event_id: eventID,
      status: "no_targets",
      target_count: 0,
      success_count: 0,
      failure_count: 0,
    });
  }

  let successCount = 0;
  let failureCount = 0;

  for (const tokenRow of targets) {
    const result = await sendLiveActivityPush({
      tokenHex: tokenRow.token_hex,
      apnsEnv,
      event,
      contentState: payload,
      attributesType: attributesType ?? undefined,
      attributes: attributes ?? undefined,
      alert: alert ?? undefined,
      staleDate: staleDate ?? undefined,
      dismissalDate: dismissalDate ?? undefined,
      priority,
    });

    if (result.ok) {
      successCount += 1;
    } else {
      failureCount += 1;
    }

    const { error: deliveryError } = await supabase
      .from("reportkit_push_deliveries")
      .insert({
        event_id: eventID,
        user_id: user.id,
        token_table: "live_activity",
        token_row_id: tokenRow.id,
        apns_status: result.status,
        apns_id: result.apnsId,
        error_code: result.ok ? null : result.reason,
        response_excerpt: sanitizeExcerpt(result.responseText),
      });

    if (deliveryError) {
      const status = resolveStatus(successCount, failureCount, targets.length);
      await updateEvent(supabase, eventID, status, targets.length, successCount, failureCount);
      return json({ ok: false, error: "delivery_audit_write_failed", event_id: eventID }, 500);
    }

    if (!result.ok && result.reason && TERMINAL_TOKEN_ERRORS.has(result.reason)) {
      await supabase
        .from("reportkit_live_activity_tokens")
        .update({
          is_active: false,
          updated_at: new Date().toISOString(),
        })
        .eq("id", tokenRow.id);
    }
  }

  const status = resolveStatus(successCount, failureCount, targets.length);
  await updateEvent(supabase, eventID, status, targets.length, successCount, failureCount);

  return json({
    ok: true,
    event_id: eventID,
    status,
    target_count: targets.length,
    success_count: successCount,
    failure_count: failureCount,
  });
});
