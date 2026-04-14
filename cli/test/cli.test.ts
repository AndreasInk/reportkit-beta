import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import process from "node:process";
import { Readable } from "node:stream";
import { buildAlarmBody, buildSendBody, normalizeVisualStyle } from "../src/format.js";
import { resolveAuthCredentials, statusCommand } from "../src/commands.js";
import { configPath, defaultConfig, readConfig, writeConfig } from "../src/config.js";
import { cliSignIn } from "../src/api.js";
import { deleteSessionSecrets, loadSessionSecrets, sessionStorePath, writeSessionSecrets } from "../src/secureSessionStore.js";

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

function withTemporarySessionStore(run: () => void): void {
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), "reportkit-session-"));
  const originalStoreFile = process.env.REPORTKIT_SESSION_STORE_FILE;
  const originalKeychainMock = process.env.REPORTKIT_SESSION_KEYCHAIN_MOCK_FILE;

  process.env.REPORTKIT_SESSION_STORE_FILE = path.join(tempRoot, "session-store.json");
  process.env.REPORTKIT_SESSION_KEYCHAIN_MOCK_FILE = path.join(tempRoot, "session-keychain.json");

  try {
    run();
  } finally {
    if (originalStoreFile === undefined) {
      delete process.env.REPORTKIT_SESSION_STORE_FILE;
    } else {
      process.env.REPORTKIT_SESSION_STORE_FILE = originalStoreFile;
    }

    if (originalKeychainMock === undefined) {
      delete process.env.REPORTKIT_SESSION_KEYCHAIN_MOCK_FILE;
    } else {
      process.env.REPORTKIT_SESSION_KEYCHAIN_MOCK_FILE = originalKeychainMock;
    }

    fs.rmSync(tempRoot, { recursive: true, force: true });
  }
}

test("buildSendBody adds ReportKitSimple attributes for start events", () => {
  const body = buildSendBody({
    event: "start",
    activityId: "daily-pulse",
    payload: { title: "Daily Pulse", summary: "Start event" }
  });

  assert.equal(body.attributes_type, "ReportKitSimpleAttributes");
  assert.deepEqual(body.attributes, { reportID: "daily-pulse" });
});

test("buildSendBody uses explicit idempotency key when provided", () => {
  const body = buildSendBody({
    event: "update",
    activityId: "daily-pulse",
    payload: { title: "Daily Pulse", summary: "Update event" },
    idempotencyKey: "fixed-key"
  });

  assert.equal(body.idempotency_key, "fixed-key");
});

test("normalizeVisualStyle accepts progress", () => {
  assert.equal(normalizeVisualStyle("progress"), "progress");
});

test("buildSendBody preserves progress payload fields", () => {
  const body = buildSendBody({
    event: "update",
    activityId: "codex-agent",
    payload: {
      title: "Ship Agent Progress Template",
      summary: "Updated the widget payload schema.",
      progressPercent: 68,
      completedSteps: 17,
      totalSteps: 25
    },
    visualStyle: "progress"
  });

  assert.equal(body.payload.visualStyle, "progress");
  assert.equal(body.payload.progressPercent, 68);
  assert.equal(body.payload.completedSteps, 17);
  assert.equal(body.payload.totalSteps, 25);
});

test("buildAlarmBody supports fire_in_seconds payloads", () => {
  const body = buildAlarmBody({
    title: "Security check",
    fireInSeconds: 60,
    apnsEnv: "production",
    alarmId: "alarm-123",
  });

  assert.deepEqual(body, {
    title: "Security check",
    apns_env: "production",
    fire_in_seconds: 60,
    alarm_id: "alarm-123",
  });
});

test("buildAlarmBody supports fire_at payloads", () => {
  const body = buildAlarmBody({
    title: "Delayed review",
    fireAt: "2026-04-13T10:30:00.000Z",
    alertTitle: "ReportKit Alarm",
    alertBody: "Check the current run.",
    deviceInstallId: "device-1",
  });

  assert.deepEqual(body, {
    title: "Delayed review",
    apns_env: "sandbox",
    fire_at: "2026-04-13T10:30:00.000Z",
    alert_title: "ReportKit Alarm",
    alert_body: "Check the current run.",
    device_install_id: "device-1",
  });
});

test("statusCommand labels expiry as cached local session metadata", () => {
  withTemporarySessionStore(() => {
    withTemporaryConfigFile(() => {
      writeSessionSecrets({
        accessToken: "access",
        refreshToken: "refresh",
      });
      writeConfig({
        supabaseUrl: "https://project-ref.supabase.co",
        supabaseAnonKey: "sb_publishable_dummy_key",
        session: {
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
      assert.match(lines.join("\n"), /Secure session store: /);
      assert.doesNotMatch(lines.join("\n"), /Token expires at:/);
    });
  });
});

test("statusCommand flags expired cached sessions", () => {
  withTemporarySessionStore(() => {
    withTemporaryConfigFile(() => {
      writeSessionSecrets({
        accessToken: "access",
        refreshToken: "refresh",
      });
      writeConfig({
        supabaseUrl: "https://project-ref.supabase.co",
        supabaseAnonKey: "sb_publishable_dummy_key",
        session: {
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

test("readConfig ignores stored Supabase values and keeps stored session metadata", () => {
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

test("readConfig migrates legacy plaintext session secrets into the secure store", () => {
  withTemporarySessionStore(() => {
    const tempHome = fs.mkdtempSync(path.join(os.tmpdir(), "reportkit-home-"));
    const runtimeDir = path.join(tempHome, ".reportkit");
    const localConfigDir = path.join(tempHome, ".config", "reportkit-simple");
    fs.mkdirSync(runtimeDir, { recursive: true });
    fs.mkdirSync(localConfigDir, { recursive: true });

    fs.writeFileSync(
      path.join(runtimeDir, ".env"),
      [
        "REPORTKIT_SUPABASE_URL=https://machine-global.supabase.co",
        "REPORTKIT_SUPABASE_ANON_KEY=sb_publishable_global_token"
      ].join("\n"),
      "utf8"
    );

    fs.writeFileSync(
      path.join(localConfigDir, "config.json"),
      JSON.stringify({
        session: {
          accessToken: "legacy-access",
          refreshToken: "legacy-refresh",
          userID: "user-123",
          email: "user@example.com",
          expiresAt: "2099-01-01T00:00:00.000Z"
        }
      }),
      "utf8"
    );

    const originalHome = process.env.HOME;
    const originalRuntimeDir = process.env.REPORTKIT_RUNTIME_DIR;
    delete process.env.REPORTKIT_RUNTIME_DIR;
    process.env.HOME = tempHome;

    try {
      const config = readConfig();
      const secureSession = loadSessionSecrets();
      const rawConfig = JSON.parse(fs.readFileSync(path.join(localConfigDir, "config.json"), "utf8")) as {
        session?: Record<string, unknown>;
      };

      assert.equal(config.session?.email, "user@example.com");
      assert.deepEqual(secureSession, {
        accessToken: "legacy-access",
        refreshToken: "legacy-refresh",
      });
      assert.deepEqual(rawConfig.session, {
        userID: "user-123",
        email: "user@example.com",
        expiresAt: "2099-01-01T00:00:00.000Z"
      });
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

      fs.rmSync(tempHome, { recursive: true, force: true });
      deleteSessionSecrets();
    }
  });
});

test("secure session store writes canonical file with local-only permissions", () => {
  withTemporarySessionStore(() => {
    writeSessionSecrets({
      accessToken: "access",
      refreshToken: "refresh",
    });

    const stats = fs.statSync(sessionStorePath());
    assert.equal(stats.mode & 0o777, 0o600);
  });
});

test("resolveAuthCredentials rejects insecure password inputs", async () => {
  await assert.rejects(
    () => resolveAuthCredentials(new Map([["password", "secret"]]), {}),
    /`--password` is not supported/,
  );

  await assert.rejects(
    () => resolveAuthCredentials(new Map(), { REPORTKIT_EMAIL: "user@example.com", REPORTKIT_PASSWORD: "secret" }),
    /`REPORTKIT_PASSWORD` is not supported/,
  );
});

test("resolveAuthCredentials reads password from stdin when requested", async () => {
  const credentials = await resolveAuthCredentials(
    new Map<string, string | true>([["email", "user@example.com"], ["password-stdin", true]]),
    {},
    Readable.from(["s3cr3t\n"]),
  );

  assert.deepEqual(credentials, {
    email: "user@example.com",
    password: "s3cr3t",
  });
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
