import fs from "node:fs";
import path from "node:path";
import { cliSignIn, persistSessionSecrets, sendLiveActivity } from "./api.js";
import { configPath, readConfig, writeConfig } from "./config.js";
import { buildSendBody, normalizeApnsEnv, normalizeStatus, normalizeVisualStyle, optionalFlag, parseArgs, requiredFlag } from "./format.js";
import { promptForPassword, readPasswordFromStdin } from "./password.js";
import { deleteSessionSecrets, loadSessionSecrets, sessionStorePath } from "./secureSessionStore.js";
import type { ReportKitConfig } from "./types.js";

function describeSessionExpiry(expiresAt: string, now: Date = new Date()): string[] {
  const expiry = new Date(expiresAt);
  if (Number.isNaN(expiry.getTime())) {
    return [
      `Cached session expires at: ${expiresAt}`,
      "Cached session state is invalid. Run `reportkit auth --email ...`."
    ];
  }

  if (expiry <= now) {
    return [
      `Cached session expired at: ${expiresAt}`,
      "Status shows local cached session metadata only. The next authenticated request will try to refresh it, or run `reportkit auth --email ...`."
    ];
  }

  return [
    `Cached session expires at: ${expiresAt}`,
    "Status shows local cached session metadata only. It does not reflect the mobile app session."
  ];
}

export async function resolveAuthCredentials(
  flags: Map<string, string | true>,
  env: NodeJS.ProcessEnv = process.env,
  stdin: NodeJS.ReadableStream = process.stdin,
): Promise<{ email: string; password: string }> {
  if (flags.has("password")) {
    throw new Error("`--password` is not supported. Use the interactive prompt or `--password-stdin`.");
  }
  if (typeof env.REPORTKIT_PASSWORD === "string" && env.REPORTKIT_PASSWORD.trim() !== "") {
    throw new Error("`REPORTKIT_PASSWORD` is not supported. Use the interactive prompt or `--password-stdin`.");
  }

  const email = optionalFlag(flags, "email") ?? env.REPORTKIT_EMAIL;
  if (!email) {
    throw new Error("Usage: reportkit auth --email EMAIL [--password-stdin]");
  }

  const password = flags.has("password-stdin")
    ? await readPasswordFromStdin(stdin)
    : await promptForPassword();

  return { email, password };
}

function requireSession(config: ReportKitConfig): void {
  if (!config.session) {
    throw new Error("No CLI credentials found. Run `reportkit auth --email ...` first.");
  }
  if (!loadSessionSecrets()) {
    throw new Error("Stored CLI session secrets are unavailable. Run `reportkit auth --email ...` again.");
  }
}

export async function authCommand(argv: string[]): Promise<void> {
  const config = readConfig();
  const flags = parseArgs(argv);
  const credentials = await resolveAuthCredentials(flags);

  const login = await cliSignIn(config, credentials.email, credentials.password);
  config.session = {
    userID: login.user.id,
    email: login.user.email,
    expiresAt: new Date(Date.now() + login.expires_in * 1000).toISOString()
  };
  persistSessionSecrets({
    accessToken: login.access_token,
    refreshToken: login.refresh_token,
  });
  writeConfig(config);
  console.log(`Signed in as ${config.session.email}.`);
}

export function statusCommand(): void {
  const config = readConfig();
  if (!config.session) {
    console.log("Not signed in. Run `reportkit auth --email ...`.");
    return;
  }

  console.log(`Signed in as: ${config.session.email}`);
  console.log(`User ID: ${config.session.userID}`);
  for (const line of describeSessionExpiry(config.session.expiresAt)) {
    console.log(line);
  }
  console.log(`Config: ${configPath()}`);
  console.log(`Secure session store: ${sessionStorePath()}`);
}

export async function sendCommand(argv: string[]): Promise<void> {
  const config = readConfig();
  requireSession(config);
  const flags = parseArgs(argv);
  const file = optionalFlag(flags, "file");

  let event: "start" | "update" | "end";
  let activityId: string;
  let payload: Record<string, unknown>;
  let idempotencyKey = optionalFlag(flags, "idempotency-key");
  let apnsEnv = normalizeApnsEnv(optionalFlag(flags, "apns-env"));
  let visualStyle = normalizeVisualStyle(optionalFlag(flags, "visual-style"));

  if (file) {
    const parsed = JSON.parse(fs.readFileSync(path.resolve(file), "utf8")) as {
      event: "start" | "update" | "end";
      activityId?: string;
      payload: Record<string, unknown>;
      idempotencyKey?: string;
      apnsEnv?: "sandbox" | "production";
      visualStyle?: "minimal" | "banner" | "chart";
    };
    event = parsed.event;
    activityId = parsed.activityId ?? "reportkit-simple";
    payload = parsed.payload;
    idempotencyKey = parsed.idempotencyKey ?? idempotencyKey;
    apnsEnv = normalizeApnsEnv(parsed.apnsEnv ?? apnsEnv);
    visualStyle = normalizeVisualStyle(parsed.visualStyle ?? visualStyle);
  } else {
    event = requiredFlag(flags, "event") as "start" | "update" | "end";
    activityId = requiredFlag(flags, "activity-id");
      payload = {
      generatedAt: Math.floor(Date.now() / 1_000),
      title: requiredFlag(flags, "title"),
      summary: requiredFlag(flags, "summary"),
      status: normalizeStatus(optionalFlag(flags, "status")),
      action: optionalFlag(flags, "action"),
      deepLink: optionalFlag(flags, "deep-link")
    };
  }

  const body = buildSendBody({
    event,
    activityId,
    payload,
    apnsEnv,
    idempotencyKey,
    visualStyle
  });
  const response = await sendLiveActivity(config, body);
  console.log(JSON.stringify(response, null, 2));
}

function buildSkillTemplate(target: "codex" | "claude"): string {
  const audience = target === "claude" ? "Claude Code" : "Codex";
  return `# ${audience} Skill: ReportKitSimple

You are helping a user configure ReportKitSimple.
Keep guidance short, practical, and paste-ready.

Use this exact setup flow:
- iOS login: email + password with the same account.
- CLI login: reportkit auth --email <email>.
- Confirm both are signed in.

Ask these onboarding questions, in order:
1) What should the report monitor? (ex: errors, revenue, PR readiness, uptime, etc.)
2) What are the data sources/commands for that report?
3) What triggers should launch each send? (manual, workflow event, or scheduled trigger)
4) Which timezone should scheduling use?
5) What constitutes each status: good / warning / critical?
6) When should it do nothing? (skip conditions)
7) What should action text say, and what deep link should open?
8) Are there quiet hours, blackout windows, or people to exclude?
9) Should each report be separate or grouped?
10) What should trigger each send (for example, manual run, task completion, explicit assistant prompt)?

Then propose direct 'reportkit send' commands per report trigger.

Contract reminder for send payload:
{ "event": "start|update|end", "activityId": "...", "payload": { "generatedAt": 1710000000, "title": "...", "summary": "...", "status": "good|warning|critical", "action": "...", "deepLink": "..." } }

Optional visual style override:
{ "visualStyle": "minimal|banner|chart" }  // default is minimal

Preferred CLI usage:
- reportkit status
- reportkit send --file payload.json
- reportkit send --event update --activity-id ID --title TITLE --summary TEXT --status warning --visual-style chart

Do not use cron here; scheduling is handled by Codex/Claude Code in this workflow.
`;
}

export async function logoutCommand(): Promise<void> {
  const config = readConfig();
  config.session = null;
  writeConfig(config);
  deleteSessionSecrets();
  console.log("Signed out.");
}

export function skillPrintCommand(argv: string[]): void {
  const flags = parseArgs(argv);
  const rawTarget = optionalFlag(flags, "target") ?? "codex";
  const target = rawTarget === "claude" ? "claude" : "codex";
  console.log(buildSkillTemplate(target));
}
