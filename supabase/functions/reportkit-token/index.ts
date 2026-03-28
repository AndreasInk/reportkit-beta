import {
  json,
  normalizeInstallID,
  normalizeTokenHex,
  parseApnsEnv,
  readJsonBody,
} from "../_shared/common.ts";
import { createServiceClient, requireUser } from "../_shared/supabase.ts";

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

  const deviceInstallID = normalizeInstallID(body.device_install_id);
  const apnsEnv = parseApnsEnv(body.apns_env);
  const tokenHex = normalizeTokenHex(body.token_hex);

  if (!deviceInstallID || !tokenHex) {
    return json({ error: "Missing or invalid device_install_id/token_hex" }, 400);
  }
  if (!apnsEnv) {
    return json({ error: "Invalid apns_env" }, 400);
  }

  const now = new Date().toISOString();
  const { error } = await supabase
    .from("reportkit_live_activity_tokens")
    .upsert(
      {
        user_id: user.id,
        device_install_id: deviceInstallID,
        apns_env: apnsEnv,
        token_hex: tokenHex,
        is_active: true,
        last_seen_at: now,
        updated_at: now,
      },
      { onConflict: "user_id,device_install_id,apns_env" },
    );

  if (error) {
    return json({ ok: false, error: "write_failed" }, 500);
  }

  return json({ ok: true });
});
