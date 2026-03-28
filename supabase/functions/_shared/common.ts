export type ApnsEnv = "sandbox" | "production";
export type LiveActivityEvent = "start" | "update" | "end";

export function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "content-type": "application/json",
      "cache-control": "no-store",
    },
  });
}

export async function readJsonBody(req: Request): Promise<Record<string, unknown> | null> {
  try {
    const body = await req.json();
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      return null;
    }
    return body as Record<string, unknown>;
  } catch {
    return null;
  }
}

export function parseApnsEnv(value: unknown): ApnsEnv | null {
  const env = String(value ?? "sandbox").trim().toLowerCase();
  if (env === "sandbox" || env === "production") {
    return env;
  }
  return null;
}

export function parseLiveActivityEvent(value: unknown): LiveActivityEvent | null {
  const event = String(value ?? "").trim().toLowerCase();
  if (event === "start" || event === "update" || event === "end") {
    return event;
  }
  return null;
}

export function normalizeTokenHex(value: unknown): string | null {
  const token = String(value ?? "").trim().toLowerCase();
  if (!token) return null;
  if (!/^[0-9a-f]+$/.test(token)) return null;
  if (token.length < 64 || token.length > 1024) return null;
  if (token.length % 2 !== 0) return null;
  return token;
}

export function normalizeInstallID(value: unknown): string | null {
  const installID = String(value ?? "").trim();
  if (!installID) return null;
  if (installID.length > 255) return null;
  return installID;
}

export function normalizeOptionalInstallID(value: unknown): string | null {
  const raw = String(value ?? "").trim();
  if (!raw) return null;
  if (raw.length > 255) return null;
  return raw;
}

function stableSortObject(obj: Record<string, unknown>): Record<string, unknown> {
  const sortedEntries = Object.entries(obj)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([key, value]) => [key, stableValue(value)] as const);
  return Object.fromEntries(sortedEntries);
}

function stableValue(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map((item) => stableValue(item));
  }
  if (value && typeof value === "object") {
    return stableSortObject(value as Record<string, unknown>);
  }
  return value;
}

export function stableJSONString(value: unknown): string {
  return JSON.stringify(stableValue(value));
}

export async function sha256Hex(input: string): Promise<string> {
  const bytes = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export function requireEnv(name: string): string {
  const value = Deno.env.get(name)?.trim() ?? "";
  if (!value) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value;
}

export function asObject(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
}

export function asOptionalInteger(value: unknown): number | null {
  if (value === null || value === undefined || value === "") {
    return null;
  }
  const num = Number(value);
  if (!Number.isFinite(num)) return null;
  return Math.trunc(num);
}
