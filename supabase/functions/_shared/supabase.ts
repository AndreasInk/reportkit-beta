import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { requireEnv } from "./common.ts";

export function createServiceClient() {
  const supabaseUrl = requireEnv("SUPABASE_URL");
  const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY"); // reportkit:allow-secret
  return createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}

export type RequestIdentity = { kind: "supabase"; user: { id: string } };

function bearerTokenFrom(req: Request): string | null {
  const authHeader = req.headers.get("authorization") ?? req.headers.get("Authorization") ?? "";
  if (!authHeader.toLowerCase().startsWith("bearer ")) {
    return null;
  }
  const token = authHeader.slice(7).trim();
  return token.length > 0 ? token : null;
}

async function resolveSupabaseUser(
  req: Request,
  supabase: ReturnType<typeof createServiceClient>,
  accessToken: string
): Promise<{ id: string } | null> {
  // Some Supabase edge functions receive an authenticated user id header.
  const gatewayUser = req.headers.get("x-supabase-auth-user");
  if (gatewayUser && gatewayUser.trim().length > 0) {
    return { id: gatewayUser.trim() };
  }

  // Primary path: validate bearer token directly.
  const supabaseUrl = requireEnv("SUPABASE_URL");
  const anonOrServiceKey =
    Deno.env.get("SUPABASE_ANON_KEY")?.trim() ??
    requireEnv("SUPABASE_SERVICE_ROLE_KEY"); // reportkit:allow-secret
  try {
    const authContextClient = createClient(supabaseUrl, anonOrServiceKey, {
      global: {
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
      },
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });
    const { data, error } = await authContextClient.auth.getUser();
    if (!error && data.user?.id) {
      return { id: data.user.id };
    }
  } catch {
    // Fall through to service-role check below.
  }

  const { data, error } = await supabase.auth.getUser(accessToken);
  if (!error && data.user?.id) {
    return { id: data.user.id };
  }

  return null;
}

export async function requireUser(
  req: Request,
  supabase: ReturnType<typeof createServiceClient>,
): Promise<{ id: string } | null> {
  const accessToken = bearerTokenFrom(req);
  if (!accessToken) {
    return null;
  }
  return resolveSupabaseUser(req, supabase, accessToken);
}

export async function requireSupabaseUser(
  req: Request,
  supabase: ReturnType<typeof createServiceClient>,
): Promise<{ id: string } | null> {
  return requireUser(req, supabase);
}
