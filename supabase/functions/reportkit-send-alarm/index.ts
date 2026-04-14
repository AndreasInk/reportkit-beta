import {
  json,
  normalizeOptionalInstallID,
  parseApnsEnv,
  readJsonBody,
} from "../_shared/common.ts";
import { sendAlarmPush } from "../_shared/apns.ts";
import { createServiceClient, requireUser } from "../_shared/supabase.ts";

type TokenRow = {
  id: string;
  token_hex: string;
};

const TERMINAL_TOKEN_ERRORS = new Set(["BadDeviceToken", "Unregistered"]);

function asOptionalPositiveInteger(value: unknown): number | null {
  if (value === null || value === undefined || value === "") return null;
  const numeric = Number(value);
  if (!Number.isFinite(numeric) || numeric < 1) {
    return null;
  }
  return Math.trunc(numeric);
}

function asOptionalTimestamp(value: unknown): string | null {
  const raw = String(value ?? "").trim();
  if (!raw) return null;
  return Number.isNaN(Date.parse(raw)) ? null : raw;
}

function resolveStatus(successCount: number, failureCount: number, targetCount: number): "sent" | "partial" | "failed" | "no_targets" {
  if (targetCount === 0) return "no_targets";
  if (successCount === 0) return "failed";
  if (failureCount === 0) return "sent";
  return "partial";
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

  const apnsEnv = parseApnsEnv(body.apns_env);
  const title = String(body.title ?? "").trim();
  const alarmID = String(body.alarm_id ?? "").trim() || undefined;
  const fireInSeconds = asOptionalPositiveInteger(body.fire_in_seconds);
  const fireAt = asOptionalTimestamp(body.fire_at);
  const alertTitle = String(body.alert_title ?? "").trim() || undefined;
  const alertBody = String(body.alert_body ?? "").trim() || undefined;
  const deviceInstallID = normalizeOptionalInstallID(body.device_install_id);

  if (!apnsEnv) return json({ error: "Invalid apns_env" }, 400);
  if (!title) return json({ error: "Invalid title" }, 400);
  if (!fireInSeconds && !fireAt) {
    return json({ error: "Provide fire_in_seconds or fire_at" }, 400);
  }
  if ((body.device_install_id ?? null) && !deviceInstallID) {
    return json({ error: "Invalid device_install_id" }, 400);
  }

  let tokenQuery = supabase
    .from("reportkit_device_tokens")
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
    return json({ ok: false, error: "token_lookup_failed" }, 500);
  }

  const targets = (tokenRows ?? []) as TokenRow[];
  if (!targets.length) {
    return json({
      ok: true,
      status: "no_targets",
      target_count: 0,
      success_count: 0,
      failure_count: 0,
    });
  }

  let successCount = 0;
  let failureCount = 0;

  for (const tokenRow of targets) {
    const result = await sendAlarmPush({
      tokenHex: tokenRow.token_hex,
      apnsEnv,
      title,
      alarmID,
      fireAt: fireAt ?? undefined,
      fireInSeconds: fireInSeconds ?? undefined,
      alertTitle,
      alertBody,
    });

    if (result.ok) {
      successCount += 1;
      continue;
    }

    failureCount += 1;

    if (result.reason && TERMINAL_TOKEN_ERRORS.has(result.reason)) {
      await supabase
        .from("reportkit_device_tokens")
        .update({ is_active: false, updated_at: new Date().toISOString() })
        .eq("id", tokenRow.id);
    }
  }

  return json({
    ok: successCount > 0,
    status: resolveStatus(successCount, failureCount, targets.length),
    target_count: targets.length,
    success_count: successCount,
    failure_count: failureCount,
  });
});
