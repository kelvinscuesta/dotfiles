import { appendFile, mkdir } from "node:fs/promises";
import { dirname, join } from "node:path";
import * as paths from "./paths.js";
import { macNotify } from "./notify.js";

function auditPath(override?: string): string {
  return override ?? process.env.AUDIT_LOG ?? paths.AUDIT_LOG;
}

function slackQueuePath(): string {
  return process.env.SLACK_QUEUE ?? join(paths.WORKFLOW_DIR, "slack_queue.jsonl");
}

/**
 * Actions worth mirroring to Slack. Quiet POLL:* / no-changes noise stays local.
 * Override via env SLACK_MIRROR_ACTIONS=comma,separated (prefix match).
 */
function mirrorPrefixes(): string[] {
  const raw = process.env.SLACK_MIRROR_ACTIONS
    ?? "RUN:,JIRA:,APPROVE,REJECT,CLEANUP,START,STOP,NOTIFY,DRAFT,PLAN,CLASSIFY,FEED,ACK,STALE";
  return raw.split(",").map((s) => s.trim()).filter(Boolean);
}

function shouldMirror(action: string): boolean {
  return mirrorPrefixes().some((p) => action.startsWith(p));
}

export async function audit(action: string, message: string, override?: string): Promise<void> {
  const ts = new Date().toISOString().replace(/\.\d{3}Z$/, "");
  const line = `${ts} [${action}] ${message}\n`;
  const path = auditPath(override);
  await mkdir(dirname(path), { recursive: true });
  await appendFile(path, line);

  // Mirror to Slack queue if action is noteworthy
  if (shouldMirror(action)) {
    try {
      const queuePath = slackQueuePath();
      await mkdir(dirname(queuePath), { recursive: true });
      await appendFile(queuePath, JSON.stringify({ ts, action, message }) + "\n");
    } catch {
      /* best-effort — don't fail audit on queue write error */
    }
  }

  // Fire macOS notification for high-value events (non-blocking)
  macNotify(action, message);
}
