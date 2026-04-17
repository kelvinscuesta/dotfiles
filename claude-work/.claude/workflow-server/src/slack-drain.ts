import { spawn } from "node:child_process";
import { stat } from "node:fs/promises";
import { appendFile, mkdir } from "node:fs/promises";
import { join, dirname } from "node:path";
import { homedir } from "node:os";
import * as paths from "./paths.js";
import { audit } from "./audit.js";

function claudeBin(): string {
  return process.env.CLAUDE_BIN ?? join(homedir(), ".local", "bin", "claude");
}
function logDir(): string {
  return process.env.RUNNER_LOG_DIR ?? join(homedir(), ".claude", "workflow-server", "logs");
}
function queuePath(): string {
  return process.env.SLACK_QUEUE ?? join(paths.WORKFLOW_DIR, "slack_queue.jsonl");
}

/**
 * Run wf-slack-drain skill headlessly. Only invokes claude if the queue has content.
 * Returns true if it attempted a drain.
 */
export async function drainSlack(): Promise<boolean> {
  let size = 0;
  try { size = (await stat(queuePath())).size; } catch { /* no file yet */ }
  if (size === 0) return false;

  const ts = new Date().toISOString().replace(/[:.]/g, "-");
  const dir = logDir();
  await mkdir(dir, { recursive: true });
  const logPath = join(dir, `slack-drain-${ts}.log`);

  await audit("NOTIFY", `slack drain starting (queue=${size}B)`);
  await appendFile(logPath, `# ${new Date().toISOString()} slack drain\n`);

  return new Promise((resolve) => {
    const proc = spawn(
      claudeBin(),
      ["--dangerously-skip-permissions", "-p", "/wf-slack-drain"],
      {
        stdio: ["ignore", "pipe", "pipe"],
        env: { ...process.env, CLAUDE_CODE_NO_FLICKER: "1" },
      },
    );
    proc.stdout!.on("data", (d: Buffer) => { appendFile(logPath, d).catch(() => {}); });
    proc.stderr!.on("data", (d: Buffer) => { appendFile(logPath, `[err] ${d}`).catch(() => {}); });
    const timer = setTimeout(() => proc.kill("SIGTERM"), 2 * 60 * 1000); // 2min cap

    proc.on("exit", async (code) => {
      clearTimeout(timer);
      await appendFile(logPath, `\n# exit=${code}\n`);
      if (code === 0) {
        await audit("NOTIFY", `slack drain ok`);
      } else {
        await audit("NOTIFY", `slack drain failed exit=${code} log=${logPath}`);
      }
      resolve(true);
    });
    proc.on("error", async (err) => {
      clearTimeout(timer);
      await audit("NOTIFY", `slack drain spawn error: ${err.message}`);
      resolve(true);
    });
  });
}
