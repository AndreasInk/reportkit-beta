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

async function requestJSON<T>(
  config: ReportKitConfig,
  functionName: string,
  options: RequestOptions = {}
): Promise<T> {
  const withToken = async (token: string): Promise<T> => {
    const response = await fetch(urlFor(functionName, config.supabaseUrl), {
      method: options.method ?? "POST",
      headers: {
        "content-type": "application/json",
        apikey: config.supabaseAnonKey,
        authorization: `Bearer ${token}`
      },
      body: options.body === undefined ? undefined : JSON.stringify(options.body)
    });

    const text = await response.text();
    const data = text ? (JSON.parse(text) as T | { error?: string }) : ({} as T);
    if (!response.ok) {
      const error = typeof data === "object" && data && "error" in data ? String(data.error ?? text) : text;
      throw new Error(`${functionName} failed (${response.status}): ${error}`);
    }
    return data as T;
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

  const response = await fetch(url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      apikey: config.supabaseAnonKey
    },
    body: JSON.stringify({
      refresh_token: config.session.refreshToken
    })
  });

  const text = await response.text();
  const data = text ? (JSON.parse(text) as CliLoginResponse | { error: string }) : ({} as CliLoginResponse);
  if (!response.ok) {
    const error = typeof data === "object" && data && "error" in data
      ? String((data as { error: string }).error)
      : text;
    throw new Error(`auth refresh failed (${response.status}): ${error}`);
  }

  return data as CliLoginResponse;
}

export function cliSignIn(
  config: ReportKitConfig,
  email: string,
  password: string
): Promise<CliLoginResponse> {
  const url = new URL("/auth/v1/token", config.supabaseUrl);
  url.searchParams.set("grant_type", "password");

  return fetch(url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      apikey: config.supabaseAnonKey
    },
    body: JSON.stringify({
      email,
      password
    })
  }).then(async (response) => {
    const text = await response.text();
    const data = text ? (JSON.parse(text) as CliLoginResponse | { error: string }) : ({} as CliLoginResponse);
    if (!response.ok) {
      const error = typeof data === "object" && data && "error" in data
        ? String((data as { error: string }).error)
        : text;
      throw new Error(`auth failed (${response.status}): ${error}`);
    }
    return data as CliLoginResponse;
  });
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
