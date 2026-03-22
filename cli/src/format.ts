import crypto from "node:crypto";
import type { ApnsEnv, SendRequestBody, Status, VisualStyle } from "./types.js";

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
  if (!value || value === "minimal" || value === "banner" || value === "chart") {
    return (value as VisualStyle | undefined) ?? "minimal";
  }
  throw new Error(`Invalid visual style: ${value}`);
}

export function buildSendBody(input: {
  event: "start" | "update" | "end";
  activityId: string;
  payload: Record<string, unknown>;
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
