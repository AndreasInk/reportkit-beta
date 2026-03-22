import fs from "node:fs";
import path from "node:path";
import { cliSignIn, sendLiveActivity } from "./api.js";
import { configPath, readConfig, writeConfig } from "./config.js";
import { buildSendBody, normalizeApnsEnv, normalizeStatus, normalizeVisualStyle, optionalFlag, parseArgs, requiredFlag } from "./format.js";
import type { ReportKitConfig } from "./types.js";

function readAuthFlags(flags: Map<string, string | true>): { email: string; password: string } {
  const email = optionalFlag(flags, "email") ?? process.env.REPORTKIT_EMAIL;
  const password = optionalFlag(flags, "password") ?? process.env.REPORTKIT_PASSWORD;
  if (!email || !password) {
    throw new Error("Usage: reportkit auth --email EMAIL --password PASSWORD");
  }
  return { email, password };
}

function requireSession(config: ReportKitConfig): void {
  if (!config.session) {
    throw new Error("No CLI credentials found. Run `reportkit auth --email ... --password ...` first.");
  }
}

export async function authCommand(argv: string[]): Promise<void> {
  const config = readConfig();
  const flags = parseArgs(argv);
  const credentials = readAuthFlags(flags);

  const login = await cliSignIn(config, credentials.email, credentials.password);
  config.session = {
    accessToken: login.access_token,
    refreshToken: login.refresh_token,
    userID: login.user.id,
    email: login.user.email,
    expiresAt: new Date(Date.now() + login.expires_in * 1000).toISOString()
  };
  writeConfig(config);
  console.log(`Signed in as ${config.session.email}.`);
}

export function statusCommand(): void {
  const config = readConfig();
  if (!config.session) {
    console.log("Not signed in. Run `reportkit auth --email ... --password ...`.");
    return;
  }

  console.log(`Signed in as: ${config.session.email}`);
  console.log(`User ID: ${config.session.userID}`);
  console.log(`Token expires at: ${config.session.expiresAt}`);
  console.log(`Config: ${configPath()}`);
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
- CLI login: reportkit auth --email <email> --password <password>.
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
  console.log("Signed out.");
}

export function skillPrintCommand(argv: string[]): void {
  const flags = parseArgs(argv);
  const rawTarget = optionalFlag(flags, "target") ?? "codex";
  const target = rawTarget === "claude" ? "claude" : "codex";
  console.log(buildSkillTemplate(target));
}
