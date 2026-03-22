import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import type { ReportKitConfig } from "./types.js";

function resolveConfigValue(value: string | undefined, label: string): string {
  if (!value || value.trim() === "") {
    throw new Error(
      `Missing ${label}. Set ${label} in env vars or in ${configPath()} ` +
        "(for example via config file or CLI setup).",
    );
  }

  return value.trim();
}

function mergeConfig(parsed: Partial<ReportKitConfig>): ReportKitConfig {
  const envUrl = process.env.REPORTKIT_SUPABASE_URL?.trim();
  const envAnon = process.env.REPORTKIT_SUPABASE_ANON_KEY?.trim();
  const merged: ReportKitConfig = {
    supabaseUrl: envUrl ?? parsed.supabaseUrl,
    supabaseAnonKey: envAnon ?? parsed.supabaseAnonKey,
    session: parsed.session ?? null,
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
  fs.writeFileSync(configPath(), JSON.stringify(config, null, 2) + "\n", "utf8");
}

export function ensureConfigDir(): void {
  fs.mkdirSync(configDir(), { recursive: true });
  fs.mkdirSync(logDir(), { recursive: true });
}
