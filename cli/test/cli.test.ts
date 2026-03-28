import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import process from "node:process";
import { buildSendBody } from "../src/format.js";
import { statusCommand } from "../src/commands.js";
import { configPath, defaultConfig, readConfig, writeConfig } from "../src/config.js";
import { cliSignIn } from "../src/api.js";

function withTemporaryConfigFile(run: () => void): void {
  const targetPath = configPath();
  const original = fs.existsSync(targetPath) ? fs.readFileSync(targetPath, "utf8") : null;

  try {
    run();
  } finally {
    if (original === null) {
      fs.rmSync(targetPath, { force: true });
    } else {
      fs.writeFileSync(targetPath, original, "utf8");
    }
  }
}

test("buildSendBody adds ReportKitSimple attributes for start events", () => {
  const body = buildSendBody({
    event: "start",
    activityId: "daily-pulse",
    payload: { title: "Daily Pulse" }
  });

  assert.equal(body.attributes_type, "ReportKitSimpleAttributes");
  assert.deepEqual(body.attributes, { reportID: "daily-pulse" });
});

test("buildSendBody uses explicit idempotency key when provided", () => {
  const body = buildSendBody({
    event: "update",
    activityId: "daily-pulse",
    payload: { title: "Daily Pulse" },
    idempotencyKey: "fixed-key"
  });

  assert.equal(body.idempotency_key, "fixed-key");
});

test("statusCommand labels expiry as cached local session metadata", () => {
  withTemporaryConfigFile(() => {
    writeConfig({
      supabaseUrl: "https://project-ref.supabase.co",
      supabaseAnonKey: "sb_publishable_dummy_key",
      session: {
        accessToken: "access",
        refreshToken: "refresh",
        userID: "user-123",
        email: "user@example.com",
        expiresAt: "2099-01-01T00:00:00.000Z"
      }
    });

    const lines: string[] = [];
    const originalLog = console.log;
    console.log = (message?: unknown) => {
      lines.push(String(message ?? ""));
    };

    try {
      statusCommand();
    } finally {
      console.log = originalLog;
    }

    assert.match(lines.join("\n"), /Cached session expires at: 2099-01-01T00:00:00.000Z/);
    assert.match(lines.join("\n"), /Status shows local cached session metadata only\./);
    assert.doesNotMatch(lines.join("\n"), /Token expires at:/);
  });
});

test("statusCommand flags expired cached sessions", () => {
  withTemporaryConfigFile(() => {
    writeConfig({
      supabaseUrl: "https://project-ref.supabase.co",
      supabaseAnonKey: "sb_publishable_dummy_key",
      session: {
        accessToken: "access",
        refreshToken: "refresh",
        userID: "user-123",
        email: "user@example.com",
        expiresAt: "2000-01-01T00:00:00.000Z"
      }
    });

    const lines: string[] = [];
    const originalLog = console.log;
    console.log = (message?: unknown) => {
      lines.push(String(message ?? ""));
    };

    try {
      statusCommand();
    } finally {
      console.log = originalLog;
    }

    assert.match(lines.join("\n"), /Cached session expired at: 2000-01-01T00:00:00.000Z/);
    assert.match(lines.join("\n"), /next authenticated request will try to refresh it/);
  });
});

test("defaultConfig rejects placeholder Supabase settings", () => {
  const originalUrl = process.env.REPORTKIT_SUPABASE_URL;
  const originalAnon = process.env.REPORTKIT_SUPABASE_ANON_KEY;
  process.env.REPORTKIT_SUPABASE_URL = "https://example.supabase.co";
  process.env.REPORTKIT_SUPABASE_ANON_KEY = "anon-key";

  try {
    assert.throws(
      () => defaultConfig(),
      /Invalid REPORTKIT_SUPABASE_URL: https:\/\/example\.supabase\.co/
    );
  } finally {
    if (originalUrl === undefined) {
      delete process.env.REPORTKIT_SUPABASE_URL;
    } else {
      process.env.REPORTKIT_SUPABASE_URL = originalUrl;
    }

    if (originalAnon === undefined) {
      delete process.env.REPORTKIT_SUPABASE_ANON_KEY;
    } else {
      process.env.REPORTKIT_SUPABASE_ANON_KEY = originalAnon;
    }
  }
});

test("defaultConfig reads machine-global ReportKit env before local config", () => {
  const tempHome = fs.mkdtempSync(path.join(os.tmpdir(), "reportkit-home-"));
  const runtimeDir = path.join(tempHome, ".reportkit");
  fs.mkdirSync(runtimeDir, { recursive: true });
  fs.writeFileSync(
    path.join(runtimeDir, ".env"),
    [
      "REPORTKIT_SUPABASE_URL=https://machine-global.supabase.co",
      "REPORTKIT_SUPABASE_ANON_KEY=sb_publishable_global_token"
    ].join("\n"),
    "utf8"
  );

  const originalHome = process.env.HOME;
  const originalRuntimeDir = process.env.REPORTKIT_RUNTIME_DIR;
  const originalUrl = process.env.REPORTKIT_SUPABASE_URL;
  const originalAnon = process.env.REPORTKIT_SUPABASE_ANON_KEY;

  delete process.env.REPORTKIT_SUPABASE_URL;
  delete process.env.REPORTKIT_SUPABASE_ANON_KEY;
  delete process.env.REPORTKIT_RUNTIME_DIR;
  process.env.HOME = tempHome;

  try {
    const config = defaultConfig();
    assert.equal(config.supabaseUrl, "https://machine-global.supabase.co");
    assert.equal(config.supabaseAnonKey, "sb_publishable_global_token");
  } finally {
    if (originalHome === undefined) {
      delete process.env.HOME;
    } else {
      process.env.HOME = originalHome;
    }

    if (originalRuntimeDir === undefined) {
      delete process.env.REPORTKIT_RUNTIME_DIR;
    } else {
      process.env.REPORTKIT_RUNTIME_DIR = originalRuntimeDir;
    }

    if (originalUrl === undefined) {
      delete process.env.REPORTKIT_SUPABASE_URL;
    } else {
      process.env.REPORTKIT_SUPABASE_URL = originalUrl;
    }

    if (originalAnon === undefined) {
      delete process.env.REPORTKIT_SUPABASE_ANON_KEY;
    } else {
      process.env.REPORTKIT_SUPABASE_ANON_KEY = originalAnon;
    }

    fs.rmSync(tempHome, { recursive: true, force: true });
  }
});

test("readConfig ignores stored Supabase values and keeps stored session", () => {
  const tempHome = fs.mkdtempSync(path.join(os.tmpdir(), "reportkit-home-"));
  const runtimeDir = path.join(tempHome, ".reportkit");
  const configDir = path.join(tempHome, ".config", "reportkit-simple");
  fs.mkdirSync(runtimeDir, { recursive: true });
  fs.mkdirSync(configDir, { recursive: true });

  fs.writeFileSync(
    path.join(runtimeDir, ".env"),
    [
      "REPORTKIT_SUPABASE_URL=https://machine-global.supabase.co",
      "REPORTKIT_SUPABASE_ANON_KEY=sb_publishable_global_token"
    ].join("\n"),
    "utf8"
  );

  fs.writeFileSync(
    path.join(configDir, "config.json"),
    JSON.stringify({
      supabaseUrl: "https://stale-config.supabase.co",
      supabaseAnonKey: "stale-config-anon-key",
      session: {
        accessToken: "access",
        refreshToken: "refresh",
        userID: "user-123",
        email: "user@example.com",
        expiresAt: "2099-01-01T00:00:00.000Z"
      }
    }),
    "utf8"
  );

  const originalHome = process.env.HOME;
  const originalRuntimeDir = process.env.REPORTKIT_RUNTIME_DIR;
  const originalUrl = process.env.REPORTKIT_SUPABASE_URL;
  const originalAnon = process.env.REPORTKIT_SUPABASE_ANON_KEY;

  delete process.env.REPORTKIT_SUPABASE_URL;
  delete process.env.REPORTKIT_SUPABASE_ANON_KEY;
  delete process.env.REPORTKIT_RUNTIME_DIR;
  process.env.HOME = tempHome;

  try {
    const config = readConfig();
    assert.equal(config.supabaseUrl, "https://machine-global.supabase.co");
    assert.equal(config.supabaseAnonKey, "sb_publishable_global_token");
    assert.equal(config.session?.email, "user@example.com");
  } finally {
    if (originalHome === undefined) {
      delete process.env.HOME;
    } else {
      process.env.HOME = originalHome;
    }

    if (originalRuntimeDir === undefined) {
      delete process.env.REPORTKIT_RUNTIME_DIR;
    } else {
      process.env.REPORTKIT_RUNTIME_DIR = originalRuntimeDir;
    }

    if (originalUrl === undefined) {
      delete process.env.REPORTKIT_SUPABASE_URL;
    } else {
      process.env.REPORTKIT_SUPABASE_URL = originalUrl;
    }

    if (originalAnon === undefined) {
      delete process.env.REPORTKIT_SUPABASE_ANON_KEY;
    } else {
      process.env.REPORTKIT_SUPABASE_ANON_KEY = originalAnon;
    }

    fs.rmSync(tempHome, { recursive: true, force: true });
  }
});

test("cliSignIn includes request URL and cause for fetch errors", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = (async () => {
    const cause = new Error("getaddrinfo ENOTFOUND example.supabase.co");
    Object.assign(cause, { code: "ENOTFOUND" });
    const error = new TypeError("fetch failed");
    Object.assign(error, { cause });
    throw error;
  }) as typeof fetch;

  try {
    await assert.rejects(
      () =>
        cliSignIn(
          {
            supabaseUrl: "https://example.supabase.co",
            supabaseAnonKey: "anon-key",
            session: null
          },
          "user@example.com",
          "password"
        ),
      /auth request failed for https:\/\/example\.supabase\.co\/auth\/v1\/token\?grant_type=password: fetch failed: getaddrinfo ENOTFOUND example\.supabase\.co \[ENOTFOUND\]/
    );
  } finally {
    globalThis.fetch = originalFetch;
  }
});
