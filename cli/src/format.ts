import crypto from "node:crypto";
import type { AlarmRequestBody, ApnsEnv, LiveActivityPayload, SendRequestBody, Status, VisualStyle } from "./types.js";

export function parseArgs(argv: string[]): Map<string, string | true> {
  const output = new Map<string, string | true>();
  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (!value.startsWith("--")) {
      continue;
    }
    const key = value.slice(2);
    const next = argv[index + 1];
    if (!next || next.startsWith("--")) {
      output.set(key, true);
      continue;
    }
    output.set(key, next);
    index += 1;
  }
  return output;
}

export function requiredFlag(flags: Map<string, string | true>, name: string): string {
  const value = flags.get(name);
  if (!value || value === true) {
    throw new Error(`Missing required --${name}`);
  }
  return value;
}

export function optionalFlag(flags: Map<string, string | true>, name: string): string | undefined {
  const value = flags.get(name);
  return value && value !== true ? value : undefined;
}

export function normalizeApnsEnv(value: string | undefined): ApnsEnv {
  if (!value || value === "sandbox") {
    return "sandbox";
  }
  if (value === "production") {
    return "production";
  }
  throw new Error(`Invalid APNs environment: ${value}`);
}

export function normalizeStatus(value: string | undefined): Status {
  if (!value || value === "good" || value === "warning" || value === "critical") {
    return (value as Status | undefined) ?? "good";
  }
  throw new Error(`Invalid status: ${value}`);
}

export function normalizeVisualStyle(value: string | undefined): VisualStyle {
  if (!value || value === "minimal" || value === "banner" || value === "chart" || value === "progress") {
    return (value as VisualStyle | undefined) ?? "minimal";
  }
  throw new Error(`Invalid visual style: ${value}`);
}

export function buildSendBody(input: {
  event: "start" | "update" | "end";
  activityId: string;
  payload: LiveActivityPayload;
  apnsEnv?: ApnsEnv;
  idempotencyKey?: string;
  visualStyle?: VisualStyle;
}): SendRequestBody {
  const idempotencyKey =
    input.idempotencyKey ??
    `${input.activityId}-${input.event}-${crypto.createHash("sha1").update(JSON.stringify(input.payload)).digest("hex").slice(0, 12)}`;

  const body: SendRequestBody = {
    event: input.event,
    payload: input.payload,
    apns_env: input.apnsEnv ?? "sandbox",
    idempotency_key: idempotencyKey
  };

  if (input.visualStyle && input.visualStyle !== "minimal") {
    (body.payload as Record<string, unknown>).visualStyle = input.visualStyle;
  }

  if (input.event === "start") {
    body.attributes_type = "ReportKitSimpleAttributes";
    body.attributes = {
      reportID: input.activityId
    };
  }

  return body;
}

export function buildAlarmBody(input: {
  title: string;
  apnsEnv?: ApnsEnv;
  fireInSeconds?: number;
  fireAt?: string;
  alarmId?: string;
  alertTitle?: string;
  alertBody?: string;
  deviceInstallId?: string;
}): AlarmRequestBody {
  const title = input.title.trim();
  if (!title) {
    throw new Error("Alarm title cannot be empty");
  }

  const body: AlarmRequestBody = {
    title,
    apns_env: input.apnsEnv ?? "sandbox",
  };

  if (typeof input.fireInSeconds === "number") {
    if (!Number.isFinite(input.fireInSeconds) || input.fireInSeconds < 1) {
      throw new Error(`Invalid fireInSeconds: ${input.fireInSeconds}`);
    }
    body.fire_in_seconds = Math.trunc(input.fireInSeconds);
  }

  if (input.fireAt) {
    const fireAt = input.fireAt.trim();
    if (!fireAt || Number.isNaN(Date.parse(fireAt))) {
      throw new Error(`Invalid fireAt: ${input.fireAt}`);
    }
    body.fire_at = fireAt;
  }

  if (!body.fire_in_seconds && !body.fire_at) {
    throw new Error("Alarm requires --in-seconds or --fire-at");
  }

  if (input.alarmId?.trim()) {
    body.alarm_id = input.alarmId.trim();
  }
  if (input.alertTitle?.trim()) {
    body.alert_title = input.alertTitle.trim();
  }
  if (input.alertBody?.trim()) {
    body.alert_body = input.alertBody.trim();
  }
  if (input.deviceInstallId?.trim()) {
    body.device_install_id = input.deviceInstallId.trim();
  }

  return body;
}
