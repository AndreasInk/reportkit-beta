export type ApnsEnv = "sandbox" | "production";
export type LiveActivityEvent = "start" | "update" | "end";
export type Status = "good" | "warning" | "critical";
export type VisualStyle = "minimal" | "banner" | "chart";

export interface CliSessionMetadata {
  userID: string;
  email: string;
  expiresAt: string;
}

export interface CliSessionSecrets {
  accessToken: string;
  refreshToken: string;
}

export interface CliSession extends CliSessionMetadata, CliSessionSecrets {}

export interface CliLoginResponse {
  access_token: string;
  token_type: string;
  expires_in: number;
  refresh_token: string;
  user: {
    id: string;
    email: string;
  };
}

export interface ReportKitConfig {
  supabaseUrl: string;
  supabaseAnonKey: string;
  session: CliSessionMetadata | null;
}

export interface SendRequestBody {
  event: LiveActivityEvent;
  payload: Record<string, unknown>;
  apns_env: ApnsEnv;
  idempotency_key: string;
  attributes_type?: string;
  attributes?: Record<string, unknown>;
}
