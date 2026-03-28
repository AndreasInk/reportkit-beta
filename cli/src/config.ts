import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import type { ReportKitConfig } from "./types.js";

const PLACEHOLDER_CONFIG_VALUES = new Map<string, string>([
  ["https://example.supabase.co", "Replace the placeholder Supabase URL with your real project URL."],
  ["YOUR_PROJECT.supabase.co", "Replace the placeholder Supabase URL with your real project URL."],
  ["anon-key", "Replace the placeholder anon key with your real Supabase anon key."],
  ["YOUR_ANON_PUBLIC_KEY", "Replace the placeholder anon key with your real Supabase anon key."]
]);

function expandHome(input: string): string {
  if (input === "~") {
    return os.homedir();
  }
  if (input.startsWith("~/")) {
    return path.join(os.homedir(), input.slice(2));
  }
  return input;
}

function parseEnvFile(filePath: string): Record<string, string> {
  if (!fs.existsSync(filePath)) {
    return {};
  }

  const output: Record<string, string> = {};
  const source = fs.readFileSync(filePath, "utf8");
  for (const rawLine of source.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) {
      continue;
    }

    const separatorIndex = line.indexOf("=");
    if (separatorIndex <= 0) {
      continue;
    }

    const key = line.slice(0, separatorIndex).trim();
    let value = line.slice(separatorIndex + 1).trim();
    const commentIndex = value.search(/\s+#/);
    if (commentIndex >= 0) {
      value = value.slice(0, commentIndex).trim();
    }

    if (
      (value.startsWith("\"") && value.endsWith("\"")) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }

    output[key] = value;
  }

  return output;
}

function reportKitRuntimeDir(): string {
  return expandHome(process.env.REPORTKIT_RUNTIME_DIR?.trim() || "~/.reportkit");
}

function machineGlobalEnv(): Record<string, string> {
  return parseEnvFile(path.join(reportKitRuntimeDir(), ".env"));
}

function resolveConfigValue(value: string | undefined, label: string): string {
  if (!value || value.trim() === "") {
    throw new Error(
      `Missing ${label}. Set ${label} in env vars or in ${path.join(reportKitRuntimeDir(), ".env")} ` +
        "(machine-global ReportKit config).",
    );
  }

  const trimmed = value.trim();
  for (const [placeholder, guidance] of PLACEHOLDER_CONFIG_VALUES) {
    if (trimmed.includes(placeholder)) {
      throw new Error(
        `Invalid ${label}: ${trimmed}. ${guidance} ` +
          `Machine-global config path: ${path.join(reportKitRuntimeDir(), ".env")}.`
      );
    }
  }

  return trimmed;
}

function mergeConfig(parsed: Partial<ReportKitConfig>): ReportKitConfig {
  const machineEnv = machineGlobalEnv();
  const envUrl = process.env.REPORTKIT_SUPABASE_URL?.trim();
  const envAnon = process.env.REPORTKIT_SUPABASE_ANON_KEY?.trim();
  const merged = {
    supabaseUrl: envUrl ?? machineEnv.REPORTKIT_SUPABASE_URL,
    supabaseAnonKey: envAnon ?? machineEnv.REPORTKIT_SUPABASE_ANON_KEY,
    session: parsed.session ?? null
  };

  return {
    ...merged,
    supabaseUrl: resolveConfigValue(merged.supabaseUrl, "REPORTKIT_SUPABASE_URL"),
    supabaseAnonKey: resolveConfigValue(merged.supabaseAnonKey, "REPORTKIT_SUPABASE_ANON_KEY"),
    session: merged.session,
  };
}

export function configDir(): string {
  const base = process.env.XDG_CONFIG_HOME ?? path.join(os.homedir(), ".config");
  return path.join(base, "reportkit-simple");
}

export function configPath(): string {
  return path.join(configDir(), "config.json");
}

export function logDir(): string {
  return path.join(configDir(), "logs");
}

export function defaultConfig(): ReportKitConfig {
  return mergeConfig({});
}

export function readConfig(): ReportKitConfig {
  ensureConfigDir();
  if (!fs.existsSync(configPath())) {
    return defaultConfig();
  }

  const parsed = JSON.parse(fs.readFileSync(configPath(), "utf8")) as Partial<ReportKitConfig>;
  return mergeConfig(parsed);
}

export function writeConfig(config: ReportKitConfig): void {
  ensureConfigDir();
  fs.writeFileSync(configPath(), JSON.stringify({ session: config.session }, null, 2) + "\n", "utf8");
}

export function ensureConfigDir(): void {
  fs.mkdirSync(configDir(), { recursive: true });
  fs.mkdirSync(logDir(), { recursive: true });
}
