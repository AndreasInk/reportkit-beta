import * as jose from "https://deno.land/x/jose@v5.2.4/index.ts";
import {
  ApnsEnv,
  LiveActivityEvent,
  asObject,
  requireEnv,
} from "./common.ts";

export interface LiveActivityPushRequest {
  tokenHex: string;
  apnsEnv: ApnsEnv;
  event: LiveActivityEvent;
  contentState: Record<string, unknown>;
  attributesType?: string;
  attributes?: Record<string, unknown>;
  alert?: Record<string, unknown>;
  staleDate?: number;
  dismissalDate?: number;
  priority?: "5" | "10";
  timestamp?: number;
}

export interface LiveActivityPushResponse {
  ok: boolean;
  status: number;
  apnsId: string | null;
  reason: string | null;
  responseText: string;
}

export interface AlarmPushRequest {
  tokenHex: string;
  apnsEnv: ApnsEnv;
  title: string;
  alarmID?: string;
  fireAt?: string;
  fireInSeconds?: number;
  alertTitle?: string;
  alertBody?: string;
  timestamp?: number;
}

interface APNSConfig {
  keyID: string;
  teamID: string;
  bundleID: string;
  topicSuffix: string;
  privateKey: string;
}

function normalizePrivateKey(raw: string): string {
  return raw.includes("\\n") ? raw.replace(/\\n/g, "\n") : raw;
}

function loadConfig(): APNSConfig {
  return {
    keyID: requireEnv("REPORTKIT_APNS_KEY_ID"),
    teamID: requireEnv("REPORTKIT_APNS_TEAM_ID"),
    bundleID: requireEnv("REPORTKIT_APNS_BUNDLE_ID"),
    topicSuffix: Deno.env.get("REPORTKIT_APNS_TOPIC_SUFFIX")?.trim() || ".push-type.liveactivity",
    privateKey: normalizePrivateKey(requireEnv("REPORTKIT_APNS_AUTH_KEY_P8")),
  };
}

function apnsHost(apnsEnv: ApnsEnv): string {
  return apnsEnv === "production" ? "api.push.apple.com" : "api.sandbox.push.apple.com";
}

async function buildProviderJWT(config: APNSConfig): Promise<string> {
  const key = await jose.importPKCS8(config.privateKey, "ES256");
  return await new jose.SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: config.keyID })
    .setIssuer(config.teamID)
    .setIssuedAt()
    .sign(key);
}

function buildAPSBody(request: LiveActivityPushRequest): Record<string, unknown> {
  const now = Math.floor(Date.now() / 1000);
  const aps: Record<string, unknown> = {
    timestamp: request.timestamp ?? now,
    event: request.event,
    "content-state": request.contentState,
  };

  if (typeof request.staleDate === "number") {
    aps["stale-date"] = request.staleDate;
  }

  if (typeof request.dismissalDate === "number") {
    aps["dismissal-date"] = request.dismissalDate;
  }

  if (request.event === "start") {
    if (!request.attributesType || !request.attributes) {
      throw new Error("Start events require attributesType and attributes");
    }
    aps["attributes-type"] = request.attributesType;
    aps["attributes"] = request.attributes;

    if (request.alert) {
      aps.alert = request.alert;
    } else {
      aps.alert = {
        title: "ReportKit",
        body: "Live Activity started",
      };
    }
  }

  return { aps };
}

function buildAlarmBody(request: AlarmPushRequest): Record<string, unknown> {
  const timestamp = request.timestamp ?? Math.floor(Date.now() / 1000);
  const alarm: Record<string, unknown> = {
    title: request.title,
    id: request.alarmID ?? String(timestamp),
  };

  if (typeof request.fireInSeconds === "number") {
    alarm.fireInSeconds = request.fireInSeconds;
  }

  if (request.fireAt) {
    alarm.fireAt = request.fireAt;
  }

  return {
    aps: {
      alert: {
        title: request.alertTitle ?? "ReportKit",
        body: request.alertBody ?? `Alarm scheduled: ${request.title}`,
      },
      sound: "default",
      "content-available": 1,
      timestamp,
    },
    reportkit: {
      alarm,
    },
  };
}

function parseAPNSError(text: string): string | null {
  const parsed = asObject(safeJSONParse(text));
  if (!parsed) return null;
  const reason = parsed.reason;
  if (typeof reason !== "string" || !reason) return null;
  return reason;
}

function safeJSONParse(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

export async function sendLiveActivityPush(request: LiveActivityPushRequest): Promise<LiveActivityPushResponse> {
  const config = loadConfig();
  const jwtToken = await buildProviderJWT(config);
  const topic = `${config.bundleID}${config.topicSuffix}`;
  const host = apnsHost(request.apnsEnv);
  const priority = request.priority ?? (request.event === "update" ? "5" : "10");

  const headers = new Headers({
    "apns-topic": topic,
    "apns-push-type": "liveactivity",
    "apns-priority": priority,
    "content-type": "application/json",
    authorization: `bearer ${jwtToken}`,
  });

  const response = await fetch(`https://${host}/3/device/${request.tokenHex}`, {
    method: "POST",
    headers,
    body: JSON.stringify(buildAPSBody(request)),
  });

  const text = await response.text();
  const reason = response.ok ? null : parseAPNSError(text) ?? (text.trim() || null);

  return {
    ok: response.ok,
    status: response.status,
    apnsId: response.headers.get("apns-id"),
    reason,
    responseText: text,
  };
}

export async function sendAlarmPush(request: AlarmPushRequest): Promise<LiveActivityPushResponse> {
  const config = loadConfig();
  const jwtToken = await buildProviderJWT(config);
  const host = apnsHost(request.apnsEnv);

  const headers = new Headers({
    "apns-topic": config.bundleID,
    "apns-push-type": "alert",
    "apns-priority": "10",
    "content-type": "application/json",
    authorization: `bearer ${jwtToken}`,
  });

  const response = await fetch(`https://${host}/3/device/${request.tokenHex}`, {
    method: "POST",
    headers,
    body: JSON.stringify(buildAlarmBody(request)),
  });

  const text = await response.text();
  const reason = response.ok ? null : parseAPNSError(text) ?? (text.trim() || null);

  return {
    ok: response.ok,
    status: response.status,
    apnsId: response.headers.get("apns-id"),
    reason,
    responseText: text,
  };
}
