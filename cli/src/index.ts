#!/usr/bin/env node
import {
  alarmCommand,
  authCommand,
  logoutCommand,
  sendCommand,
  skillPrintCommand,
  statusCommand
} from "./commands.js";

async function main(): Promise<void> {
  const [command, subcommand, ...rest] = process.argv.slice(2);

  switch (command) {
    case "auth":
      await authCommand([subcommand, ...rest].filter(Boolean));
      return;
    case "status":
      await statusCommand();
      return;
    case "send":
      await sendCommand([subcommand, ...rest].filter(Boolean));
      return;
    case "alarm":
      await alarmCommand([subcommand, ...rest].filter(Boolean));
      return;
    case "logout":
      await logoutCommand();
      return;
    case "skill":
      if (subcommand === "print") {
        skillPrintCommand(rest);
        return;
      }
      break;
    default:
      break;
  }

  console.log(`ReportKitSimple CLI

Commands:
  reportkit auth --email EMAIL [--password-stdin]
  reportkit status
  reportkit send --event start|update|end --activity-id ID --title TITLE --summary TEXT [--status good|warning|critical] [--action TEXT] [--deep-link URL]
  reportkit send --file payload.json
  reportkit alarm --title TITLE [--in-seconds N | --fire-at ISO8601] [--apns-env sandbox|production] [--device-install-id ID]
  reportkit logout
  reportkit skill print --target codex|claude
`);
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(message);
  process.exitCode = 1;
});
