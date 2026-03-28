import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import type { CliSessionSecrets } from "./types.js";

interface SessionRecord<T> {
  state: T | null;
  error: unknown;
}

interface PersistedSessionSecretRecord extends CliSessionSecrets {
  version: 1;
}

const DEFAULT_CONFIG_DIR_NAME = "reportkit-simple";
const DEFAULT_SESSION_STORE_FILE = "session-store.json";
const KEYCHAIN_SERVICE = "com.reportkit.simple.cli.session";
const KEYCHAIN_ACCOUNT = "default";

let hasLoggedKeychainMismatch = false;

export function sessionStorePath(): string {
  return normalizeNonEmptyString(process.env.REPORTKIT_SESSION_STORE_FILE)
    || path.join(configDir(), DEFAULT_SESSION_STORE_FILE);
}

export function loadSessionSecrets(): CliSessionSecrets | null {
  const fileRecord = readCanonicalFileStateRecord();
  const keychainRecord = readKeychainStateRecord();

  if (fileRecord.state) {
    reconcileLegacyKeychainMirror(fileRecord.state, keychainRecord);
    return fileRecord.state;
  }

  if (fileRecord.error) {
    if (keychainRecord.state) {
      warnOnce(
        "[reportkit] Recovering the canonical session-store.json from the legacy Keychain session mirror.",
      );
      writeSessionSecrets(keychainRecord.state);
      return keychainRecord.state;
    }
    throw corruptedStateError("session-store.json", fileRecord.error);
  }

  if (keychainRecord.error) {
    throw corruptedStateError("legacy Keychain session mirror", keychainRecord.error);
  }

  if (keychainRecord.state) {
    writeSessionSecrets(keychainRecord.state);
    return keychainRecord.state;
  }

  return null;
}

export function writeSessionSecrets(secrets: CliSessionSecrets): void {
  const normalized = normalizeSessionSecrets({
    version: 1,
    accessToken: secrets.accessToken,
    refreshToken: secrets.refreshToken,
  });
  const serialized = JSON.stringify(normalized, null, 2);
  writeCanonicalFileStateString(serialized);
  writeKeychainStateString(serialized);
}

export function deleteSessionSecrets(): {
  hadState: boolean;
  removedCanonicalFile: boolean;
  removedKeychainMirror: boolean;
} {
  const removedCanonicalFile = deleteCanonicalFileState();
  const removedKeychainMirror = deleteKeychainStateString();
  return {
    hadState: removedCanonicalFile || removedKeychainMirror,
    removedCanonicalFile,
    removedKeychainMirror,
  };
}

function configDir(): string {
  const base = process.env.XDG_CONFIG_HOME ?? path.join(os.homedir(), ".config");
  return path.join(base, DEFAULT_CONFIG_DIR_NAME);
}

function readCanonicalFileStateRecord(): SessionRecord<CliSessionSecrets> {
  const storeFile = sessionStorePath();
  if (!fs.existsSync(storeFile)) {
    return { state: null, error: null };
  }

  try {
    const raw = JSON.parse(fs.readFileSync(storeFile, "utf8")) as PersistedSessionSecretRecord;
    return {
      state: normalizeSessionSecrets(raw),
      error: null,
    };
  } catch (error) {
    return { state: null, error };
  }
}

function readKeychainStateRecord(): SessionRecord<CliSessionSecrets> {
  const rawState = readKeychainStateString();
  if (!rawState) {
    return { state: null, error: null };
  }

  try {
    return {
      state: normalizeSessionSecrets(JSON.parse(rawState) as PersistedSessionSecretRecord),
      error: null,
    };
  } catch (error) {
    return { state: null, error };
  }
}

function writeCanonicalFileStateString(serialized: string): void {
  const storeFile = sessionStorePath();
  fs.mkdirSync(path.dirname(storeFile), { recursive: true });
  fs.writeFileSync(storeFile, serialized, { mode: 0o600 });
  try {
    fs.chmodSync(storeFile, 0o600);
  } catch {
    // Best-effort only on filesystems without POSIX mode support.
  }
}

function resolveKeychainMirrorFile(): string {
  return normalizeNonEmptyString(process.env.REPORTKIT_SESSION_KEYCHAIN_MOCK_FILE);
}

function readKeychainStateString(): string | null {
  const keychainMirrorFile = resolveKeychainMirrorFile();
  if (keychainMirrorFile) {
    try {
      return fs.readFileSync(keychainMirrorFile, "utf8");
    } catch {
      return null;
    }
  }

  if (process.platform !== "darwin") {
    return null;
  }

  try {
    return execFileSync(
      "security",
      [
        "find-generic-password",
        "-s",
        KEYCHAIN_SERVICE,
        "-a",
        KEYCHAIN_ACCOUNT,
        "-w",
      ],
      { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] },
    ).trim();
  } catch {
    return null;
  }
}

function writeKeychainStateString(value: string): boolean {
  const keychainMirrorFile = resolveKeychainMirrorFile();
  if (keychainMirrorFile) {
    try {
      fs.mkdirSync(path.dirname(keychainMirrorFile), { recursive: true });
      fs.writeFileSync(keychainMirrorFile, value, { mode: 0o600 });
      try {
        fs.chmodSync(keychainMirrorFile, 0o600);
      } catch {
        // Best-effort only on filesystems without POSIX mode support.
      }
      return true;
    } catch {
      return false;
    }
  }

  if (process.platform !== "darwin") {
    return false;
  }

  try {
    execFileSync(
      "security",
      [
        "add-generic-password",
        "-U",
        "-s",
        KEYCHAIN_SERVICE,
        "-a",
        KEYCHAIN_ACCOUNT,
        "-w",
        value,
      ],
      { stdio: ["ignore", "ignore", "ignore"] },
    );
    return true;
  } catch {
    return false;
  }
}

function deleteKeychainStateString(): boolean {
  const keychainMirrorFile = resolveKeychainMirrorFile();
  if (keychainMirrorFile) {
    const existed = fs.existsSync(keychainMirrorFile);
    try {
      fs.rmSync(keychainMirrorFile, { force: true });
      return existed;
    } catch {
      return false;
    }
  }

  if (process.platform !== "darwin") {
    return false;
  }

  try {
    execFileSync(
      "security",
      [
        "delete-generic-password",
        "-s",
        KEYCHAIN_SERVICE,
        "-a",
        KEYCHAIN_ACCOUNT,
      ],
      { stdio: ["ignore", "ignore", "ignore"] },
    );
    return true;
  } catch {
    return false;
  }
}

function deleteCanonicalFileState(): boolean {
  const storeFile = sessionStorePath();
  const existed = fs.existsSync(storeFile);
  try {
    fs.rmSync(storeFile, { force: true });
    return existed;
  } catch {
    return false;
  }
}

function reconcileLegacyKeychainMirror(
  canonicalState: CliSessionSecrets,
  keychainRecord: SessionRecord<CliSessionSecrets>,
): void {
  if (keychainRecord.error) {
    warnOnce("[reportkit] Ignoring unreadable legacy Keychain session mirror; using session-store.json.");
    return;
  }

  if (!keychainRecord.state) {
    writeKeychainStateString(JSON.stringify({ version: 1, ...canonicalState }, null, 2));
    return;
  }

  if (sessionSecretsEqual(canonicalState, keychainRecord.state)) {
    return;
  }

  warnOnce("[reportkit] Canonical session-store.json differs from the legacy Keychain session mirror; using session-store.json.");
  writeKeychainStateString(JSON.stringify({ version: 1, ...canonicalState }, null, 2));
}

function normalizeSessionSecrets(raw: Partial<PersistedSessionSecretRecord>): CliSessionSecrets {
  const accessToken = normalizeNonEmptyString(raw.accessToken);
  const refreshToken = normalizeNonEmptyString(raw.refreshToken);

  if (!accessToken || !refreshToken) {
    throw new Error("CLI session secrets are incomplete");
  }

  return {
    accessToken,
    refreshToken,
  };
}

function sessionSecretsEqual(left: CliSessionSecrets, right: CliSessionSecrets): boolean {
  return JSON.stringify(left) === JSON.stringify(right);
}

function normalizeNonEmptyString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function corruptedStateError(source: string, error: unknown): Error {
  const detail = normalizeNonEmptyString(error instanceof Error ? error.message : error);
  return new Error(
    `The saved ReportKit session state in ${source} is unreadable. `
      + "Run `reportkit logout` and then `reportkit auth --email ...` to start fresh."
      + (detail ? ` (${detail})` : ""),
  );
}

function warnOnce(message: string): void {
  if (hasLoggedKeychainMismatch) {
    return;
  }
  hasLoggedKeychainMismatch = true;
  console.warn(message);
}
