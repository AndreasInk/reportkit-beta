import readline from "node:readline";
import { Writable } from "node:stream";

export async function readPasswordFromStdin(input: NodeJS.ReadableStream = process.stdin): Promise<string> {
  const chunks: Buffer[] = [];

  for await (const chunk of input) {
    chunks.push(typeof chunk === "string" ? Buffer.from(chunk) : Buffer.from(chunk));
  }

  const password = Buffer.concat(chunks).toString("utf8").replace(/[\r\n]+$/u, "");
  if (!password) {
    throw new Error("Password stdin was empty.");
  }
  return password;
}

export async function promptForPassword(
  prompt = "Password: ",
  input: NodeJS.ReadStream = process.stdin,
  output: NodeJS.WriteStream = process.stdout,
): Promise<string> {
  if (!input.isTTY || !output.isTTY) {
    throw new Error("Interactive password prompt requires a TTY. Use `--password-stdin` for non-interactive auth.");
  }

  let muted = false;
  const maskedOutput = new Writable({
    write(chunk, encoding, callback) {
      if (!muted) {
        output.write(chunk, encoding as BufferEncoding);
      }
      callback();
    },
  });

  const rl = readline.createInterface({
    input,
    output: maskedOutput,
    terminal: true,
  }) as readline.Interface & { _writeToOutput?: (value: string) => void };

  rl._writeToOutput = (value: string) => {
    if (!muted || value.includes(prompt)) {
      output.write(value);
    }
  };

  return new Promise<string>((resolve, reject) => {
    muted = true;
    rl.question(prompt, (value) => {
      rl.close();
      output.write("\n");
      if (!value) {
        reject(new Error("Password cannot be empty."));
        return;
      }
      resolve(value);
    });

    rl.once("SIGINT", () => {
      rl.close();
      output.write("\n");
      reject(new Error("Password prompt cancelled."));
    });
  });
}
