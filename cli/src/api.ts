import type {
  CliSession,
  CliLoginResponse,
  ReportKitConfig,
  SendRequestBody
} from "./types.js";
import { writeConfig } from "./config.js";

interface RequestOptions {
  method?: "GET" | "POST";
  body?: unknown;
  session?: CliSession | null;
}

function describeNetworkError(error: unknown): string {
  if (!(error instanceof Error)) {
    return String(error);
  }

  const cause = error.cause;
  if (cause instanceof Error) {
    const details = [cause.message];
    const code = "code" in cause ? String((cause as { code?: unknown }).code ?? "") : "";
    if (code && !details.includes(code)) {
      details.push(code);
    }
    return `${error.message}: ${details.join(" [")}${details.length > 1 ? "]" : ""}`;
  }

  if (cause) {
    return `${error.message}: ${String(cause)}`;
  }

  return error.message;
}

async function fetchJSON<T>(
  url: URL | string,
  init: RequestInit,
  context: string
): Promise<T> {
  let response: Response;
  try {
    response = await fetch(url, init);
  } catch (error) {
    throw new Error(`${context} request failed for ${String(url)}: ${describeNetworkError(error)}`);
  }

  const text = await response.text();
  const data = text ? (JSON.parse(text) as T | { error?: string }) : ({} as T);
  if (!response.ok) {
    const error = typeof data === "object" && data && "error" in data ? String(data.error ?? text) : text;
    throw new Error(`${context} failed (${response.status}): ${error}`);
  }

  return data as T;
}

async function requestJSON<T>(
  config: ReportKitConfig,
  functionName: string,
  options: RequestOptions = {}
): Promise<T> {
  const withToken = async (token: string): Promise<T> => {
    return fetchJSON<T>(urlFor(functionName, config.supabaseUrl), {
      method: options.method ?? "POST",
      headers: {
        "content-type": "application/json",
        apikey: config.supabaseAnonKey,
        authorization: `Bearer ${token}`
      },
      body: options.body === undefined ? undefined : JSON.stringify(options.body)
    }, functionName);
  };

  if (!options.session?.accessToken) {
    throw new Error("No session access token. Run reportkit auth first.");
  }

  try {
    return await withToken(options.session.accessToken);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (!message.includes("401")) {
      throw error;
    }
  }

  if (!options.session.refreshToken) {
    throw new Error("Session expired. Run reportkit auth again.");
  }

  const refreshed = await refreshSession(config);
  options.session.accessToken = refreshed.access_token;
  options.session.refreshToken = refreshed.refresh_token;
  options.session.expiresAt = new Date(Date.now() + refreshed.expires_in * 1000).toISOString();
  writeSession(config, options.session);

  return withToken(options.session.accessToken);
}

function writeSession(config: ReportKitConfig, session: ReportKitConfig["session"]): void {
  if (!session) return;
  config.session = session;
  writeConfig(config);
}

function urlFor(functionName: string, supabaseUrl: string): string {
  return new URL(`/functions/v1/${functionName}`, supabaseUrl).toString();
}

async function refreshSession(config: ReportKitConfig): Promise<CliLoginResponse> {
  if (!config.session?.refreshToken) {
    throw new Error("Missing refresh token.");
  }

  const url = new URL("/auth/v1/token", config.supabaseUrl);
  url.searchParams.set("grant_type", "refresh_token");

  return fetchJSON<CliLoginResponse>(url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      apikey: config.supabaseAnonKey
    },
    body: JSON.stringify({
      refresh_token: config.session.refreshToken
    })
  }, "auth refresh");
}

export function cliSignIn(
  config: ReportKitConfig,
  email: string,
  password: string
): Promise<CliLoginResponse> {
  const url = new URL("/auth/v1/token", config.supabaseUrl);
  url.searchParams.set("grant_type", "password");

  return fetchJSON<CliLoginResponse>(url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      apikey: config.supabaseAnonKey
    },
    body: JSON.stringify({
      email,
      password
    })
  }, "auth");
}

export function sendLiveActivity(
  config: ReportKitConfig,
  body: SendRequestBody
): Promise<Record<string, unknown>> {
  return requestJSON<Record<string, unknown>>(config, "reportkit-send-live-activity", {
    body,
    session: config.session
  });
}
