import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import type { ReportKitConfig } from "./types.js";

const DEFAULT_SUPABASE_URL = "https://bsakakesupfudupbxflj.supabase.co";
const DEFAULT_SUPABASE_ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzYWtha2VzdXBmdWR1cGJ4ZmxqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIwODI4NDQsImV4cCI6MjA4NzY1ODg0NH0.oFUeZiR8Nz01pdY0FCh6OP38LveHKYlmL46jMxnUhBo";

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
  return {
    supabaseUrl: process.env.REPORTKIT_SUPABASE_URL ?? DEFAULT_SUPABASE_URL,
    supabaseAnonKey: process.env.REPORTKIT_SUPABASE_ANON_KEY ?? DEFAULT_SUPABASE_ANON_KEY,
    session: null,
  };
}

export function readConfig(): ReportKitConfig {
  ensureConfigDir();
  if (!fs.existsSync(configPath())) {
    return defaultConfig();
  }

  const parsed = JSON.parse(fs.readFileSync(configPath(), "utf8")) as Partial<ReportKitConfig>;
  return {
    ...defaultConfig(),
    ...parsed,
    session: parsed.session ?? null
  };
}

export function writeConfig(config: ReportKitConfig): void {
  ensureConfigDir();
  fs.writeFileSync(configPath(), JSON.stringify(config, null, 2) + "\n", "utf8");
}

export function ensureConfigDir(): void {
  fs.mkdirSync(configDir(), { recursive: true });
  fs.mkdirSync(logDir(), { recursive: true });
}
